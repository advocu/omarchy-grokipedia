.pragma library

// Network gate, URL rules, and HTML parsers for the Grokipedia bar widget.
// Pure JavaScript with no QML types, so the same file runs in the shell and
// under a plain JavaScript engine in tests.
//
// Contract (see README "Network and privacy"):
// - HTTPS GET to grokipedia.com only, and only two shapes of URL:
//   the homepage ("/") and the search page ("/search?q=...").
// - Never /api/* (robots.txt disallows it) and never /page/* (articles are MBs).
// - Hard cap of MAX_BYTES on every response; the body is dropped, not parsed,
//   when the cap is exceeded.
// - A redirect that leaves those two URL shapes is treated as a failure.

var MAX_BYTES = 262144          // 256 KiB
var TIMEOUT_MS = 10000          // per request
var MAX_QUERY_CHARS = 200
var MAX_SLUG_CHARS = 256
var MAX_TITLE_CHARS = 160
var MAX_BRIEF_CHARS = 320
var MAX_FEATURED = 5
var MAX_RESULTS = 12

var HOME_URL = "https://grokipedia.com/"
var SEARCH_PREFIX = "https://grokipedia.com/search?q="
var PAGE_PREFIX = "https://grokipedia.com/page/"

// encodeURIComponent output: unreserved characters and %XX escapes only.
var ENCODED_QUERY_RE = /^(?:[A-Za-z0-9\-_.!~*'()]|%[0-9A-F]{2})+$/
// Article path the site itself builds (window.__articlePath): encodeURIComponent
// with $ & + , : ; = @ decoded again.
var ENCODED_SLUG_RE = /^(?:[A-Za-z0-9\-_.!~*'()$&+,:;=@]|%[0-9A-F]{2})+$/

// ---------------------------------------------------------------- URLs

function searchUrl(query) {
    var q = String(query === undefined || query === null ? "" : query).trim()
    if (q.length === 0 || q.length > MAX_QUERY_CHARS) return ""
    var url = SEARCH_PREFIX + encodeURIComponent(q)
    return requestKind(url) === "search" ? url : ""
}

// Classify a URL the plugin may GET. Returns "home", "search", or "" (refused).
// Exact string shapes only: no other scheme, host, port, userinfo, path,
// parameter, or fragment passes.
function requestKind(url) {
    if (typeof url !== "string") return ""
    if (url === HOME_URL) return "home"
    if (url.indexOf(SEARCH_PREFIX) === 0) {
        var q = url.substring(SEARCH_PREFIX.length)
        if (q.length > 0 && q.length <= MAX_QUERY_CHARS * 12 && ENCODED_QUERY_RE.test(q)) return "search"
    }
    return ""
}

function isAllowedRequestUrl(url) {
    return requestKind(url) !== ""
}

// A slug as the site gives it in data-slug (entity-decoded, not URL-encoded).
// Refuses empty or oversized values, control characters, whitespace, path
// separators, traversal, and characters that never appear in article slugs.
function isValidSlug(slug) {
    if (typeof slug !== "string") return false
    if (slug.length === 0 || slug.length > MAX_SLUG_CHARS) return false
    if (slug === "." || slug.indexOf("..") !== -1) return false
    if (/[\u0000-\u0020\u007f-\u009f\u2028\u2029\/\\?#%<>"`{}|^\[\]]/.test(slug)) return false
    return true
}

function articlePath(slug) {
    return encodeURIComponent(slug).replace(/%(?:24|26|2B|2C|3A|3B|3D|40)/g, function (e) {
        return decodeURIComponent(e)
    })
}

// https://grokipedia.com/page/{slug}, or "" for an invalid slug.
function pageUrl(slug) {
    if (!isValidSlug(slug)) return ""
    var url = PAGE_PREFIX + articlePath(slug)
    return isAllowedOpenUrl(url) ? url : ""
}

// Final gate before Qt.openUrlExternally. Only the homepage, a search page,
// or an article page on https://grokipedia.com pass.
function isAllowedOpenUrl(url) {
    if (typeof url !== "string") return false
    if (url === HOME_URL) return true
    if (requestKind(url) === "search") return true
    if (url.indexOf(PAGE_PREFIX) === 0) {
        var p = url.substring(PAGE_PREFIX.length)
        return p.length > 0 && p.length <= MAX_SLUG_CHARS * 12 && p.indexOf("..") === -1 && ENCODED_SLUG_RE.test(p)
    }
    return false
}

// URL for a More button: the article when the slug is valid, otherwise the
// search page for the query, otherwise the homepage. Never a server URL.
function moreUrl(slug, fallbackQuery) {
    var url = pageUrl(slug)
    if (url) return url
    url = searchUrl(fallbackQuery)
    return url || HOME_URL
}

// Slug from a site-relative "/page/..." href. Absolute or other paths: "".
function slugFromHref(href) {
    if (typeof href !== "string" || href.indexOf("/page/") !== 0) return ""
    var raw = href.substring(6)
    if (raw.length === 0 || /[?#]/.test(raw)) return ""
    var slug
    try {
        slug = decodeURIComponent(raw)
    } catch (e) {
        return ""
    }
    return isValidSlug(slug) ? slug : ""
}

function safeDecode(s) {
    try {
        return decodeURIComponent(s)
    } catch (e) {
        return null
    }
}

// ---------------------------------------------------------------- text

var NAMED_ENTITIES = {
    amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'", nbsp: " ",
    hellip: "\u2026", ndash: "\u2013", mdash: "\u2014",
    lsquo: "\u2018", rsquo: "\u2019", ldquo: "\u201c", rdquo: "\u201d",
    laquo: "\u00ab", raquo: "\u00bb", middot: "\u00b7", copy: "\u00a9",
    reg: "\u00ae", trade: "\u2122", deg: "\u00b0", times: "\u00d7", minus: "\u2212"
}

function codePointText(n) {
    if (!isFinite(n) || n <= 0 || n > 0x10ffff || (n >= 0xd800 && n <= 0xdfff)) return "\ufffd"
    if (n < 0x20 && n !== 9 && n !== 10 && n !== 13) return ""
    return String.fromCodePoint(n)
}

function decodeEntities(s) {
    return String(s).replace(/&(#[xX][0-9A-Fa-f]{1,6}|#[0-9]{1,7}|[A-Za-z][A-Za-z0-9]{1,31});/g, function (m, body) {
        if (body.charAt(0) === "#") {
            var hex = body.charAt(1) === "x" || body.charAt(1) === "X"
            return codePointText(parseInt(body.substring(hex ? 2 : 1), hex ? 16 : 10))
        }
        return Object.prototype.hasOwnProperty.call(NAMED_ENTITIES, body) ? NAMED_ENTITIES[body] : m
    })
}

function stripTags(s) {
    return String(s)
        .replace(/<!--[\s\S]*?-->/g, " ")
        .replace(/<(script|style)\b[\s\S]*?<\/\1\s*>/gi, " ")
        .replace(/<[^>]*>/g, " ")
}

// Plain display text: tags stripped (again after decoding, so encoded markup
// never shows), entities decoded, empty or truncated markdown citation
// links such as [](https...) removed, whitespace collapsed,
// control characters removed, capped at maxChars with an ellipsis.
function cleanText(s, maxChars) {
    var t = decodeEntities(stripTags(s))
        .replace(/<\/?[A-Za-z][^<>]*>/g, " ")
        .replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, "")
        .replace(/\[\]\([^)]*\)/g, " ")
        .replace(/\[\]\([^)]*$/g, "")
        .replace(/\s+/g, " ")
        .trim()
    if (maxChars > 0 && t.length > maxChars) {
        t = t.substring(0, maxChars - 1).replace(/\[\]\([^)]*$/g, "")
        t = t.replace(/\s+\S*$/, "") + "\u2026"
    }
    return t
}

// ---------------------------------------------------------------- HTML

// Attributes of one start tag, names lower-cased, values raw (not decoded).
function parseAttributes(tag) {
    var attrs = {}
    var inner = tag.replace(/^<[A-Za-z0-9]+/, "").replace(/\/?>$/, "")
    var re = /([^\s"'<>\/=]+)(?:\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s"'=<>`]+)))?/g
    var m
    while ((m = re.exec(inner)) !== null) {
        var name = m[1].toLowerCase()
        if (Object.prototype.hasOwnProperty.call(attrs, name)) continue
        attrs[name] = m[2] !== undefined ? m[2] : (m[3] !== undefined ? m[3] : (m[4] !== undefined ? m[4] : ""))
    }
    return attrs
}

function hasClass(attrs, cls) {
    return (" " + String(attrs["class"] || "").replace(/\s+/g, " ") + " ").indexOf(" " + cls + " ") !== -1
}

// Featured shelf on the homepage: <button class="featured-item" data-href
// data-title data-dek>. Returns up to MAX_FEATURED items
// { slug, title, dek, url }, the active (hero) item first.
function parseFeatured(html) {
    var out = []
    var seen = {}
    if (typeof html !== "string") return out
    var re = /<button\b[^>]*>/gi
    var m
    while ((m = re.exec(html)) !== null && out.length < MAX_FEATURED) {
        var attrs = parseAttributes(m[0])
        if (!hasClass(attrs, "featured-item")) continue
        var slug = slugFromHref(decodeEntities(attrs["data-href"] || ""))
        var title = cleanText(attrs["data-title"] || "", MAX_TITLE_CHARS)
        var dek = cleanText(attrs["data-dek"] || "", MAX_BRIEF_CHARS)
        var url = pageUrl(slug)
        if (!slug || !title || !url || seen[slug]) continue
        seen[slug] = true
        var item = { slug: slug, title: title, dek: dek, url: url }
        if (attrs["data-active"] === "1") out.unshift(item)
        else out.push(item)
    }
    return out
}

// Search results: <a class="result-row" href="/page/{slug}" data-slug
// data-search-snippet> with an <h3> title and a <p> snippet. Returns up to
// MAX_RESULTS items { slug, title, snippet, url }.
function parseSearch(html) {
    var out = []
    var seen = {}
    if (typeof html !== "string") return out
    var re = /<a\b[^>]*>/gi
    var m
    while ((m = re.exec(html)) !== null && out.length < MAX_RESULTS) {
        var attrs = parseAttributes(m[0])
        if (!hasClass(attrs, "result-row")) continue
        var end = html.indexOf("</a>", re.lastIndex)
        var body = end === -1 ? "" : html.substring(re.lastIndex, end)
        // data-slug when present (an invalid one drops the row); the
        // site-relative href only when data-slug is missing.
        var slug = Object.prototype.hasOwnProperty.call(attrs, "data-slug")
            ? decodeEntities(attrs["data-slug"])
            : slugFromHref(decodeEntities(attrs["href"] || ""))
        if (!isValidSlug(slug)) continue
        var h3 = /<h3\b[^>]*>([\s\S]*?)<\/h3>/i.exec(body)
        var title = h3 ? cleanText(h3[1], MAX_TITLE_CHARS) : ""
        var snippet = cleanText(attrs["data-search-snippet"] || "", MAX_BRIEF_CHARS)
        if (!snippet) {
            var p = /<p\b[^>]*>([\s\S]*?)<\/p>/i.exec(body)
            snippet = p ? cleanText(p[1], MAX_BRIEF_CHARS) : ""
        }
        var url = pageUrl(slug)
        if (!slug || !title || !url || seen[slug]) continue
        seen[slug] = true
        out.push({ slug: slug, title: title, snippet: snippet, url: url })
    }
    return out
}

// ---------------------------------------------------------------- bytes

// UTF-8 byte length of a JavaScript string.
function utf8Length(s) {
    var n = 0
    for (var i = 0; i < s.length; i++) {
        var c = s.charCodeAt(i)
        if (c < 0x80) n += 1
        else if (c < 0x800) n += 2
        else if (c >= 0xd800 && c <= 0xdbff && i + 1 < s.length) {
            var d = s.charCodeAt(i + 1)
            if (d >= 0xdc00 && d <= 0xdfff) { n += 4; i++ } else n += 3
        } else n += 3
    }
    return n
}

// True when the text is over the cap. Counts characters first (a lower bound
// on bytes) so a huge buffer is refused without walking it.
function overCap(s) {
    if (typeof s !== "string") return false
    if (s.length > MAX_BYTES) return true
    return utf8Length(s) > MAX_BYTES
}

// ---------------------------------------------------------------- request

// Start one bounded GET with the given XMLHttpRequest object.
//
// onDone(error, text) runs exactly once: error is "" on success (text is the
// body, within the cap) or a short message for the user (text is "").
// Returns a handle { abort(reason), checkBuffer(), timeout(), finished }, or
// null when the URL is refused, in which case open() is never called and
// onDone has already run with the error.
//
// The caller drives checkBuffer() from a short timer while the request is in
// flight, and timeout() from a TIMEOUT_MS timer.
function startGet(xhr, url, onDone) {
    var kind = requestKind(url)
    if (!kind) {
        onDone("Refused: not an allowed grokipedia.com URL.", "")
        return null
    }

    var handle = { finished: false, kind: kind, url: url }

    function finish(error, text) {
        if (handle.finished) return
        handle.finished = true
        onDone(error, error ? "" : text)
    }

    function fail(error) {
        if (handle.finished) return
        handle.finished = true
        xhr.onreadystatechange = function () {}
        try { xhr.abort() } catch (e) {}
        onDone(error, "")
    }

    // responseURL must be the requested URL (Qt reports it percent-decoded,
    // e.g. "q=periodic table", so compare decoded forms), or a redirect onto
    // a URL of the same kind (home stays home, search stays search).
    function redirectOk() {
        var r = xhr.responseURL
        if (r === undefined || r === null || r === "") return true
        r = String(r)
        if (r === url) return true
        var a = safeDecode(r)
        if (a !== null && a === safeDecode(url)) return true
        return requestKind(r) === kind
    }

    function statusOk() {
        return xhr.status === 200
    }

    xhr.onreadystatechange = function () {
        if (handle.finished) return
        var state = xhr.readyState
        if (state === 2) {                       // HEADERS_RECEIVED
            if (!redirectOk()) return fail("Refused: the site redirected off the allowed URL.")
            if (!statusOk()) return fail("Grokipedia answered HTTP " + xhr.status + ".")
            var len = parseInt(xhr.getResponseHeader("Content-Length") || "", 10)
            if (isFinite(len) && len > MAX_BYTES) return fail("Refused: response larger than 256 KiB.")
            var type = String(xhr.getResponseHeader("Content-Type") || "").toLowerCase()
            if (type && type.indexOf("text/html") === -1) return fail("Unexpected response type from Grokipedia.")
        } else if (state === 3) {                // LOADING
            if (!redirectOk()) return fail("Refused: the site redirected off the allowed URL.")
            handle.checkBuffer()
        } else if (state === 4) {                // DONE
            if (!redirectOk()) return fail("Refused: the site redirected off the allowed URL.")
            if (xhr.status === 0) return fail("Network error: could not reach grokipedia.com.")
            if (!statusOk()) return fail("Grokipedia answered HTTP " + xhr.status + ".")
            var text = xhr.responseText
            if (overCap(text)) { text = ""; return fail("Refused: response larger than 256 KiB.") }
            finish("", typeof text === "string" ? text : "")
        }
    }

    handle.checkBuffer = function () {
        if (handle.finished) return
        var state = xhr.readyState
        if (state !== 3 && state !== 4) return
        if (overCap(xhr.responseText)) fail("Refused: response larger than 256 KiB.")
    }
    handle.timeout = function () {
        fail("Timed out after " + Math.round(TIMEOUT_MS / 1000) + " s.")
    }
    handle.abort = function (reason) {
        fail(reason || "Cancelled.")
    }

    xhr.open("GET", url)
    xhr.setRequestHeader("Accept", "text/html")
    xhr.send()
    return handle
}
