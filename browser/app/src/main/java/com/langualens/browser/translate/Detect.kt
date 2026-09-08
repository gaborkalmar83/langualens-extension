package com.langualens.browser.translate

import com.google.mlkit.nl.languageid.LanguageIdentification
import com.google.mlkit.nl.languageid.LanguageIdentifier
import kotlinx.coroutines.tasks.await

/**
 * Works out what language a page is actually written in.
 *
 * The page's own `lang` attribute is not trusted on its own, because plenty of
 * sites declare `lang="en"` and then serve something else. ML Kit's identifier
 * gets the first say; the declaration is the fallback when it is not confident.
 */
object Detect {

    private const val MIN_CONFIDENCE = 0.5f
    private const val MIN_SAMPLE = 40

    private val client: LanguageIdentifier by lazy {
        LanguageIdentification.getClient(
            com.google.mlkit.nl.languageid.LanguageIdentificationOptions.Builder()
                .setConfidenceThreshold(MIN_CONFIDENCE)
                .build()
        )
    }

    /** Returns a supported language tag, or null when nothing can be said. */
    suspend fun of(sample: String, declared: String?): String? {
        val text = sample.trim()
        if (text.length >= MIN_SAMPLE) {
            try {
                val tag = Languages.base(client.identifyLanguage(text).await())
                if (tag.isNotEmpty() && tag != "und" && Languages.supports(tag)) return tag
            } catch (t: Throwable) {
                // fall through to the declaration
            }
        }
        val fallback = Languages.base(declared)
        return if (fallback.isNotEmpty() && Languages.supports(fallback)) fallback else null
    }
}
