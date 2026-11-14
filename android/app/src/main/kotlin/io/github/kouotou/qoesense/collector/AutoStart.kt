package io.github.kouotou.qoesense.collector

import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings

/**
 * Brand-specific "auto-start" screens (report alignment, 2026-11-14). Several manufacturers
 * block apps from restarting on their own (after a reboot, an app update, or when the
 * system kills them) unless the user allows it in a vendor screen. On the Infinix test phone
 * this "AutoStart Limit" blocked the boot/update restarts.
 *
 * The vendor activities aren't public API: they move between OS versions, so each family
 * lists several candidates, tried in order, then the app's details page as the fallback.
 */
object AutoStart {
    enum class Brand(val wire: String) { TRANSSION("transsion"), XIAOMI("xiaomi"), OPPO("oppo"), VIVO("vivo"), HUAWEI("huawei"), SAMSUNG("samsung"), OTHER("other") }

    /** Pure, so it's unit-tested: Build.MANUFACTURER / Build.BRAND to a family. */
    fun brandOf(manufacturer: String?, brand: String?): Brand {
        val names = listOfNotNull(manufacturer, brand).map { it.lowercase() }
        fun any(vararg keys: String) = names.any { n -> keys.any { n.contains(it) } }
        return when {
            any("infinix", "tecno", "itel", "transsion") -> Brand.TRANSSION
            any("xiaomi", "redmi", "poco") -> Brand.XIAOMI
            any("oppo", "realme", "oneplus") -> Brand.OPPO
            any("vivo", "iqoo") -> Brand.VIVO
            any("huawei", "honor") -> Brand.HUAWEI
            any("samsung") -> Brand.SAMSUNG
            else -> Brand.OTHER
        }
    }

    fun currentBrand(): Brand = brandOf(Build.MANUFACTURER, Build.BRAND)

    /** Candidate vendor screens (package to activity), most likely first. */
    fun candidates(brand: Brand): List<Pair<String, String>> = when (brand) {
        Brand.TRANSSION -> listOf(
            "com.transsion.phonemaster" to "com.cyin.himgr.autostart.AutoStartActivity",
            "com.transsion.phonemaster" to "com.cyin.himgr.applicationmanager.view.activities.AppManagerActivity",
        )
        Brand.XIAOMI -> listOf(
            "com.miui.securitycenter" to "com.miui.permcenter.autostart.AutoStartManagementActivity",
        )
        Brand.OPPO -> listOf(
            "com.coloros.safecenter" to "com.coloros.safecenter.permission.startup.StartupAppListActivity",
            "com.coloros.safecenter" to "com.coloros.safecenter.startupapp.StartupAppListActivity",
            "com.oppo.safe" to "com.oppo.safe.permission.startup.StartupAppListActivity",
        )
        Brand.VIVO -> listOf(
            "com.vivo.permissionmanager" to "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
            "com.iqoo.secure" to "com.iqoo.secure.ui.phoneoptimize.BgStartUpManager",
        )
        Brand.HUAWEI -> listOf(
            "com.huawei.systemmanager" to "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
            "com.huawei.systemmanager" to "com.huawei.systemmanager.optimize.process.ProtectActivity",
        )
        Brand.SAMSUNG -> listOf(
            "com.samsung.android.lool" to "com.samsung.android.sm.battery.ui.BatteryActivity",
            "com.samsung.android.sm" to "com.samsung.android.sm.battery.ui.BatteryActivity",
        )
        Brand.OTHER -> emptyList()
    }

    /**
     * Opens the first vendor screen that starts. startActivity is tried directly (no
     * resolveActivity): on Android 11+ other apps' components are invisible to queries
     * without a <queries> entry, but starting an exported one still works.
     */
    fun open(context: Context) {
        for ((pkg, cls) in candidates(currentBrand())) {
            val intent = Intent().setComponent(ComponentName(pkg, cls)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            try {
                context.startActivity(intent)
                return
            } catch (e: ActivityNotFoundException) {
                // not on this OS version - try the next one
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
