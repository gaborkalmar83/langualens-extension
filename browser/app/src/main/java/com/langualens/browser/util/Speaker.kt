package com.langualens.browser.util

import android.content.Context
import android.speech.tts.TextToSpeech
import java.util.Locale

/**
 * Reads a selection aloud in whatever language the page is in.
 *
 * This is the one feature that might leave the device, and not because of
 * anything here: some system voices synthesise in the cloud. Which one yours
 * does is a setting of the TTS engine, not of this app.
 */
object Speaker {

    private var tts: TextToSpeech? = null
    private var ready = false

    fun init(context: Context) {
        if (tts != null) return
        tts = TextToSpeech(context.applicationContext) { status ->
            ready = status == TextToSpeech.SUCCESS
        }
    }

    fun speak(context: Context, text: String, languageTag: String) {
        init(context)
        val body = text.trim()
        if (body.isEmpty()) return
        val engine = tts ?: return
        if (!ready) return
        try {
            val result = engine.setLanguage(Locale.forLanguageTag(languageTag))
            if (result == TextToSpeech.LANG_MISSING_DATA ||
                result == TextToSpeech.LANG_NOT_SUPPORTED
            ) {
                engine.setLanguage(Locale.ENGLISH)
            }
        } catch (t: Throwable) {
            // keep whichever voice is already loaded
        }
        engine.speak(body, TextToSpeech.QUEUE_FLUSH, null, "langualens")
    }

    fun shutdown() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        ready = false
    }
}
