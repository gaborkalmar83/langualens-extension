package com.langualens.browser

import android.annotation.SuppressLint
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Message
import android.view.KeyEvent
import android.view.View
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.webkit.ValueCallback
import android.webkit.WebChromeClient
import android.webkit.WebResourceRequest
import android.webkit.WebSettings
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.EditText
import android.widget.FrameLayout
import android.widget.ImageButton
import android.widget.ProgressBar
import android.widget.TextView
import android.widget.Toast
import androidx.activity.OnBackPressedCallback
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.langualens.browser.data.Prefs
import com.langualens.browser.data.Vocab
import com.langualens.browser.translate.Detect
import com.langualens.browser.translate.Languages
import com.langualens.browser.translate.Translate
import com.langualens.browser.ui.Sheets
import com.langualens.browser.util.Colors
import com.langualens.browser.util.DefaultBrowser
import com.langualens.browser.util.Handoff
import com.langualens.browser.util.Speaker
import com.langualens.browser.util.Urls
import kotlinx.coroutines.launch
import org.json.JSONObject
import org.json.JSONTokener

/**
 * The whole browser.
 *
 * One activity, a stack of WebViews and a script injected into each page. There
 * is no custom rendering engine here and there could not be: the WebView *is*
 * Chromium, the same engine Chrome uses, kept up to date by the system. What
 * this app adds is the line underneath every paragraph, and the good sense to
 * hand the page to Chrome when you reach something you should be typing a
 * password into.
 */
class BrowserActivity : AppCompatActivity() {

    private lateinit var prefs: Prefs
    private lateinit var vocab: Vocab
    private lateinit var tabs: Tabs

    private lateinit var urlBar: EditText
    private lateinit var loadBar: ProgressBar
    private lateinit var status: TextView
    private lateinit var webContainer: FrameLayout
    private lateinit var btnTranslate: ImageButton
    private lateinit var btnBack: ImageButton
    private lateinit var btnForward: ImageButton
    private lateinit var btnTabs: TextView

    private var fileCallback: ValueCallback<Array<Uri>>? = null

    private val filePicker =
        registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
            val callback = fileCallback ?: return@registerForActivityResult
            fileCallback = null
            callback.onReceiveValue(
                WebChromeClient.FileChooserParams.parseResult(result.resultCode, result.data)
            )
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_browser)

        prefs = Prefs(this)
        vocab = Vocab(this)
        Speaker.init(this)

        urlBar = findViewById(R.id.urlBar)
        loadBar = findViewById(R.id.loadBar)
        status = findViewById(R.id.status)
        webContainer = findViewById(R.id.webContainer)
        btnTranslate = findViewById(R.id.btnTranslate)
        btnBack = findViewById(R.id.btnBack)
        btnForward = findViewById(R.id.btnForward)
        btnTabs = findViewById(R.id.btnTabs)

        tabs = Tabs(webContainer, ::newWebView) { onTabsChanged() }

        wireBars()
        wireBackButton()

        val startUrl = urlFrom(intent) ?: prefs.homeUrl.ifBlank { prefs.lastUrl }
        tabs.open(startUrl.ifBlank { null })
        if (startUrl.isBlank()) showStart()

        if (!prefs.welcomeSeen) Sheets.welcome(this, prefs) { onTabsChanged() }
    }

    /* ------------------------------ chrome ------------------------------ */

    private fun wireBars() {
        urlBar.setOnEditorActionListener { _, actionId, event ->
            // A hardware Enter arrives twice, down and up; only the first counts.
            val entered = actionId == EditorInfo.IME_ACTION_GO ||
                actionId == EditorInfo.IME_ACTION_DONE ||
                (event != null && event.keyCode == KeyEvent.KEYCODE_ENTER &&
                    event.action == KeyEvent.ACTION_DOWN)
            if (entered) {
                go(urlBar.text.toString())
                true
            } else {
                false
            }
        }
        // Tapping the bar reveals the whole address; leaving it puts the host back,
        // because a full URL is unreadable at this width and the host is what you
        // actually check.
        urlBar.setOnFocusChangeListener { _, focused ->
            val tab = tabs.current
            if (focused) {
                urlBar.setText(tab?.url.orEmpty())
                urlBar.selectAll()
            } else {
                urlBar.setText(Urls.pretty(tab?.url))
            }
        }

        btnTranslate.setOnClickListener { toggleTranslation() }
        findViewById<View>(R.id.btnMenu).setOnClickListener { Sheets.menu(this) }

        btnBack.setOnClickListener { goBack() }
        btnForward.setOnClickListener { tabs.current?.web?.takeIf { it.canGoForward() }?.goForward() }
        btnTabs.setOnClickListener { Sheets.tabs(this) }
        findViewById<View>(R.id.btnChrome).setOnClickListener { openInChrome() }
        findViewById<View>(R.id.btnNewTab).setOnClickListener { newTab(null) }
    }

    private fun wireBackButton() {
        onBackPressedDispatcher.addCallback(this, object : OnBackPressedCallback(true) {
            override fun handleOnBackPressed() {
                val web = tabs.current?.web
                when {
                    web != null && web.canGoBack() -> web.goBack()
                    tabs.size > 1 -> tabs.current?.let { tabs.close(it) }
                    else -> finish()
                }
            }
        })
    }

    private fun goBack() {
        val web = tabs.current?.web ?: return
        if (web.canGoBack()) web.goBack() else onBackPressedDispatcher.onBackPressed()
    }

    private fun onTabsChanged() {
        val tab = tabs.current
        btnTabs.text = tabs.size.toString()
        if (!urlBar.hasFocus()) urlBar.setText(Urls.pretty(tab?.url))
        btnBack.isEnabled = tab?.web?.canGoBack() == true
        btnForward.isEnabled = tab?.web?.canGoForward() == true
        btnBack.alpha = if (btnBack.isEnabled) 1f else 0.35f
        btnForward.alpha = if (btnForward.isEnabled) 1f else 0.35f
        btnTranslate.isSelected = tab?.translated == true
        btnTranslate.alpha = if (prefs.isExcluded(Urls.hostOf(tab?.url))) 0.35f else 1f
    }

    /* ---------------------------- navigation ---------------------------- */

    fun go(input: String) {
        val url = Urls.resolve(input, prefs.searchTemplate)
        hideKeyboard()
        urlBar.clearFocus()
        val tab = tabs.current ?: tabs.open(null)
        tab.web.loadUrl(url)
    }

    fun newTab(url: String?) {
        tabs.open(url)
        if (url == null) {
            showStart()
            urlBar.requestFocus()
            showKeyboard()
        }
    }

    private fun urlFrom(intent: Intent?): String? {
        if (intent == null) return null
        intent.dataString?.takeIf { Urls.isHttp(it) }?.let { return it }
        if (intent.action == Intent.ACTION_SEND) {
            val shared = intent.getStringExtra(Intent.EXTRA_TEXT)
            Urls.firstUrlIn(shared)?.let { return it }
            if (!shared.isNullOrBlank()) return Urls.resolve(shared, prefs.searchTemplate)
        }
        if (intent.action == Intent.ACTION_WEB_SEARCH) {
            val query = intent.getStringExtra("query")
            if (!query.isNullOrBlank()) return Urls.resolve(query, prefs.searchTemplate)
        }
        return null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        urlFrom(intent)?.let { newTab(it) }
    }

    /** The blank page a new tab starts on. Local, so it works offline. */
    private fun showStart() {
        val tab = tabs.current ?: return
        val html = """
            <!doctype html><html><head>
            <meta name="viewport" content="width=device-width,initial-scale=1">
            <style>
              body{margin:0;display:flex;align-items:center;justify-content:center;
                   height:100vh;font-family:-apple-system,Roboto,sans-serif;
                   background:#fbfaf7;color:#5b6472;text-align:center;padding:24px;}
              @media (prefers-color-scheme: dark){body{background:#12151c;color:#8a94a6;}}
              h1{font-size:19px;font-weight:600;margin:0 0 8px;color:#3F7CFF;}
              p{font-size:14px;line-height:1.5;margin:0;}
            </style></head><body><div>
              <h1>LanguaLens</h1>
              <p>Type an address above.<br>Every page you open gets the translation
              on the line underneath.</p>
            </div></body></html>
        """.trimIndent()
        tab.web.loadDataWithBaseURL(null, html, "text/html", "utf-8", null)
    }

    /* ----------------------------- webview ----------------------------- */

    @SuppressLint("SetJavaScriptEnabled")
    private fun newWebView(): WebView {
        val web = WebView(this)
        with(web.settings) {
            javaScriptEnabled = true
            domStorageEnabled = true
            databaseEnabled = true
            loadWithOverviewMode = true
            useWideViewPort = true
            builtInZoomControls = true
            displayZoomControls = false
            setSupportMultipleWindows(true)
            javaScriptCanOpenWindowsAutomatically = false
            mediaPlaybackRequiresUserGesture = true
            mixedContentMode = WebSettings.MIXED_CONTENT_COMPATIBILITY_MODE
            // Sites serve a stripped-down page to anything that admits to being a
            // WebView, which is exactly the page the reader has least to work with.
            userAgentString = userAgentString.replace("; wv", "")
        }
        web.isVerticalScrollBarEnabled = true
        web.addJavascriptInterface(Bridge(web), Tabs.BRIDGE_NAME)

        web.webViewClient = object : WebViewClient() {
            override fun shouldOverrideUrlLoading(
                view: WebView?,
                request: WebResourceRequest?
            ): Boolean {
                val url = request?.url?.toString() ?: return false
                if (Urls.isHttp(url)) return false
                // mailto:, tel:, market: and the rest belong to whichever app owns
                // them. intent:// needs unpacking first, and its browser_fallback_url
                // is what to load when nothing on the phone claims it.
                return try {
                    if (url.startsWith("intent:")) {
                        val parsed = Intent.parseUri(url, Intent.URI_INTENT_SCHEME)
                        try {
                            startActivity(parsed)
                        } catch (t: Throwable) {
                            parsed.getStringExtra("browser_fallback_url")
                                ?.let { view?.loadUrl(it) }
                        }
                    } else {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                    }
                    true
                } catch (t: Throwable) {
                    true
                }
            }

            override fun onPageStarted(view: WebView?, url: String?, favicon: android.graphics.Bitmap?) {
                view?.let { tabs.of(it) }?.resetForNewPage()
                onTabsChanged()
            }

            override fun onPageFinished(view: WebView?, url: String?) {
                val tab = view?.let { tabs.of(it) } ?: return
                onTabsChanged()
                if (tab !== tabs.current) return
                if (!prefs.autoTranslate) return
                if (prefs.isExcluded(Urls.hostOf(url))) return
                if (!Urls.isHttp(url)) return
                translate(tab)
            }
        }

        web.webChromeClient = object : WebChromeClient() {
            override fun onProgressChanged(view: WebView?, newProgress: Int) {
                if (view !== tabs.current?.web) return
                loadBar.progress = newProgress
                loadBar.visibility = if (newProgress in 1..99) View.VISIBLE else View.GONE
            }

            override fun onReceivedTitle(view: WebView?, title: String?) = onTabsChanged()

            override fun onCreateWindow(
                view: WebView?,
                isDialog: Boolean,
                isUserGesture: Boolean,
                resultMsg: Message?
            ): Boolean {
                val transport = resultMsg?.obj as? WebView.WebViewTransport ?: return false
                val tab = tabs.open(null)
                transport.webView = tab.web
                resultMsg.sendToTarget()
                return true
            }

            override fun onShowFileChooser(
                webView: WebView?,
                callback: ValueCallback<Array<Uri>>?,
                params: FileChooserParams?
            ): Boolean {
                val intent = params?.createIntent() ?: return false
                fileCallback?.onReceiveValue(null)
                fileCallback = callback
                return try {
                    filePicker.launch(intent)
                    true
                } catch (t: Throwable) {
                    fileCallback = null
                    false
                }
            }
        }

        // A download is the other thing this app should not be doing itself.
        web.setDownloadListener { url, _, _, _, _ ->
            if (!Handoff.open(this, url)) toast(getString(R.string.no_browser))
        }
        return web
    }

    /* ---------------------------- translating ---------------------------- */

    private fun toggleTranslation() {
        val tab = tabs.current ?: return
        if (prefs.isExcluded(Urls.hostOf(tab.url))) {
            toast(getString(R.string.excluded_here, Urls.hostOf(tab.url)))
            return
        }
        if (tab.translated) {
            tab.web.evaluateJavascript("if(window.llClear)llClear();", null)
            tab.translated = false
            onTabsChanged()
        } else {
            translate(tab)
        }
    }

    /** Injects the reader if needed, works out the page language, then runs a pass. */
    fun translate(tab: Tab) {
        if (tab.translated || tab.translating || tab.alreadyKnown) return
        tab.translating = true
        inject(tab)
        lifecycleScope.launch {
            try {
                val source = sourceFor(tab) ?: return@launch
                val target = prefs.knownLanguage
                if (source == target) {
                    tab.alreadyKnown = true
                    toast(getString(R.string.already_in, Languages.nameOf(target)))
                    return@launch
                }
                if (!Translate.isReady(source, target)) {
                    setStatus(getString(R.string.downloading, Languages.nameOf(source)))
                    val error = Translate.prepare(source, target)
                    setStatus(null)
                    if (error != null) {
                        toast(error)
                        return@launch
                    }
                }
                tab.translated = true
                onTabsChanged()
                tab.web.evaluateJavascript("if(window.llRun){llRun();llWatch(true);}", null)
            } finally {
                tab.translating = false
            }
        }
    }

    private fun inject(tab: Tab) {
        if (tab.injected) return
        val script = try {
            assets.open("inline.js").bufferedReader().use { it.readText() }
        } catch (t: Throwable) {
            toast(getString(R.string.reader_missing)); return
        }
        val color = Colors.of(prefs.colorPreset)
        val bootstrap = """
            window.__llMode = ${JSONObject.quote(prefs.mode)};
            window.__llHidden = ${prefs.hideUntilTapped};
            window.__llHint = ${JSONObject.quote(getString(R.string.tap_to_reveal))};
            window.__llLight = ${JSONObject.quote(color.light)};
            window.__llDark = ${JSONObject.quote(color.dark)};
        """.trimIndent()
        tab.web.evaluateJavascript(bootstrap, null)
        tab.web.evaluateJavascript(script, null)
        tab.injected = true
    }

    /** Cached per page: detection costs a round trip into the page and back. */
    private suspend fun sourceFor(tab: Tab): String? {
        tab.source?.let { return it }
        if (!prefs.autoDetect) return prefs.pageLanguage.also { tab.source = it }

        val probe = evaluate(
            tab,
            "JSON.stringify({s:(window.llSample?llSample():''),l:document.documentElement.lang||''})"
        )
        val sample: String
        val declared: String
        try {
            val o = JSONObject(probe ?: "{}")
            sample = o.optString("s")
            declared = o.optString("l")
        } catch (t: Throwable) {
            return null
        }
        val detected = Detect.of(sample, declared)
        if (detected == null) {
            toast(getString(R.string.cannot_detect))
            return null
        }
        tab.source = detected
        return detected
    }

    /** evaluateJavascript hands back a JSON literal; this unwraps it to the value. */
    private suspend fun evaluate(tab: Tab, js: String): String? =
        kotlinx.coroutines.suspendCancellableCoroutine { cont ->
            try {
                tab.web.evaluateJavascript(js) { raw ->
                    val value = try {
                        JSONTokener(raw ?: "null").nextValue() as? String
                    } catch (t: Throwable) {
                        null
                    }
                    if (cont.isActive) cont.resumeWith(Result.success(value))
                }
            } catch (t: Throwable) {
                if (cont.isActive) cont.resumeWith(Result.success(null))
            }
        }

    /** Re-runs the current page after a setting that changes how it looks. */
    fun refreshReading() {
        val tab = tabs.current ?: return
        tab.web.evaluateJavascript("if(window.llSetHidden)llSetHidden(${prefs.hideUntilTapped});", null)
        val color = Colors.of(prefs.colorPreset)
        tab.web.evaluateJavascript(
            "if(window.llSetColor)llSetColor(${JSONObject.quote(color.light)},${JSONObject.quote(color.dark)});",
            null
        )
        onTabsChanged()
    }

    /** A changed language pair or mode means the existing lines are wrong. */
    fun retranslate() {
        val tab = tabs.current ?: return
        tab.web.evaluateJavascript("if(window.llClear)llClear();", null)
        tab.translated = false
        tab.translating = false
        tab.alreadyKnown = false
        tab.source = null
        // Mode is read when the script loads, so a mode change needs a fresh page.
        tab.injected = false
        tab.web.reload()
    }

    /* ------------------------------ actions ------------------------------ */

    fun openInChrome() {
        val url = tabs.current?.url.orEmpty()
        if (!Urls.isHttp(url)) {
            toast(getString(R.string.nothing_to_hand_over))
            return
        }
        if (!Handoff.open(this, url)) toast(getString(R.string.no_browser))
    }

    fun share() {
        val url = tabs.current?.url.orEmpty()
        if (!Urls.isHttp(url)) return
        startActivity(
            Intent.createChooser(
                Intent(Intent.ACTION_SEND)
                    .setType("text/plain")
                    .putExtra(Intent.EXTRA_TEXT, url)
                    .putExtra(Intent.EXTRA_SUBJECT, tabs.current?.title.orEmpty()),
                null
            )
        )
    }

    fun reload() {
        tabs.current?.web?.reload()
    }

    /** Called after a tab switch: a page loaded in the background is not translated yet. */
    fun translateCurrentIfAuto() {
        val tab = tabs.current ?: return
        if (!prefs.autoTranslate || tab.translated || tab.alreadyKnown) return
        if (!Urls.isHttp(tab.url)) return
        if (prefs.isExcluded(Urls.hostOf(tab.url))) return
        translate(tab)
    }

    fun toast(message: String) = Toast.makeText(this, message, Toast.LENGTH_SHORT).show()

    private fun setStatus(text: String?) {
        status.text = text.orEmpty()
        status.visibility = if (text.isNullOrBlank()) View.GONE else View.VISIBLE
    }

    private fun hideKeyboard() {
        val imm = getSystemService(InputMethodManager::class.java)
        imm?.hideSoftInputFromWindow(urlBar.windowToken, 0)
    }

    private fun showKeyboard() {
        val imm = getSystemService(InputMethodManager::class.java)
        imm?.showSoftInput(urlBar, InputMethodManager.SHOW_IMPLICIT)
    }

    /* ------------------------- accessors for the sheets ------------------------- */

    fun prefs(): Prefs = prefs
    fun vocab(): Vocab = vocab
    fun tabList(): Tabs = tabs
    fun currentTab(): Tab? = tabs.current
    fun isDefaultBrowser(): Boolean = DefaultBrowser.isDefault(this)

    override fun onPause() {
        super.onPause()
        tabs.current?.url?.takeIf { Urls.isHttp(it) }?.let { prefs.lastUrl = it }
    }

    override fun onDestroy() {
        tabs.closeAll()
        Speaker.shutdown()
        super.onDestroy()
    }

    /* ------------------------------ the bridge ------------------------------ */

    /**
     * What the page is allowed to ask the app for. Four methods, all of them
     * things the reader needs and nothing else: no file access, no storage, no
     * way to reach the tabs.
     */
    @Suppress("unused")
    inner class Bridge(private val web: WebView) {

        // Every method here is called on the WebView's JavaScript thread, so the
        // work is handed to the main thread before it touches the tab list or the
        // WebView itself.

        @android.webkit.JavascriptInterface
        fun requestTranslate(payload: String) {
            lifecycleScope.launch {
                val tab = tabs.of(web) ?: return@launch
                val source = tab.source ?: return@launch
                val items = parse(payload)
                if (items.isEmpty()) return@launch
                val out = Translate.translateAll(items.map { it.second }, source, prefs.knownLanguage)
                val obj = JSONObject()
                items.forEachIndexed { i, pair ->
                    out.getOrNull(i)?.takeIf { it.isNotBlank() }?.let { obj.put(pair.first, it) }
                }
                web.evaluateJavascript("window.llApply(${JSONObject.quote(obj.toString())});", null)
            }
        }

        @android.webkit.JavascriptInterface
        fun lookup(text: String) {
            lifecycleScope.launch {
                val tab = tabs.of(web) ?: return@launch
                val source = tab.source ?: sourceFor(tab) ?: return@launch
                val target = prefs.knownLanguage
                val translated = Translate.translate(text, source, target)
                val message = translated.ifBlank { getString(R.string.no_translation) }
                web.evaluateJavascript(
                    "if(window.llPopup)llPopup(${JSONObject.quote(message)});", null
                )
            }
        }

        @android.webkit.JavascriptInterface
        fun save(text: String, context: String, origin: String) {
            lifecycleScope.launch {
                val tab = tabs.of(web) ?: return@launch
                val source = tab.source ?: prefs.knownLanguage
                val target = prefs.knownLanguage
                val added = vocab.add(
                    Vocab.Item(
                        text = text.trim(),
                        translation = Translate.translate(text, source, target),
                        context = context,
                        origin = origin,
                        source = source,
                        target = target,
                        savedAt = System.currentTimeMillis()
                    )
                )
                toast(getString(if (added) R.string.saved else R.string.already_saved))
            }
        }

        @android.webkit.JavascriptInterface
        fun speak(text: String) {
            runOnUiThread {
                val tab = tabs.of(web) ?: return@runOnUiThread
                Speaker.speak(this@BrowserActivity, text, tab.source ?: prefs.knownLanguage)
            }
        }

        private fun parse(payload: String): List<Pair<String, String>> = try {
            val arr = org.json.JSONArray(payload)
            (0 until arr.length()).mapNotNull { i ->
                val o = arr.optJSONObject(i) ?: return@mapNotNull null
                val id = o.optString("id")
                val text = o.optString("text")
                if (id.isBlank() || text.isBlank()) null else id to text
            }
        } catch (t: Throwable) {
            emptyList()
        }
    }
}
