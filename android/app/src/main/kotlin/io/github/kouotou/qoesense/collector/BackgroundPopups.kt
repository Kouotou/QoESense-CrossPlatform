package io.github.kouotou.qoesense.collector

import android.app.AppOpsManager
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Process
import android.provider.Settings

/**
 * Xiaomi (MIUI / HyperOS) adds its own permission, "Display pop-up windows while running in
 * the background", which is off by default. Without it the rating pop-up is silently dropped
 * even when "display over other apps" is granted: a Xiaomi test phone collected for 12 hours
 * without a single prompt (2026-11-25).
 *
 * MIUI stores it as app-op 10021. Not public API, so it is read by reflection and reported as
 * "unknown" if that fails; the survey's notification fallback covers that case anyway.
 */
object BackgroundPopups {
    private const val OP_BACKGROUND_START_ACTIVITY = 10021

    fun status(context: Context): String {
        if (AutoStart.currentBrand() != AutoStart.Brand.XIAOMI) return "notApplicable"
        return try {
            val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val m = AppOpsManager::class.java.getMethod(
                "checkOpNoThrow", Int::class.javaPrimitiveType, Int::class.javaPrimitiveType, String::class.java,
            )
            val mode = m.invoke(appOps, OP_BACKGROUND_START_ACTIVITY, Process.myUid(), context.packageName) as Int
            if (mode == AppOpsManager.MODE_ALLOWED) "allowed" else "denied"
        } catch (e: Exception) {
            "unknown"
        }
    }

    /** MIUI's per-app permission editor ("Other permissions"), else the app's details page. */
    fun open(context: Context) {
        val candidates = listOf(
            Intent("miui.intent.action.APP_PERM_EDITOR").setComponent(
                ComponentName("com.miui.securitycenter", "com.miui.permcenter.permissions.PermissionsEditorActivity"),
            ),
            Intent("miui.intent.action.APP_PERM_EDITOR").setComponent(
                ComponentName("com.miui.securitycenter", "com.miui.permcenter.permissions.AppPermissionsEditorActivity"),
            ),
        )
        for (intent in candidates) {
            try {
                context.startActivity(
                    intent.putExtra("extra_pkgname", context.packageName).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                return
            } catch (e: ActivityNotFoundException) {
                // other MIUI version - try the next one
            } catch (e: SecurityException) {
                // not exported here - try the next one
            }
        }
        context.startActivity(
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
    }
}
