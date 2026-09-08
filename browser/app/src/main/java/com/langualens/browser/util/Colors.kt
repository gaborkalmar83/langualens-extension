package com.langualens.browser.util

/**
 * The colour the translation is drawn in.
 *
 * Two values per preset, because a colour that reads on a white page rarely
 * reads on a black one; the page's own background decides which is used, and
 * that decision is made in the page, not here. The hues come from the Okabe-Ito
 * palette, which stays distinguishable from ordinary body text under the common
 * forms of colour blindness, and there is a plain high-contrast option for
 * anyone who cannot use hue at all.
 */
object Colors {

    data class Preset(val id: String, val name: String, val light: String, val dark: String)

    val PRESETS = listOf(
        Preset("blue", "Blue", "#0072B2", "#7FB2FF"),
        Preset("orange", "Orange", "#B4460B", "#FF9E6B"),
        Preset("green", "Green", "#00695C", "#4FD1B0"),
        Preset("purple", "Purple", "#8E2F6B", "#F3A0CE"),
        Preset("contrast", "Maximum contrast", "#111111", "#FFFFFF")
    )

    private val byId = PRESETS.associateBy { it.id }

    fun of(id: String): Preset = byId[id] ?: PRESETS.first()
}
