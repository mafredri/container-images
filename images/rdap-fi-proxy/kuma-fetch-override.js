const targetPrefix = process.env.RDAP_FI_TARGET_PREFIX || "https://rdap.fi/rdap/rdap/domain/";
const replacementPrefix = process.env.RDAP_FI_PROXY_PREFIX || "http://rdap-fi-proxy:8080/rdap/rdap/domain/";
const verbose = process.env.RDAP_FI_PROXY_DEBUG !== "0";
const originalFetch = globalThis.fetch;

if (typeof originalFetch !== "function") {
    throw new Error("global fetch is not available");
}

function log(message) {
    if (verbose) {
        console.log("[rdap-fi-proxy] " + message);
    }
}

log("fetch override loaded: " + targetPrefix + " -> " + replacementPrefix);

globalThis.fetch = function rdapFiFetchOverride(input, init) {
    let rewritten = null;
    if (typeof input === "string" && input.startsWith(targetPrefix)) {
        rewritten = replacementPrefix + input.slice(targetPrefix.length);
        input = rewritten;
    } else if (input instanceof URL && input.href.startsWith(targetPrefix)) {
        rewritten = replacementPrefix + input.href.slice(targetPrefix.length);
        input = new URL(rewritten);
    } else if (input && typeof input.url === "string" && input.url.startsWith(targetPrefix)) {
        rewritten = replacementPrefix + input.url.slice(targetPrefix.length);
        input = new Request(rewritten, input);
    }
    if (rewritten) {
        log("rewritten RDAP request to " + rewritten);
    }
    return originalFetch.call(this, input, init);
};
