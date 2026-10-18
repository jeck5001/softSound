package com.softSound.soft_sound

import android.media.audiofx.LoudnessEnhancer
import android.os.Build
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * 承载「音量增强」的原生实现。
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
class MainActivity : FlutterActivity() {

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

        /** 全局输出会话。 */
        private const val AUDIO_SESSION_GLOBAL = 0

        /** 默认增益 600 mB（约 +6 dB）。 */
        private const val DEFAULT_GAIN_MB = 600

        /** 上限 1500 mB，避免过度放大导致失真。 */
        private const val MAX_GAIN_MB = 1500
    }
}
