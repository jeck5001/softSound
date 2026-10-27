import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'effects_settings.dart';

/// 点击粒子特效层 —— 对应聆阅 `tingshu_tap_fx`。
///
/// 用法：把整棵页面树包在 [TapFxLayer] 里（`MaterialApp.builder`），
/// 它在**不拦截**正常点击的前提下旁路监听 `onTapDown`，在落点炸开一小簇粒子。
///
/// 设计要点：
/// - 只用 `Listener`（不参与手势竞技场），因此不会抢走按钮点击；
/// - 粒子数量/寿命固定（12 颗 / 520ms），动画结束即移除，不留垃圾；
/// - 动效总开关关闭或特效本身关闭时**零开销**（直接返回 child）。
class TapFxLayer extends ConsumerStatefulWidget {
  const TapFxLayer({super.key, required this.child});

  final Widget child;

  /// 粒子数量与寿命（对齐「轻微」的手感，不喧宾夺主）。
  static const int particleCount = 12;

  /// 一簇粒子的动画时长。
  static const Duration burstDuration = Duration(milliseconds: 520);

  @override
  ConsumerState<TapFxLayer> createState() => _TapFxLayerState();
}

class _TapFxLayerState extends ConsumerState<TapFxLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Offset? _origin;
  int _burstSeed = 0;

  /// 按下时的位置与时间；抬手时据此判断「是否算一次点击」。
  Offset? _downPosition;
  DateTime? _downAt;

  /// 点击判定阈值：位移 < 12dp 且按住 < 260ms。
  ///
  /// 这样滑动列表、拖进度条都不会炸粒子 —— 只为「点」这一下做特效。
  static const double _tapSlop = 12;
  static const Duration _tapMaxHold = Duration(milliseconds: 260);


  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: TapFxLayer.burstDuration)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _origin = null);
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _burst(Offset position) {
    setState(() {
      _origin = position;
      // 每次点击换一个种子，粒子角度分布不重复
      _burstSeed = (_burstSeed + 7) % 360;
    });
    _controller
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(
      effectsSettingsProvider.select((s) => s.tapFxActive),
    );
    if (!active) return widget.child;

    return Listener(
      key: const ValueKey('tap-fx-listener'),
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        _downPosition = event.position;
        _downAt = DateTime.now();
      },
      onPointerUp: (event) {
        final down = _downPosition;
        final at = _downAt;
        _downPosition = null;
        _downAt = null;
        if (down == null || at == null) return;
        if ((event.position - down).distance > _tapSlop) return;
        if (DateTime.now().difference(at) > _tapMaxHold) return;
        _burst(event.position);
      },
      onPointerCancel: (_) {
        _downPosition = null;
        _downAt = null;
      },
      child: Stack(
        children: [
          widget.child,
          if (_origin != null)
            Positioned.fill(
              child: IgnorePointer(
                key: const ValueKey('tap-fx-particles'),
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) => CustomPaint(
                    painter: _TapFxPainter(
                      origin: _origin!,
                      progress: _controller.value,
                      seed: _burstSeed,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 单簇粒子的绘制：从落点向外扩散 + 上抛 + 淡出。
class _TapFxPainter extends CustomPainter {
  _TapFxPainter({
    required this.origin,
    required this.progress,
    required this.seed,
    required this.color,
  });

  final Offset origin;
  final double progress;
  final int seed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final t = Curves.easeOut.transform(progress);
    final opacity = (1 - progress).clamp(0.0, 1.0);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color.withValues(alpha: opacity * 0.85);

    for (var i = 0; i < TapFxLayer.particleCount; i++) {
      final angle = (seed + i * (360 / TapFxLayer.particleCount)) *
          math.pi /
          180;
      // 半径随进度增大；每颗再加一点随机抖动（固定种子 → 可重现）
      final jitter = 0.75 + ((i * 37) % 50) / 100;
      final distance = 26 * t * jitter;
      final dx = math.cos(angle) * distance;
      final dy = math.sin(angle) * distance - 10 * t; // 轻微上抛
      final r = (3.2 * (1 - t)).clamp(0.4, 3.2);
      canvas.drawCircle(origin.translate(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_TapFxPainter old) =>
      old.progress != progress ||
      old.origin != origin ||
      old.seed != seed ||
      old.color != color;
}
