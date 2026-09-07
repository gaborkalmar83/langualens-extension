package com.langualens.browser.data

import android.content.Context
import android.content.SharedPreferences

/**
 * Everything the browser remembers. Deliberately short: one language you know,
 * one page language (usually auto), and a handful of reading switches.
 */
class Prefs(context: Context) {

    private val sp: SharedPreferences =
        context.applicationContext.getSharedPreferences("langualens_browser", Context.MODE_PRIVATE)

    /** The language you actually understand. Translations are shown in this. */
    var knownLanguage: String
        get() = sp.getString(KEY_KNOWN, "en") ?: "en"
        set(v) = sp.edit().putString(KEY_KNOWN, v).apply()

    /** The page's language, or [AUTO] to detect it per page. */
    var pageLanguage: String
        get() = sp.getString(KEY_PAGE, AUTO) ?: AUTO
        set(v) = sp.edit().putString(KEY_PAGE, v).apply()

    val autoDetect: Boolean get() = pageLanguage == AUTO

    /** Translate as soon as a page finishes loading. */
    var autoTranslate: Boolean
        get() = sp.getBoolean(KEY_AUTO, true)
        set(v) = sp.edit().putBoolean(KEY_AUTO, v).apply()

    /** "paragraph" (default) or "sentence". */
    var mode: String
        get() = sp.getString(KEY_MODE, "paragraph") ?: "paragraph"
        set(v) = sp.edit().putString(KEY_MODE, v).apply()

    /** Veil each translation until it is tapped, so you read the original first. */
    var hideUntilTapped: Boolean
        get() = sp.getBoolean(KEY_HIDE, false)
        set(v) = sp.edit().putBoolean(KEY_HIDE, v).apply()

    var colorPreset: String
        get() = sp.getString(KEY_COLOR, "blue") ?: "blue"
        set(v) = sp.edit().putString(KEY_COLOR, v).apply()

    /** Search engine query template, %s replaced by the terms. */
    var searchTemplate: String
        get() = sp.getString(KEY_SEARCH, DEFAULT_SEARCH) ?: DEFAULT_SEARCH
        set(v) = sp.edit().putString(KEY_SEARCH, v).apply()

    var homeUrl: String
        get() = sp.getString(KEY_HOME, "") ?: ""
        set(v) = sp.edit().putString(KEY_HOME, v).apply()

    /** Restored when the app is opened without a URL. */
    var lastUrl: String
        get() = sp.getString(KEY_LAST, "") ?: ""
        set(v) = sp.edit().putString(KEY_LAST, v).apply()

    var welcomeSeen: Boolean
        get() = sp.getBoolean(KEY_WELCOME, false)
        set(v) = sp.edit().putBoolean(KEY_WELCOME, v).apply()

    /** Hosts that are never translated and never get the selection bar. */
    var excluded: Set<String>
        get() = sp.getStringSet(KEY_EXCLUDED, emptySet()) ?: emptySet()
        set(v) = sp.edit().putStringSet(KEY_EXCLUDED, v).apply()

    fun isExcluded(host: String?): Boolean {
        val h = (host ?: "").lowercase().removePrefix("www.")
        if (h.isEmpty()) return false
        return excluded.any { entry ->
            val e = entry.lowercase().removePrefix("www.").trim()
            e.isNotEmpty() && (h == e || h.endsWith(".$e"))
        }
    }

    fun toggleExcluded(host: String?) {
        val h = (host ?: "").lowercase().removePrefix("www.")
        if (h.isEmpty()) return
        excluded = if (isExcluded(h)) excluded - h else excluded + h
    }

    companion object {
        const val AUTO = "auto"
        const val DEFAULT_SEARCH = "https://duckduckgo.com/?q=%s"

        private const val KEY_KNOWN = "known_language"
        private const val KEY_PAGE = "page_language"
        private const val KEY_AUTO = "auto_translate"
        private const val KEY_MODE = "reader_mode"
        private const val KEY_HIDE = "hide_until_tapped"
        private const val KEY_COLOR = "color_preset"
        private const val KEY_SEARCH = "search_template"
        private const val KEY_HOME = "home_url"
        private const val KEY_LAST = "last_url"
        private const val KEY_WELCOME = "welcome_seen"
        private const val KEY_EXCLUDED = "excluded_hosts"
    }
}
