package com.langualens.browser.ui

import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.FileProvider
import androidx.lifecycle.lifecycleScope
import com.langualens.browser.R
import com.langualens.browser.data.Vocab
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

/**
 * The words you starred, and the way out to Anki.
 *
 * Export is a tab separated file rather than an Anki package, because that is
 * what Anki's own importer takes and it stays readable in anything else.
 */
class SavedActivity : AppCompatActivity() {

    private lateinit var vocab: Vocab
    private lateinit var container: LinearLayout
    private lateinit var empty: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_saved)
        vocab = Vocab(this)

        container = findViewById(R.id.savedList)
        empty = findViewById(R.id.savedEmpty)

        findViewById<View>(R.id.savedBack).setOnClickListener { finish() }
        findViewById<View>(R.id.savedExport).setOnClickListener { export() }
        findViewById<View>(R.id.savedClear).setOnClickListener { confirmClear() }

        load()
    }

    private fun load() {
        lifecycleScope.launch {
            val items = vocab.all()
            container.removeAllViews()
            empty.visibility = if (items.isEmpty()) View.VISIBLE else View.GONE
            items.forEach { item ->
                val row = layoutInflater.inflate(R.layout.item_saved, container, false)
                row.findViewById<TextView>(R.id.savedText).text = item.text
                row.findViewById<TextView>(R.id.savedTranslation).text =
                    item.translation.ifBlank { getString(R.string.no_translation) }
                val context = row.findViewById<TextView>(R.id.savedContext)
                context.text = item.context
                context.visibility = if (item.context.isBlank()) View.GONE else View.VISIBLE
                row.findViewById<View>(R.id.savedRemove).setOnClickListener {
                    lifecycleScope.launch {
                        vocab.remove(item.text)
                        load()
                    }
                }
                container.addView(row)
            }
        }
    }

    private fun export() {
        lifecycleScope.launch {
            val tsv = vocab.toTsv()
            if (tsv.isBlank()) {
                toast(getString(R.string.nothing_to_export))
                return@launch
            }
            val uri = withContext(Dispatchers.IO) {
                val dir = File(cacheDir, "exports").apply { mkdirs() }
                val file = File(dir, "langualens-vocabulary.tsv")
                file.writeText(tsv)
                FileProvider.getUriForFile(
                    this@SavedActivity,
                    "com.langualens.browser.fileprovider",
                    file
                )
            }
            startActivity(
                Intent.createChooser(
                    Intent(Intent.ACTION_SEND)
                        .setType("text/tab-separated-values")
                        .putExtra(Intent.EXTRA_STREAM, uri)
                        .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION),
                    getString(R.string.export)
                )
            )
        }
    }

    private fun confirmClear() {
        AlertDialog.Builder(this)
            .setTitle(R.string.clear_all)
            .setMessage(R.string.clear_all_body)
            .setPositiveButton(R.string.delete) { _, _ ->
                lifecycleScope.launch {
                    vocab.clear()
                    load()
                }
            }
            .setNegativeButton(android.R.string.cancel, null)
            .show()
    }

    private fun toast(message: String) = Toast.makeText(this, message, Toast.LENGTH_SHORT).show()
}
