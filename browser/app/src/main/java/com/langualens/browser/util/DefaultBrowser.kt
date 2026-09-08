package com.langualens.browser.util

import android.app.Activity
import android.app.role.RoleManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings

/**
 * Becoming, and checking whether we are, the phone's default browser.
 *
 * Android 10 and newer expose this as a role the app can ask for with a system
 * dialog. Older versions have no such prompt, so the user is sent to the
 * settings screen where the choice lives.
 */
object DefaultBrowser {

    const val REQUEST_CODE = 4711

    fun isDefault(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roles = context.getSystemService(RoleManager::class.java)
            if (roles != null && roles.isRoleAvailable(RoleManager.ROLE_BROWSER)) {
                return roles.isRoleHeld(RoleManager.ROLE_BROWSER)
            }
        }
        val probe = Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com"))
            .addCategory(Intent.CATEGORY_BROWSABLE)
        val handler = context.packageManager
            .resolveActivity(probe, PackageManager.MATCH_DEFAULT_ONLY)
            ?.activityInfo?.packageName
        return handler == context.packageName
    }

    /** Shows the system prompt, or the settings screen where none exists. */
    fun request(activity: Activity) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val roles = activity.getSystemService(RoleManager::class.java)
            if (roles != null && roles.isRoleAvailable(RoleManager.ROLE_BROWSER)) {
                activity.startActivityForResult(
                    roles.createRequestRoleIntent(RoleManager.ROLE_BROWSER),
                    REQUEST_CODE
                )
                return
            }
        }
        openSettings(activity)
    }

    fun openSettings(context: Context) {
        val screens = listOf(
            Intent(Settings.ACTION_MANAGE_DEFAULT_APPS_SETTINGS),
            Intent(Settings.ACTION_APPLICATION_SETTINGS)
        )
        for (intent in screens) {
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (intent.resolveActivity(context.packageManager) != null) {
                context.startActivity(intent)
                return
            }
        }
    }
}
