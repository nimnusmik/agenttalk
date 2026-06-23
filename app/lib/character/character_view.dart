import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'character_state.dart';
import 'sprite_manifest.dart';

/// 도트 캐릭터 1체를 그리는 위젯.
///
/// - manifest.frame_layout 의 rect 만 샘플링(그리드 추측 금지).
/// - emotion(논리) + moodScore → sprite state 해석(talking→talk, idle→mood baseline).
/// - transient(happy/sad/surprised, loop=false) 는 1회 재생 후 mood idle baseline 으로 복귀.
/// - 픽셀아트라 nearest-neighbor(FilterQuality.none) 강제.
/// - mood 에 따라 옅은 배경 tint(설계서의 "idle 3종 + 배경 tint" 채택안).
class CharacterView extends StatefulWidget {
  final ui.Image atlas;
  final SpriteManifest manifest;
  final Emotion emotion;
  final int moodScore; // -3..+3
  final bool showMoodTint;
  final VoidCallback? onTransientComplete;

  const CharacterView({
    super.key,
    required this.atlas,
    required this.manifest,
    this.emotion = Emotion.idle,
    this.moodScore = 0,
    this.showMoodTint = true,
    this.onTransientComplete,
  });

  @override
  State<CharacterView> createState() => _CharacterViewState();
}

class _CharacterViewState extends State<CharacterView>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  Duration _stateElapsed = Duration.zero;

  late List<SpriteRect> _frames;
  late int _fps;
  late bool _loop;
  int _frameIndex = 0;
  bool _firedComplete = false;

  Mood get _mood => moodFromScore(widget.moodScore);

  @override
  void initState() {
    super.initState();
    _applyState(spriteStateFor(widget.emotion, _mood), resetComplete: true);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void didUpdateWidget(CharacterView old) {
    super.didUpdateWidget(old);
    if (old.emotion != widget.emotion || old.moodScore != widget.moodScore) {
      _applyState(spriteStateFor(widget.emotion, _mood), resetComplete: true);
    }
  }

  /// manifest 에 없는 state 면 idle → 첫 state 순으로 폴백.
  String _safe(String name) {
    if (widget.manifest.hasState(name)) return name;
    if (widget.manifest.hasState('idle')) return 'idle';
    return widget.manifest.states.first;
  }

  void _applyState(String name, {bool resetComplete = false}) {
    final state = _safe(name);
    final frames = widget.manifest.framesFor(state) ?? const <SpriteRect>[];
    final anim = widget.manifest.animFor(state);
    setState(() {
      _frames = frames;
      _fps = anim?.fps ?? 8;
      _loop = anim?.loop ?? true;
      _frameIndex = 0;
      _stateElapsed = Duration.zero;
      if (resetComplete) _firedComplete = false;
    });
  }

  void _onTick(Duration now) {
    final dt = now - _last;
    _last = now;
    if (_frames.isEmpty || _fps <= 0) return;
    _stateElapsed += dt;
    final total = _frames.length;
    final raw = (_stateElapsed.inMicroseconds / 1000000.0 * _fps).floor();

    if (_loop) {
      final idx = raw % total;
      if (idx != _frameIndex) setState(() => _frameIndex = idx);
      return;
    }

    // non-loop(transient): 마지막 프레임에서 정지 → mood idle baseline 으로 복귀.
    final idx = raw >= total ? total - 1 : raw;
    if (idx != _frameIndex) setState(() => _frameIndex = idx);
    if (raw >= total && !_firedComplete) {
      _firedComplete = true;
      widget.onTransientComplete?.call();
      _applyState(idleStateForMood(_mood));
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rect = _frames.isEmpty
        ? null
        : _frames[_frameIndex.clamp(0, _frames.length - 1)];
    return CustomPaint(
      painter: _CharacterPainter(
        atlas: widget.atlas,
        rect: rect,
        moodTint: widget.showMoodTint ? _tintFor(_mood) : null,
      ),
      child: const SizedBox.expand(),
    );
  }

  Color? _tintFor(Mood mood) {
    switch (mood) {
      case Mood.down:
        return const Color(0x223A4A6B); // 차분한 블루그레이
      case Mood.up:
        return const Color(0x22FFD27F); // 따뜻한 톤
      case Mood.neutral:
        return null;
    }
  }
}

class _CharacterPainter extends CustomPainter {
  final ui.Image atlas;
  final SpriteRect? rect;
  final Color? moodTint;

  _CharacterPainter({required this.atlas, required this.rect, this.moodTint});

  @override
  void paint(Canvas canvas, Size size) {
    if (moodTint != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = moodTint!);
    }
    final r = rect;
    if (r == null) return;

    final src =
        Rect.fromLTWH(r.x.toDouble(), r.y.toDouble(), r.w.toDouble(), r.h.toDouble());

    // 셀을 위젯 안에 contain(비율 유지)으로 배치, 하단 정렬(바닥에 앉은 느낌).
    final sx = size.width / r.w;
    final sy = size.height / r.h;
    final s = sx < sy ? sx : sy;
    final dw = r.w * s;
    final dh = r.h * s;
    final dst = Rect.fromLTWH((size.width - dw) / 2, size.height - dh, dw, dh);

    final paint = Paint()
      ..isAntiAlias = false
      ..filterQuality = FilterQuality.none; // 픽셀아트 = nearest neighbor
    canvas.drawImageRect(atlas, src, dst, paint);
  }

  @override
  bool shouldRepaint(_CharacterPainter old) =>
      old.rect != rect || old.atlas != atlas || old.moodTint != moodTint;
}
