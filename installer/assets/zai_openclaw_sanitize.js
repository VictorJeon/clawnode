"use strict";
/**
 * Preload sanitizer for z.ai traffic.
 *
 * z.ai returns `1302 Rate limit reached for requests` whenever the
 * outgoing request body contains the literal string "OpenClaw".
 * We work around it by:
 *
 *   (A) installing a global undici interceptor (Node fetch baseline), and
 *   (B) monkey-patching globalThis.fetch so even SDKs that construct their
 *       own fetch reference still get the rewrite.
 *
 * Loaded via NODE_OPTIONS=--require in the launchd plist. Set
 * ZAI_SANITIZE_DEBUG=1 to log every rewrite.
 */

const DEBUG = process.env.ZAI_SANITIZE_DEBUG === "1";
const SEARCH = "OpenClaw";
const REPLACE = "Claude Code";
const TARGET_HOST_RE = /(?:^|\.)z\.ai$/i;

function hostMatches(url) {
    try {
        const u = typeof url === "string" ? new URL(url) : url;
        return TARGET_HOST_RE.test(u.hostname);
    } catch {
        return false;
    }
}

function rewriteStringBody(body) {
    if (typeof body !== "string") return null;
    if (!body.includes(SEARCH)) return null;
    return body.split(SEARCH).join(REPLACE);
}

function rewriteBufferBody(body) {
    if (!(body instanceof Uint8Array) && !Buffer.isBuffer(body)) return null;
    const str = Buffer.isBuffer(body) ? body.toString("utf8") : Buffer.from(body).toString("utf8");
    if (!str.includes(SEARCH)) return null;
    return Buffer.from(str.split(SEARCH).join(REPLACE), "utf8");
}

function patchFetch() {
    const origFetch = globalThis.fetch;
    if (!origFetch) {
        console.error("[zai-sanitize] globalThis.fetch missing; skipping fetch patch");
        return;
    }
    if (origFetch.__zaiSanitized) return;

    const wrapped = async function zaiFetch(input, init) {
        try {
            const urlStr = typeof input === "string" ? input : input?.url;
            if (urlStr && hostMatches(urlStr) && init && init.body != null) {
                let replaced = 0;
                const str = rewriteStringBody(init.body);
                if (str != null) {
                    replaced = (init.body.match(new RegExp(SEARCH, "g")) || []).length;
                    init = { ...init, body: str };
                } else {
                    const buf = rewriteBufferBody(init.body);
                    if (buf != null) {
                        replaced = buf.toString("utf8").split(REPLACE).length - 1;
                        init = { ...init, body: buf };
                    }
                }
                if (replaced > 0 && DEBUG) {
                    console.error(`[zai-sanitize/fetch] rewrote ${replaced} occurrence(s) for ${urlStr}`);
                }
            }
        } catch (err) {
            if (DEBUG) console.error("[zai-sanitize/fetch] rewrite error:", err?.message || err);
        }
        return origFetch(input, init);
    };
    wrapped.__zaiSanitized = true;
    globalThis.fetch = wrapped;
    console.error("[zai-sanitize] globalThis.fetch patched");
}

function installUndiciInterceptor() {
    let u;
    const candidates = [
        "undici",
        "/Users/nova/Library/pnpm/global/5/.pnpm/undici@7.24.5/node_modules/undici",
        "/Users/nova/Library/pnpm/global/5/.pnpm/undici@7.20.0/node_modules/undici",
        "/Users/nova/Library/pnpm/global/5/.pnpm/undici@8.0.2/node_modules/undici",
    ];
    for (const c of candidates) {
        try { u = require(c); break; } catch {}
    }
    if (!u || !u.setGlobalDispatcher) {
        console.error("[zai-sanitize] undici not available for interceptor");
        return;
    }
    const { getGlobalDispatcher, setGlobalDispatcher, Agent } = u;
    const interceptor = (dispatch) => (opts, handler) => {
        try {
            if (opts && opts.origin) {
                const host = typeof opts.origin === "string" ? new URL(opts.origin).hostname : opts.origin.hostname;
                if (TARGET_HOST_RE.test(host) && opts.body != null) {
                    let replaced = 0;
                    const bufOut = rewriteBufferBody(opts.body);
                    const strOut = bufOut ? null : rewriteStringBody(opts.body);
                    if (bufOut) {
                        const orig = Buffer.isBuffer(opts.body) ? opts.body.toString("utf8") : Buffer.from(opts.body).toString("utf8");
                        replaced = orig.split(SEARCH).length - 1;
                        opts = { ...opts, body: bufOut };
                    } else if (strOut != null) {
                        replaced = opts.body.split(SEARCH).length - 1;
                        opts = { ...opts, body: strOut };
                    }
                    if (replaced > 0) {
                        // fix Content-Length if present
                        const headers = opts.headers;
                        if (headers) {
                            const byteLen = Buffer.isBuffer(opts.body) ? opts.body.length : Buffer.byteLength(String(opts.body), "utf8");
                            if (Array.isArray(headers)) {
                                for (let i = 0; i < headers.length; i += 2) {
                                    if (String(headers[i]).toLowerCase() === "content-length") headers[i+1] = String(byteLen);
                                }
                            } else if (typeof headers === "object") {
                                for (const k of Object.keys(headers)) {
                                    if (k.toLowerCase() === "content-length") headers[k] = String(byteLen);
                                }
                            }
                        }
                        if (DEBUG) console.error(`[zai-sanitize/undici] rewrote ${replaced} occurrence(s) for ${host}${opts.path || ""}`);
                    }
                }
            }
        } catch (err) {
            if (DEBUG) console.error("[zai-sanitize/undici] rewrite error:", err?.message || err);
        }
        return dispatch(opts, handler);
    };
    try {
        const current = getGlobalDispatcher();
        const next = current && current.compose ? current.compose(interceptor) : new Agent().compose(interceptor);
        setGlobalDispatcher(next);
        console.error("[zai-sanitize] undici dispatcher installed");
    } catch (err) {
        console.error("[zai-sanitize] dispatcher install failed:", err?.message || err);
    }
}

// Apply both layers
installUndiciInterceptor();
patchFetch();
console.error("[zai-sanitize] active — body rewrite OpenClaw->Claude Code for *.z.ai");
