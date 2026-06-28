package main

import (
	"bufio"
	"encoding/json"
	"io"
	"log/slog"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestParseWHOISExpiry(t *testing.T) {
	body := `
domain.............: domain.fi
status.............: Registered
created............: 21.10.2018 02:37:36
expires............: 21.10.2026 02:37:36
available..........: 21.11.2026 02:37:36
`

	got, err := parseWHOISExpiry(body)
	if err != nil {
		t.Fatal(err)
	}
	if got.Format(time.RFC3339) != "2026-10-21T02:37:36+03:00" {
		t.Fatalf("expiry = %s", got.Format(time.RFC3339))
	}
}

func TestAddExpirationEventReplacesExisting(t *testing.T) {
	var rdap map[string]any
	if err := json.Unmarshal([]byte(`{
		"events": [
			{"eventAction": "registration", "eventDate": "2018-10-21T02:37:36+03:00"},
			{"eventAction": "expiration", "eventDate": "2025-10-21T02:37:36+03:00"}
		]
	}`), &rdap); err != nil {
		t.Fatal(err)
	}

	expiry, err := time.Parse(time.RFC3339, "2026-10-21T02:37:36+03:00")
	if err != nil {
		t.Fatal(err)
	}
	addExpirationEvent(rdap, expiry)

	events := rdap["events"].([]any)
	if len(events) != 2 {
		t.Fatalf("events len = %d", len(events))
	}
	got := events[1].(map[string]any)
	if got["eventAction"] != "expiration" || got["eventDate"] != "2026-10-21T02:37:36+03:00" {
		t.Fatalf("expiration event = %#v", got)
	}
}

func TestValidFIDomain(t *testing.T) {
	tests := map[string]bool{
		"domain.fi":   true,
		"xn--test.fi": true,
		"example.com": false,
		"bad.fi/xx":   false,
		"":            false,
	}
	for domain, want := range tests {
		if got := validFIDomain(domain); got != want {
			t.Fatalf("validFIDomain(%q) = %v, want %v", domain, got, want)
		}
	}
}

func TestHandleDomainEnrichesRDAP(t *testing.T) {
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path != "/domain/domain.fi" {
			t.Fatalf("upstream path = %s", r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/rdap+json")
		_, _ = w.Write([]byte(`{
			"rdapConformance": ["rdap_level_0"],
			"objectClassName": "domain",
			"ldhName": "domain.fi",
			"events": [
				{"eventAction": "registration", "eventDate": "2018-10-21T02:37:36+03:00"}
			]
		}`))
	}))
	defer upstream.Close()

	whoisAddr, closeWhois := fakeWhois(t, "expires............: 21.10.2026 02:37:36\n")
	defer closeWhois()

	s := &server{
		httpClient:  upstream.Client(),
		upstreamURL: upstream.URL,
		whoisAddr:   whoisAddr,
		timeout:     time.Second,
		cacheTTL:    time.Hour,
		cache:       &expiryCache{entries: map[string]cacheEntry{}},
		log:         slog.New(slog.NewTextHandler(io.Discard, nil)),
	}

	req := httptest.NewRequest(http.MethodGet, "/rdap/rdap/domain/domain.fi", nil)
	res := httptest.NewRecorder()
	s.handleDomain(res, req)

	if res.Code != http.StatusOK {
		t.Fatalf("status = %d, body = %s", res.Code, res.Body.String())
	}

	var body map[string]any
	if err := json.Unmarshal(res.Body.Bytes(), &body); err != nil {
		t.Fatal(err)
	}
	events := body["events"].([]any)
	got := events[1].(map[string]any)
	if got["eventAction"] != "expiration" || got["eventDate"] != "2026-10-21T02:37:36+03:00" {
		t.Fatalf("expiration event = %#v", got)
	}
}

func fakeWhois(t *testing.T, response string) (string, func()) {
	t.Helper()

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}

	done := make(chan struct{})
	go func() {
		defer close(done)
		conn, err := listener.Accept()
		if err != nil {
			return
		}
		defer conn.Close()
		_, _ = bufio.NewReader(conn).ReadString(byte(10))
		_, _ = conn.Write([]byte(response))
	}()

	return listener.Addr().String(), func() {
		_ = listener.Close()
		<-done
	}
}
