package com.langualens.browser.data

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Words and phrases you starred while reading.
 *
 * A JSON file rather than a database: the list is small, it is only ever read
 * whole, and a file keeps the app free of a persistence library.
 */
class Vocab(context: Context) {

    data class Item(
        val text: String,
        val translation: String,
        val context: String,
        val origin: String,
        val source: String,
        val target: String,
        val savedAt: Long
    )

    private val file = File(context.applicationContext.filesDir, "vocab.json")

    suspend fun all(): List<Item> = withContext(Dispatchers.IO) { read() }

    /** Returns false when the same text is already saved. */
    suspend fun add(item: Item): Boolean = withContext(Dispatchers.IO) {
        val items = read()
        if (items.any { it.text.equals(item.text, ignoreCase = true) }) return@withContext false
        write(listOf(item) + items)
        true
    }

    suspend fun remove(text: String) = withContext(Dispatchers.IO) {
        write(read().filterNot { it.text == text })
    }

    suspend fun clear() = withContext(Dispatchers.IO) { write(emptyList()) }

    /** Tab separated, the shape Anki's importer expects. */
    suspend fun toTsv(): String = withContext(Dispatchers.IO) {
        read().joinToString("\n") { item ->
            listOf(item.text, item.translation, item.context, item.origin)
                .joinToString("\t") { it.replace('\t', ' ').replace('\n', ' ') }
        }
    }

    private fun read(): List<Item> {
        if (!file.exists()) return emptyList()
        return try {
            val arr = JSONArray(file.readText())
            (0 until arr.length()).mapNotNull { i ->
                val o = arr.optJSONObject(i) ?: return@mapNotNull null
                Item(
                    text = o.optString("text"),
                    translation = o.optString("translation"),
                    context = o.optString("context"),
                    origin = o.optString("origin"),
                    source = o.optString("source"),
                    target = o.optString("target"),
                    savedAt = o.optLong("savedAt")
                )
            }.filter { it.text.isNotBlank() }
        } catch (t: Throwable) {
            emptyList()
        }
    }

    private fun write(items: List<Item>) {
        val arr = JSONArray()
        items.forEach { item ->
            arr.put(
                JSONObject()
                    .put("text", item.text)
                    .put("translation", item.translation)
                    .put("context", item.context)
                    .put("origin", item.origin)
                    .put("source", item.source)
                    .put("target", item.target)
                    .put("savedAt", item.savedAt)
            )
        }
        try {
            file.writeText(arr.toString())
        } catch (t: Throwable) {
            // a full disk is not worth crashing a browser over
        }
    }
}
