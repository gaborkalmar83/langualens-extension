package com.langualens.browser.util

import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri

/**
 * Sending the current page to a real browser.
 *
 * This exists because a small WebView shell is the wrong place to type a
 * password: it has no password manager, no passkeys and no sync. So anything
 * that needs an account gets handed over to Chrome, on the same URL, and this
 * app stays out of it.
 *
 * A plain ACTION_VIEW would come straight back here whenever this app is the
 * default browser, so the target is always named explicitly: Chrome by package
 * if it is installed, otherwise a chooser built from the other browsers on the
 * device with this app filtered out.
 */
object Handoff {

    private val CHROME_PACKAGES = listOf(
        "com.android.chrome",
        "com.chrome.beta",
        "com.chrome.dev",
        "com.chrome.canary"
    )

    fun chromePackage(context: Context): String? =
        CHROME_PACKAGES.firstOrNull { installed(context, it) }

    /** Returns false when there is nowhere to hand the page to. */
    fun open(context: Context, url: String): Boolean {
        if (!Urls.isHttp(url)) return false
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

        chromePackage(context)?.let { pkg ->
            return try {
                context.startActivity(Intent(intent).setPackage(pkg))
                true
            } catch (t: ActivityNotFoundException) {
                openInAnyOtherBrowser(context, intent)
            }
        }
        return openInAnyOtherBrowser(context, intent)
    }

    private fun openInAnyOtherBrowser(context: Context, template: Intent): Boolean {
        val others = browsersOtherThanUs(context, template)
        if (others.isEmpty()) return false
        if (others.size == 1) {
            context.startActivity(Intent(template).setPackage(others.first()))
            return true
        }
        val first = Intent(template).setPackage(others.first())
        val chooser = Intent.createChooser(first, null).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        chooser.putExtra(
            Intent.EXTRA_INITIAL_INTENTS,
            others.drop(1).map { Intent(template).setPackage(it) }.toTypedArray()
        )
        context.startActivity(chooser)
        return true
    }

    private fun browsersOtherThanUs(context: Context, template: Intent): List<String> =
        context.packageManager
            .queryIntentActivities(template, PackageManager.MATCH_DEFAULT_ONLY)
            .map { it.activityInfo.packageName }
            .distinct()
            .filterNot { it == context.packageName }

    private fun installed(context: Context, pkg: String): Boolean = try {
        context.packageManager.getPackageInfo(pkg, 0)
        true
    } catch (t: PackageManager.NameNotFoundException) {
        false
    }
}
