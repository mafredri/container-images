package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"
	_ "time/tzdata"
)

const (
	defaultAddr        = ":8080"
	defaultUpstreamURL = "https://rdap.fi/rdap/rdap"
	defaultWhoisAddr   = "whois.fi:43"
	defaultTimeout     = 10 * time.Second
	defaultCacheTTL    = 6 * time.Hour
)

type server struct {
	httpClient  *http.Client
	upstreamURL string
	whoisAddr   string
	timeout     time.Duration
	cacheTTL    time.Duration
	cache       *expiryCache
	log         *slog.Logger
}

type expiryCache struct {
	mu      sync.Mutex
	entries map[string]cacheEntry
}

type cacheEntry struct {
	expiry    time.Time
	expiresAt time.Time
}

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))

	s := &server{
		httpClient:  &http.Client{Timeout: envDuration("HTTP_TIMEOUT", defaultTimeout)},
		upstreamURL: strings.TrimRight(envString("UPSTREAM_RDAP_URL", defaultUpstreamURL), "/"),
		whoisAddr:   envString("WHOIS_ADDR", defaultWhoisAddr),
		timeout:     envDuration("WHOIS_TIMEOUT", defaultTimeout),
		cacheTTL:    envDuration("CACHE_TTL", defaultCacheTTL),
		cache:       &expiryCache{entries: map[string]cacheEntry{}},
		log:         logger,
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/healthz", s.handleHealthz)
	mux.HandleFunc("/domain/", s.handleDomain)
	mux.HandleFunc("/rdap/rdap/domain/", s.handleDomain)

	addr := envString("ADDR", defaultAddr)
	logger.Info("starting rdap fi proxy", "addr", addr, "upstream", s.upstreamURL, "whois", s.whoisAddr)
	if err := http.ListenAndServe(addr, mux); err != nil {
		logger.Error("server stopped", "error", err)
		os.Exit(1)
	}
}

func (s *server) handleHealthz(w http.ResponseWriter, _ *http.Request) {
	w.WriteHeader(http.StatusNoContent)
}

func (s *server) handleDomain(w http.ResponseWriter, r *http.Request) {
	started := time.Now()
	domain := domainFromPath(r.URL.Path)
	if !validFIDomain(domain) {
		s.log.Warn("rejected request", "path", r.URL.Path, "remote", r.RemoteAddr)
		http.Error(w, "expected a .fi domain", http.StatusBadRequest)
		return
	}
	s.log.Info("rdap request", "domain", domain, "path", r.URL.Path, "remote", r.RemoteAddr)

	ctx, cancel := context.WithTimeout(r.Context(), s.timeout)
	defer cancel()

	rdap, rdapErr := s.fetchRDAP(ctx, domain)
	expiry, expiryErr := s.expiry(ctx, domain)
	if expiryErr != nil {
		s.log.Warn("expiry lookup failed", "domain", domain, "error", expiryErr)
		if rdapErr != nil {
			http.Error(w, "rdap and whois lookups failed", http.StatusBadGateway)
			return
		}
		writeJSON(w, rdapStatus(rdap), rdap)
		return
	}

	if rdapErr != nil {
		s.log.Warn("upstream rdap lookup failed, returning minimal response", "domain", domain, "error", rdapErr)
		rdap = minimalRDAP(domain)
	}

	addExpirationEvent(rdap, expiry)
	s.log.Info("rdap response enriched", "domain", domain, "expiration", expiry.Format(time.RFC3339), "duration", time.Since(started).String())
	writeJSON(w, rdapStatus(rdap), rdap)
}

func (s *server) fetchRDAP(ctx context.Context, domain string) (map[string]any, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, s.upstreamURL+"/domain/"+domain, nil)
	if err != nil {
		return nil, err
	}

	res, err := s.httpClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer res.Body.Close()

	body, err := io.ReadAll(io.LimitReader(res.Body, 1<<20))
	if err != nil {
		return nil, err
	}
	if res.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("upstream rdap returned %d: %s", res.StatusCode, strings.TrimSpace(string(body)))
	}

	var out map[string]any
	if err := json.Unmarshal(body, &out); err != nil {
		return nil, err
	}
	return out, nil
}

func (s *server) expiry(ctx context.Context, domain string) (time.Time, error) {
	if expiry, ok := s.cache.get(domain, time.Now()); ok {
		s.log.Info("whois cache hit", "domain", domain, "expiration", expiry.Format(time.RFC3339))
		return expiry, nil
	}

	expiry, err := lookupWHOISExpiry(ctx, s.whoisAddr, domain, s.timeout)
	if err != nil {
		return time.Time{}, err
	}
	s.cache.set(domain, expiry, time.Now().Add(s.cacheTTL))
	s.log.Info("whois expiry found", "domain", domain, "expiration", expiry.Format(time.RFC3339))
	return expiry, nil
}

func lookupWHOISExpiry(ctx context.Context, addr, domain string, timeout time.Duration) (time.Time, error) {
	var dialer net.Dialer
	conn, err := dialer.DialContext(ctx, "tcp", addr)
	if err != nil {
		return time.Time{}, err
	}
	defer conn.Close()

	deadline := time.Now().Add(timeout)
	_ = conn.SetDeadline(deadline)

	if _, err := fmt.Fprintf(conn, "%s\r\n", domain); err != nil {
		return time.Time{}, err
	}
	body, err := io.ReadAll(io.LimitReader(conn, 1<<20))
	if err != nil {
		return time.Time{}, err
	}
	return parseWHOISExpiry(string(body))
}

func parseWHOISExpiry(body string) (time.Time, error) {
	for _, line := range strings.Split(body, "\n") {
		line = strings.TrimSpace(line)
		if !strings.HasPrefix(line, "expires") {
			continue
		}
		_, value, ok := strings.Cut(line, ":")
		if !ok {
			return time.Time{}, fmt.Errorf("malformed expires line: %q", line)
		}
		value = strings.TrimSpace(value)
		loc, err := time.LoadLocation("Europe/Helsinki")
		if err != nil {
			return time.Time{}, err
		}
		return time.ParseInLocation("2.1.2006 15:04:05", value, loc)
	}
	return time.Time{}, errors.New("whois response did not contain expires line")
}

func addExpirationEvent(rdap map[string]any, expiry time.Time) {
	events, _ := rdap["events"].([]any)
	filtered := make([]any, 0, len(events)+1)
	for _, event := range events {
		obj, ok := event.(map[string]any)
		if ok && obj["eventAction"] == "expiration" {
			continue
		}
		filtered = append(filtered, event)
	}
	filtered = append(filtered, map[string]any{
		"eventAction": "expiration",
		"eventDate":   expiry.Format(time.RFC3339),
	})
	rdap["events"] = filtered
}

func minimalRDAP(domain string) map[string]any {
	return map[string]any{
		"rdapConformance": []any{"rdap_level_0"},
		"objectClassName": "domain",
		"ldhName":         domain,
		"unicodeName":     domain,
		"events":          []any{},
	}
}

func rdapStatus(rdap map[string]any) int {
	if code, ok := rdap["statusCode"].(float64); ok && code >= 400 {
		return int(code)
	}
	return http.StatusOK
}

func domainFromPath(path string) string {
	if strings.HasPrefix(path, "/rdap/rdap/domain/") {
		return strings.TrimPrefix(path, "/rdap/rdap/domain/")
	}
	return strings.TrimPrefix(path, "/domain/")
}

func validFIDomain(domain string) bool {
	domain = strings.ToLower(strings.TrimSpace(domain))
	if domain == "" || !strings.HasSuffix(domain, ".fi") {
		return false
	}
	if strings.ContainsAny(domain, " \t\r\n/\\") {
		return false
	}
	if strings.Count(domain, ".") < 1 {
		return false
	}
	return true
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/rdap+json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}

func (c *expiryCache) get(domain string, now time.Time) (time.Time, bool) {
	c.mu.Lock()
	defer c.mu.Unlock()
	entry, ok := c.entries[domain]
	if !ok || now.After(entry.expiresAt) {
		return time.Time{}, false
	}
	return entry.expiry, true
}

func (c *expiryCache) set(domain string, expiry time.Time, expiresAt time.Time) {
	c.mu.Lock()
	defer c.mu.Unlock()
	c.entries[domain] = cacheEntry{expiry: expiry, expiresAt: expiresAt}
}

func envString(name, fallback string) string {
	if value := strings.TrimSpace(os.Getenv(name)); value != "" {
		return value
	}
	return fallback
}

func envDuration(name string, fallback time.Duration) time.Duration {
	value := strings.TrimSpace(os.Getenv(name))
	if value == "" {
		return fallback
	}
	if d, err := time.ParseDuration(value); err == nil {
		return d
	}
	seconds, err := strconv.Atoi(value)
	if err != nil {
		return fallback
	}
	return time.Duration(seconds) * time.Second
}
