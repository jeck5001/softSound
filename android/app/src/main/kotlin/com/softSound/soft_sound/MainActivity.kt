package com.softSound.soft_sound

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.audiofx.LoudnessEnhancer
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import android.util.Log
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 承载「音量增强」与「系统设置跳转」的原生实现。
 *
 * 继承 `AudioServiceActivity`（而非 `FlutterActivity`）是 audio_service /
 * just_audio_background 的硬性要求：它把 Activity 的 FlutterEngine 交给
 * 媒体服务复用，否则初始化时会报
 * "The Activity class declared in your AndroidManifest.xml is wrong or has not
 * provided the correct FlutterEngine"，通知栏媒体卡片也就不会出现。
 *
 * 对应聆阅的 `🔊 播放与音频 → 音量增强`：
 * 采用 Android 原生 [LoudnessEnhancer]（无需 ROOT），
 * 以毫贝（mB）为单位提升响度，弥补手机/蓝牙耳机音量不足。
 *
 * 说明：Dart 侧 `just_audio` 的 `setVolume()` 上限为 1.0，
 * 无法真正放大；因此增益必须走原生音效链。
 *
 * 需要 `android.permission.MODIFY_AUDIO_SETTINGS`（已在清单中声明）。
 */
class MainActivity : AudioServiceActivity() {

    private var loudnessEnhancer: LoudnessEnhancer? = null

    /** 当前增益（毫贝）。0 表示未启用。 */
    private var currentGainMb = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> {
                    val gain = call.argument<Int>("gainMb") ?: DEFAULT_GAIN_MB
                    result.success(enable(gain))
                }
                "setGain" -> {
                    val gain = call.argument<Int>("gainMb") ?: DEFAULT_GAIN_MB
                    result.success(setGain(gain))
                }
                "disable" -> {
                    disable()
                    result.success(true)
                }
                "isSupported" -> result.success(isSupported())
                "getGain" -> result.success(currentGainMb)
                else -> result.notImplemented()
            }
        }

        // 系统设置跳转（后台保活引导）：聆阅只给文案，这里把用户送到目标页。
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            SYSTEM_CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAppSettings" -> result.success(openAppSettings())
                "openBatteryOptimizationSettings" ->
                    result.success(openBatteryOptimizationSettings())
                "isIgnoringBatteryOptimizations" ->
                    result.success(isIgnoringBatteryOptimizations())
                "hasNotificationPermission" ->
                    result.success(hasNotificationPermission())
                "requestNotificationPermission" ->
                    result.success(requestNotificationPermission())
                else -> result.notImplemented()
            }
        }
    }

    /** 打开本应用的系统详情页。 */
    private fun openAppSettings(): Boolean = try {
        startActivity(
            Intent(
                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                Uri.parse("package:$packageName")
            ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
        true
    } catch (e: Exception) {
        Log.w(TAG, "打开应用设置失败: ${e.message}")
        false
    }

    /** 打开系统「电池优化」列表页（用户在此把本应用设为「不优化」）。 */
    private fun openBatteryOptimizationSettings(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return false
        return try {
            startActivity(
                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
            true
        } catch (e: Exception) {
            Log.w(TAG, "打开电池优化设置失败: ${e.message}")
            // 退化为应用详情页
            openAppSettings()
        }
    }

    /** 是否已获得通知权限（Android 13+ 需要运行时申请）。 */
    private fun hasNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    /**
     * 申请通知权限。
     *
     * 没有通知权限时，媒体通知不会出现，小米 HyperOS 的灵动岛/焦点通知
     * 也就无从显示 —— 所以第一次播放前要主动申请。
     *
     * @return 当前是否已授权（false 表示已弹出系统对话框，等用户选择）。
     */
    private fun requestNotificationPermission(): Boolean {
        if (hasNotificationPermission()) return true
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_REQUEST_CODE
        )
        return false
    }

    /** 是否已在电池优化白名单（API 23+）。 */
    private fun isIgnoringBatteryOptimizations(): Boolean? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) return null
        return try {
            val pm = getSystemService(POWER_SERVICE) as PowerManager
            pm.isIgnoringBatteryOptimizations(packageName)
        } catch (e: Exception) {
            Log.w(TAG, "查询电池优化白名单失败: ${e.message}")
            null
        }
    }

    /** 系统是否支持响度增强（API 19+）。 */
    private fun isSupported(): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT

    /**
     * 启用增强并设置增益。
     *
     * @param gainMb 增益毫贝；常用区间 0–1500（约 +0–15 dB）。
     * @return 是否成功。
     */
    private fun enable(gainMb: Int): Boolean {
        if (!isSupported()) {
            Log.w(TAG, "LoudnessEnhancer 不受支持（API < 19）")
            return false
        }
        return try {
            if (loudnessEnhancer == null) {
                loudnessEnhancer = LoudnessEnhancer(AUDIO_SESSION_GLOBAL).apply {
                    enabled = true
                }
            }
            applyGain(gainMb)
            true
        } catch (e: Exception) {
            Log.w(TAG, "启用音量增强失败: ${e.message}")
            loudnessEnhancer?.release()
            loudnessEnhancer = null
            false
        }
    }

    /** 调整增益；未启用时先启用。 */
    private fun setGain(gainMb: Int): Boolean {
        if (loudnessEnhancer == null) return enable(gainMb)
        return try {
            applyGain(gainMb)
            true
        } catch (e: Exception) {
            Log.w(TAG, "设置增益失败: ${e.message}")
            false
        }
    }

    private fun applyGain(gainMb: Int) {
        // 钳制到安全范围，避免削波失真
        val clamped = gainMb.coerceIn(0, MAX_GAIN_MB)
        loudnessEnhancer?.setTargetGain(clamped)
        currentGainMb = clamped
        Log.d(TAG, "音量增强增益 = ${clamped}mB")
    }

    /** 关闭并释放音效资源（聆阅：退出播放或销毁页面时释放）。 */
    private fun disable() {
        try {
            loudnessEnhancer?.enabled = false
            loudnessEnhancer?.release()
        } catch (e: Exception) {
            Log.w(TAG, "释放音量增强失败: ${e.message}")
        } finally {
            loudnessEnhancer = null
            currentGainMb = 0
        }
    }

    override fun onDestroy() {
        disable()
        super.onDestroy()
    }

    companion object {
        private const val TAG = "LoudnessEnhancer"
        private const val CHANNEL = "soft_sound/audio_effects"
        private const val SYSTEM_CHANNEL = "soft_sound/system_settings"

        /** 通知权限请求码（与 onRequestPermissionsResult 对应）。 */
        private const val NOTIFICATION_REQUEST_CODE = 1001

        /** 全局输出会话。 */
        private const val AUDIO_SESSION_GLOBAL = 0

        /** 默认增益 600 mB（约 +6 dB）。 */
        private const val DEFAULT_GAIN_MB = 600

        /** 上限 1500 mB，避免过度放大导致失真。 */
        private const val MAX_GAIN_MB = 1500
    }
}
