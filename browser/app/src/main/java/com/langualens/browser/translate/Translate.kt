package com.langualens.browser.translate

import android.util.LruCache
import com.google.mlkit.common.model.DownloadConditions
import com.google.mlkit.common.model.RemoteModelManager
import com.google.mlkit.nl.translate.TranslateLanguage
import com.google.mlkit.nl.translate.TranslateRemoteModel
import com.google.mlkit.nl.translate.Translation
import com.google.mlkit.nl.translate.Translator
import com.google.mlkit.nl.translate.TranslatorOptions
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.awaitAll
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext
import java.util.concurrent.ConcurrentHashMap

/**
 * On-device translation between any two of ML Kit's languages.
 *
 * The model file is downloaded once per language and then works offline. No page
 * text is ever sent anywhere: only the model comes down, and it comes down from
 * Google's model service without carrying anything of yours with it.
 *
 * Unlike the phone app this is called per page rather than per session, so the
 * pair is passed in on every call instead of being held as global state.
 */
object Translate {

    private val clients = ConcurrentHashMap<String, Translator>()
    private val cache = LruCache<String, String>(4000)
    private val prepareLock = Mutex()
    private val readyPairs = HashSet<String>()

    private fun clientFor(source: String, target: String): Translator? {
        val src = TranslateLanguage.fromLanguageTag(source) ?: return null
        val tgt = TranslateLanguage.fromLanguageTag(target) ?: return null
        val key = "$src>$tgt"
        clients[key]?.let { return it }
        return synchronized(clients) {
            clients[key] ?: run {
                val options = TranslatorOptions.Builder()
                    .setSourceLanguage(src)
                    .setTargetLanguage(tgt)
                    .build()
                Translation.getClient(options).also { clients[key] = it }
            }
        }
    }

    /** Downloads whatever this pair needs. Returns null on success, a message otherwise. */
    suspend fun prepare(
        source: String,
        target: String,
        requireWifi: Boolean = false
    ): String? = prepareLock.withLock {
        if (source == target) return null
        val key = "$source>$target"
        if (readyPairs.contains(key)) return null
        val client = clientFor(source, target) ?: return "That language pair is not supported"
        return try {
            val conditions = DownloadConditions.Builder().apply {
                if (requireWifi) requireWifi()
            }.build()
            client.downloadModelIfNeeded(conditions).await()
            readyPairs.add(key)
            null
        } catch (t: Throwable) {
            t.message ?: "Model download failed"
        }
    }

    /** True when both halves of the pair are already on the device. */
    suspend fun isReady(source: String, target: String): Boolean = withContext(Dispatchers.IO) {
        if (source == target) return@withContext true
        try {
            downloadedTags().containsAll(setOf(source, target) - setOf("en"))
        } catch (t: Throwable) {
            false
        }
    }

    suspend fun downloadedTags(): Set<String> = withContext(Dispatchers.IO) {
        try {
            RemoteModelManager.getInstance()
                .getDownloadedModels(TranslateRemoteModel::class.java)
                .await()
                .mapNotNull { it.language }
                .toSet()
        } catch (t: Throwable) {
            emptySet()
        }
    }

    suspend fun deleteModel(tag: String): Boolean = withContext(Dispatchers.IO) {
        try {
            val language = TranslateLanguage.fromLanguageTag(tag) ?: return@withContext false
            RemoteModelManager.getInstance()
                .deleteDownloadedModel(TranslateRemoteModel.Builder(language).build())
                .await()
            readyPairs.removeAll { it.contains(tag) }
            true
        } catch (t: Throwable) {
            false
        }
    }

    suspend fun translate(text: String, source: String, target: String): String {
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return ""
        if (source == target) return trimmed

        val key = "$source>$target|$trimmed"
        cache.get(key)?.let { return it }

        if (prepare(source, target) != null) return ""
        val client = clientFor(source, target) ?: return ""
        return try {
            client.translate(trimmed).await().also { cache.put(key, it) }
        } catch (t: Throwable) {
            ""
        }
    }

    /** Translates a batch, preserving order. */
    suspend fun translateAll(
        texts: List<String>,
        source: String,
        target: String
    ): List<String> = coroutineScope {
        if (texts.isEmpty()) return@coroutineScope emptyList()
        val results = arrayOfNulls<String>(texts.size)
        texts.chunked(BATCH).forEachIndexed { chunkIndex, chunk ->
            val jobs = chunk.mapIndexed { i, t ->
                async(Dispatchers.Default) { (chunkIndex * BATCH + i) to translate(t, source, target) }
            }
            jobs.awaitAll().forEach { (index, value) -> results[index] = value }
        }
        results.map { it ?: "" }
    }

    private const val BATCH = 8
}
