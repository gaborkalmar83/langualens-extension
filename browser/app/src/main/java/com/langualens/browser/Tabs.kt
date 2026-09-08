package com.langualens.browser

import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import android.widget.FrameLayout

/**
 * One open page.
 *
 * Alongside the WebView it carries what the reader needs to know about this
 * particular page: whether the script is in yet, whether a translation pass has
 * run, and what language the page turned out to be in. All of that resets on
 * every navigation, which is why it lives per tab rather than per app.
 */
class Tab(val web: WebView) {
    var injected = false
    var translated = false
    /** Set while a pass is in flight, so a second onPageFinished does not start another. */
    var translating = false
    /** The language this page is written in, once detected. */
    var source: String? = null
    /** Set when the page is in the language you already know, so the pass is pointless. */
    var alreadyKnown = false

    val title: String get() = web.title?.takeIf { it.isNotBlank() } ?: url
    val url: String get() = web.url.orEmpty()

    fun resetForNewPage() {
        injected = false
        translated = false
        translating = false
        source = null
        alreadyKnown = false
    }
}

/**
 * The open tabs and which one is on screen.
 *
 * Every tab keeps a live WebView, which is what makes switching instant and what
 * puts a ceiling on how many there can be: [MAX] of them, after which the oldest
 * untouched one is closed. A browser this size is for reading a few pages at a
 * time, not for hoarding forty.
 */
class Tabs(
    private val container: FrameLayout,
    private val create: () -> WebView,
    private val onChanged: () -> Unit
) {
    private val items = mutableListOf<Tab>()
    var currentIndex = -1
        private set

    val size: Int get() = items.size
    val current: Tab? get() = items.getOrNull(currentIndex)
    val all: List<Tab> get() = items.toList()

    fun open(url: String?): Tab {
        if (items.size >= MAX) close(items.first())
        val tab = Tab(create())
        items.add(tab)
        container.addView(
            tab.web,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
        )
        select(items.lastIndex)
        if (!url.isNullOrBlank()) tab.web.loadUrl(url)
        return tab
    }

    fun select(index: Int) {
        if (index !in items.indices) return
        currentIndex = index
        items.forEachIndexed { i, tab ->
            tab.web.visibility = if (i == index) View.VISIBLE else View.GONE
            if (i == index) tab.web.onResume() else tab.web.onPause()
        }
        onChanged()
    }

    fun select(tab: Tab) = select(items.indexOf(tab))

    fun close(tab: Tab) {
        val index = items.indexOf(tab)
        if (index < 0) return
        items.removeAt(index)
        container.removeView(tab.web)
        destroy(tab.web)
        if (items.isEmpty()) {
            currentIndex = -1
            onChanged()
            return
        }
        select(index.coerceAtMost(items.lastIndex))
    }

    fun closeAll() {
        items.forEach {
            container.removeView(it.web)
            destroy(it.web)
        }
        items.clear()
        currentIndex = -1
        onChanged()
    }

    fun of(web: WebView): Tab? = items.firstOrNull { it.web === web }

    private fun destroy(web: WebView) {
        web.stopLoading()
        web.removeJavascriptInterface(BRIDGE_NAME)
        web.loadUrl("about:blank")
        web.destroy()
    }

    companion object {
        const val MAX = 12
        const val BRIDGE_NAME = "LL"
    }
}
