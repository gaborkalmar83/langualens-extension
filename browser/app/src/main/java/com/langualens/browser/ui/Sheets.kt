package com.langualens.browser.ui

import android.content.Intent
import android.view.View
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.widget.SwitchCompat
import androidx.lifecycle.lifecycleScope
import com.google.android.material.bottomsheet.BottomSheetDialog
import com.langualens.browser.BrowserActivity
import com.langualens.browser.R
import com.langualens.browser.data.Prefs
import com.langualens.browser.translate.Languages
import com.langualens.browser.translate.Translate
import com.langualens.browser.util.Colors
import com.langualens.browser.util.DefaultBrowser
import com.langualens.browser.util.Urls
import kotlinx.coroutines.launch

/**
 * Every panel the browser puts up.
 *
 * Kept in one file on purpose: they are all short, they all read and write the
 * same handful of preferences, and splitting them across five files would make
 * the settings harder to see as a whole than they are to use.
 */
object Sheets {

    /* ------------------------------- welcome ------------------------------- */

    /** Asked once, on first run. One question, then an offer, then out of the way. */
    fun welcome(act: BrowserActivity, prefs: Prefs, done: () -> Unit) {
        val languages = Languages.ORDERED
        AlertDialog.Builder(act)
            .setTitle(R.string.welcome_title)
            .setItems(languages.map { it.label }.toTypedArray()) { _, which ->
                prefs.knownLanguage = languages[which].tag
                prefs.welcomeSeen = true
                done()
                offerDefaultBrowser(act)
            }
            .setCancelable(false)
            .show()
    }

    private fun offerDefaultBrowser(act: BrowserActivity) {
        if (act.isDefaultBrowser()) return
        AlertDialog.Builder(act)
            .setTitle(R.string.default_title)
            .setMessage(R.string.default_body)
            .setPositiveButton(R.string.default_yes) { _, _ -> DefaultBrowser.request(act) }
            .setNegativeButton(R.string.not_now, null)
            .show()
    }

    /* -------------------------------- menu -------------------------------- */

    fun menu(act: BrowserActivity) {
        val sheet = BottomSheetDialog(act)
        val view = act.layoutInflater.inflate(R.layout.sheet_menu, null)
        sheet.setContentView(view)

        fun row(id: Int, action: () -> Unit) {
            view.findViewById<View>(id).setOnClickListener {
                sheet.dismiss()
                action()
            }
        }

        row(R.id.mNewTab) { act.newTab(null) }
        row(R.id.mReload) { act.reload() }
        row(R.id.mShare) { act.share() }
        row(R.id.mChrome) { act.openInChrome() }
        row(R.id.mSaved) { act.startActivity(Intent(act, SavedActivity::class.java)) }
        row(R.id.mSettings) { settings(act) }

        val makeDefault = view.findViewById<View>(R.id.mDefault)
        makeDefault.visibility = if (act.isDefaultBrowser()) View.GONE else View.VISIBLE
        row(R.id.mDefault) { DefaultBrowser.request(act) }

        sheet.show()
    }

    /* ------------------------------ settings ------------------------------ */

    fun settings(act: BrowserActivity) {
        val prefs = act.prefs()
        val sheet = BottomSheetDialog(act)
        val view = act.layoutInflater.inflate(R.layout.sheet_settings, null)
        sheet.setContentView(view)

        val knownValue = view.findViewById<TextView>(R.id.sKnownValue)
        val pageValue = view.findViewById<TextView>(R.id.sPageValue)
        val modeValue = view.findViewById<TextView>(R.id.sModeValue)
        val colorValue = view.findViewById<TextView>(R.id.sColorValue)
        val searchValue = view.findViewById<TextView>(R.id.sSearchValue)
        val defaultValue = view.findViewById<TextView>(R.id.sDefaultValue)

        fun refresh() {
            knownValue.text = Languages.labelOf(prefs.knownLanguage)
            pageValue.text =
                if (prefs.autoDetect) act.getString(R.string.detect_automatically)
                else Languages.labelOf(prefs.pageLanguage)
            modeValue.text = act.getString(
                if (prefs.mode == "sentence") R.string.mode_sentence else R.string.mode_paragraph
            )
            colorValue.text = Colors.of(prefs.colorPreset).name
            searchValue.text = searchName(prefs.searchTemplate)
            defaultValue.text = act.getString(
                if (act.isDefaultBrowser()) R.string.yes else R.string.no
            )
        }
        refresh()

        view.findViewById<View>(R.id.sKnown).setOnClickListener {
            pickLanguage(act, R.string.known_language, false) { tag ->
                prefs.knownLanguage = tag
                refresh()
                act.retranslate()
            }
        }
        view.findViewById<View>(R.id.sPage).setOnClickListener {
            pickLanguage(act, R.string.page_language, true) { tag ->
                prefs.pageLanguage = tag
                refresh()
                act.retranslate()
            }
        }
        view.findViewById<View>(R.id.sMode).setOnClickListener {
            val options = arrayOf(
                act.getString(R.string.mode_paragraph),
                act.getString(R.string.mode_sentence)
            )
            AlertDialog.Builder(act)
                .setTitle(R.string.mode)
                .setItems(options) { _, which ->
                    prefs.mode = if (which == 1) "sentence" else "paragraph"
                    refresh()
                    act.retranslate()
                }
                .show()
        }
        view.findViewById<View>(R.id.sColor).setOnClickListener {
            val presets = Colors.PRESETS
            AlertDialog.Builder(act)
                .setTitle(R.string.color)
                .setItems(presets.map { it.name }.toTypedArray()) { _, which ->
                    prefs.colorPreset = presets[which].id
                    refresh()
                    act.refreshReading()
                }
                .show()
        }
        view.findViewById<View>(R.id.sSearch).setOnClickListener {
            AlertDialog.Builder(act)
                .setTitle(R.string.search_engine)
                .setItems(SEARCH.map { it.first }.toTypedArray()) { _, which ->
                    prefs.searchTemplate = SEARCH[which].second
                    refresh()
                }
                .show()
        }
        view.findViewById<View>(R.id.sDefault).setOnClickListener {
            DefaultBrowser.request(act)
            sheet.dismiss()
        }
        view.findViewById<View>(R.id.sModels).setOnClickListener {
            sheet.dismiss()
            models(act)
        }

        val swAuto = view.findViewById<SwitchCompat>(R.id.swAuto)
        swAuto.isChecked = prefs.autoTranslate
        swAuto.setOnCheckedChangeListener { _, checked -> prefs.autoTranslate = checked }

        val swHide = view.findViewById<SwitchCompat>(R.id.swHide)
        swHide.isChecked = prefs.hideUntilTapped
        swHide.setOnCheckedChangeListener { _, checked ->
            prefs.hideUntilTapped = checked
            act.refreshReading()
        }

        val host = Urls.hostOf(act.currentTab()?.url)
        val swExclude = view.findViewById<SwitchCompat>(R.id.swExclude)
        if (host.isBlank()) {
            swExclude.visibility = View.GONE
        } else {
            swExclude.text = act.getString(R.string.never_here, host)
            swExclude.isChecked = prefs.isExcluded(host)
            swExclude.setOnCheckedChangeListener { _, _ ->
                prefs.toggleExcluded(host)
                act.refreshReading()
            }
        }

        view.findViewById<TextView>(R.id.sVersion).text =
            act.getString(R.string.version_line, com.langualens.browser.BuildConfig.VERSION_NAME)

        sheet.show()
    }

    private fun pickLanguage(
        act: BrowserActivity,
        titleRes: Int,
        withAuto: Boolean,
        onPick: (String) -> Unit
    ) {
        val languages = Languages.ORDERED
        val labels = ArrayList<String>()
        val tags = ArrayList<String>()
        if (withAuto) {
            labels.add(act.getString(R.string.detect_automatically))
            tags.add(Prefs.AUTO)
        }
        languages.forEach { labels.add(it.label); tags.add(it.tag) }
        AlertDialog.Builder(act)
            .setTitle(titleRes)
            .setItems(labels.toTypedArray()) { _, which -> onPick(tags[which]) }
            .show()
    }

    /** Downloaded models, and a way to get the space back. */
    private fun models(act: BrowserActivity) {
        act.lifecycleScope.launch {
            val tags = Translate.downloadedTags().sorted()
            if (tags.isEmpty()) {
                AlertDialog.Builder(act)
                    .setTitle(R.string.models)
                    .setMessage(R.string.models_none)
                    .setPositiveButton(android.R.string.ok, null)
                    .show()
                return@launch
            }
            AlertDialog.Builder(act)
                .setTitle(R.string.models)
                .setItems(tags.map { Languages.labelOf(it) }.toTypedArray()) { _, which ->
                    val tag = tags[which]
                    AlertDialog.Builder(act)
                        .setTitle(Languages.labelOf(tag))
                        .setMessage(R.string.models_delete_body)
                        .setPositiveButton(R.string.delete) { _, _ ->
                            act.lifecycleScope.launch {
                                val ok = Translate.deleteModel(tag)
                                act.toast(
                                    act.getString(if (ok) R.string.deleted else R.string.delete_failed)
                                )
                            }
                        }
                        .setNegativeButton(android.R.string.cancel, null)
                        .show()
                }
                .setPositiveButton(android.R.string.ok, null)
                .show()
        }
    }

    /* -------------------------------- tabs -------------------------------- */

    fun tabs(act: BrowserActivity) {
        val list = act.tabList()
        val sheet = BottomSheetDialog(act)
        val view = act.layoutInflater.inflate(R.layout.sheet_tabs, null)
        sheet.setContentView(view)

        val container = view.findViewById<android.widget.LinearLayout>(R.id.tabList)

        fun rebuild() {
            container.removeAllViews()
            list.all.forEachIndexed { index, tab ->
                val row = act.layoutInflater.inflate(R.layout.item_tab, container, false)
                row.findViewById<TextView>(R.id.tabTitle).text =
                    tab.title.ifBlank { act.getString(R.string.new_tab) }
                row.findViewById<TextView>(R.id.tabUrl).text = Urls.pretty(tab.url)
                row.isSelected = index == list.currentIndex
                row.setOnClickListener {
                    list.select(tab)
                    act.translateCurrentIfAuto()
                    sheet.dismiss()
                }
                row.findViewById<View>(R.id.tabClose).setOnClickListener {
                    list.close(tab)
                    if (list.size == 0) {
                        sheet.dismiss()
                        act.newTab(null)
                    } else {
                        rebuild()
                    }
                }
                container.addView(row)
            }
        }
        rebuild()

        view.findViewById<View>(R.id.tabNew).setOnClickListener {
            sheet.dismiss()
            act.newTab(null)
        }
        sheet.show()
    }

    /* ------------------------------- helpers ------------------------------- */

    private val SEARCH = listOf(
        "DuckDuckGo" to "https://duckduckgo.com/?q=%s",
        "Google" to "https://www.google.com/search?q=%s",
        "Bing" to "https://www.bing.com/search?q=%s",
        "Startpage" to "https://www.startpage.com/sp/search?query=%s"
    )

    private fun searchName(template: String): String =
        SEARCH.firstOrNull { it.second == template }?.first ?: template
}
