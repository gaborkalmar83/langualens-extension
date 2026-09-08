package com.langualens.browser.util

import android.net.Uri
import android.util.Patterns

/** Turning whatever was typed in the address bar into something loadable. */
object Urls {

    private val SCHEME = Regex("^[a-zA-Z][a-zA-Z0-9+.-]*://")

    /**
     * A single token with a dot and no spaces is treated as an address; anything
     * else is a search. "localhost" and "about:blank" are handled too, because
     * both come up and neither looks like a domain.
     */
    fun resolve(input: String, searchTemplate: String): String {
        val text = input.trim()
        if (text.isEmpty()) return "about:blank"
        if (SCHEME.containsMatchIn(text)) return text
        if (text.startsWith("about:") || text.startsWith("data:")) return text

        val looksLikeHost = !text.contains(' ') &&
            (text == "localhost" || text.startsWith("localhost:") ||
                Patterns.WEB_URL.matcher(text).matches())

        return if (looksLikeHost) "https://$text"
        else searchTemplate.replace("%s", Uri.encode(text))
    }

    fun hostOf(url: String?): String =
        try { Uri.parse(url ?: "").host.orEmpty().removePrefix("www.") } catch (t: Throwable) { "" }

    /** What the address bar shows: the host alone, so the bar stays readable. */
    fun pretty(url: String?): String {
        val host = hostOf(url)
        return if (host.isNotEmpty()) host else (url ?: "")
    }

    fun isHttp(url: String?): Boolean =
        url != null && (url.startsWith("http://") || url.startsWith("https://"))

    /** Pulls the first link out of shared text, which usually has a title in front. */
    fun firstUrlIn(text: String?): String? =
        Regex("https?://\\S+").find(text ?: "")?.value
}
