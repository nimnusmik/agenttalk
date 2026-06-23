import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../character/character_state.dart';
import 'chat_controller.dart';

/// 노아의 방 (Direction 01) — 채팅 화면 상단 무대.
///
/// 노아 누끼(noa_cut.png)가 방을 **뽈뽈뽈 걸어다니고**(작은 홉 + 착지 스쿼시 +
/// 진행 방향으로 기울임 + 점프에 연동되는 그림자), 말을 걸거나 방을 톡 누르면
/// 가운데로 와 **정면을 응시**한다. 탭하면 하트가 톡 튀어오른다.
/// 시간대(낮/노을/밤)에 따라 창밖 하늘과 방 분위기가, mood 에 따라 status·tint 가 바뀐다.
///
/// 높이는 부모(AnimatedContainer)가 주는 제약(maxHeight)을 그대로 사용 →
/// 대화 시작 시 슬림 헤더로 줄어드는 collapsing 무대를 부드럽게 따라간다.
class NoaRoom extends StatefulWidget {
  final ChatController controller;
  const NoaRoom({super.key, required this.controller});

  @override
  State<NoaRoom> createState() => _NoaRoomState();
}

enum _Tod { day, sunset, night }

class _NoaRoomState extends State<NoaRoom> with TickerProviderStateMixin {
  final _rng = Random();

  late final AnimationController _breathe; // 가만히 있을 때 숨쉬는 미세 스케일
  late final AnimationController _hop; // 이동/반응 시 통통 점프(여러 홉)

  double _stageW = 360;
  double _stageH = 360;
  double _x = 180;
  int _moveMs = 800;
  int _hopSteps = 2; // 이번 이동에서 밟을 작은 홉 수(거리 비례)
  bool _facingRight = true;
  bool _looking = false;
  String? _indicator;

  Timer? _wanderTimer;
  Timer? _lookTimer;
  Timer? _indTimer;

  int _lastMsgCount = 0;
  int _lastTick = 0;

  final List<int> _hearts = [];
  int _heartSeq = 0;

  static const double _noaW = 104;

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _hop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _lastMsgCount = widget.controller.messages.length;
    _lastTick = widget.controller.attentionTick;
    widget.controller.addListener(_onChange);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _x = _stageW / 2);
      _scheduleWander(const Duration(milliseconds: 900));
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _wanderTimer?.cancel();
    _lookTimer?.cancel();
    _indTimer?.cancel();
    _breathe.dispose();
    _hop.dispose();
    super.dispose();
  }

  // --- 컨트롤러 상태 → 노아 행동 ---
  void _onChange() {
    final c = widget.controller;
    if (c.attentionTick != _lastTick) {
      _lastTick = c.attentionTick;
      _lookAtUser();
    }
    if (c.messages.length > _lastMsgCount) {
      final last = c.messages.last;
      _lastMsgCount = c.messages.length;
      if (last.isMe) {
        _lookAtUser();
      } else {
        _react(last.emotion);
      }
    } else if (c.typing && !_looking) {
      _lookAtUser();
    }
  }

  // --- 이동 ---
  void _moveTo(double targetX, {int? ms, bool faceFront = false}) {
    final clamped =
        targetX.clamp(_noaW / 2, max(_noaW / 2, _stageW - _noaW / 2)).toDouble();
    final dist = (clamped - _x).abs();
    final dur = ms ?? (250 + dist / 170 * 700).clamp(380, 1500).round();
    setState(() {
      if (!faceFront && dist > 1) _facingRight = clamped >= _x;
      _x = clamped;
      _moveMs = dur;
      _hopSteps = max(1, (dist / 46).round());
    });
    _hop
      ..duration = Duration(milliseconds: dur)
      ..forward(from: 0);
  }

  void _scheduleWander(Duration delay) {
    _wanderTimer?.cancel();
    _wanderTimer = Timer(delay, _wander);
  }

  void _wander() {
    if (!mounted || _looking) return;
    const margin = _noaW / 2 + 8;
    final span = _stageW - margin * 2;
    final tx = span <= 0 ? _stageW / 2 : margin + _rng.nextDouble() * span;
    _moveTo(tx);
    _scheduleWander(Duration(milliseconds: 1300 + _rng.nextInt(1900)));
  }

  void _lookAtUser() {
    setState(() {
      _looking = true;
      _indicator = '!';
    });
    _wanderTimer?.cancel();
    _moveTo(_stageW / 2, ms: 480, faceFront: true);
    _indTimer?.cancel();
    _indTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _indicator = null);
    });
    _armReturnToWander();
  }

  void _react(Emotion e) {
    final ind = _indicatorFor(e);
    if (ind != null) {
      setState(() => _indicator = ind);
      _indTimer?.cancel();
      _indTimer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _indicator = null);
      });
    }
    setState(() => _hopSteps = 2); // 제자리 반응 홉
    _hop
      ..duration = const Duration(milliseconds: 560)
      ..forward(from: 0);
    _armReturnToWander();
  }

  void _armReturnToWander() {
    // 친해질수록 사용자를 더 오래 쳐다보고 곁에 머문다 (가시적 관계 변화).
    final lookMs = switch (bondFromAffinity(widget.controller.affinity)) {
      Bond.distant => 4500,
      Bond.warming => 6500,
      Bond.close => 9000,
    };
    _lookTimer?.cancel();
    _lookTimer = Timer(Duration(milliseconds: lookMs), () {
      if (!mounted) return;
      setState(() => _looking = false);
      _scheduleWander(const Duration(milliseconds: 400));
    });
  }

  void _spawnHeart() {
    final id = _heartSeq++;
    setState(() => _hearts.add(id));
  }

  String? _indicatorFor(Emotion e) {
    switch (e) {
      case Emotion.happy:
        return '♪';
      case Emotion.surprised:
        return '!';
      case Emotion.sad:
        return '…';
      case Emotion.thinking:
        return '…';
      default:
        return null;
    }
  }

  _Tod _tod() {
    final h = DateTime.now().hour;
    if (h >= 6 && h < 17) return _Tod.day;
    if (h >= 17 && h < 19) return _Tod.sunset;
    return _Tod.night;
  }

  String _statusText(Mood mood, _Tod tod) {
    final time = switch (tod) {
      _Tod.day => '☀️ 낮',
      _Tod.sunset => '🌇 노을',
      _Tod.night => '🌙 밤',
    };
    final m = switch (mood) {
      Mood.down => '기분 가라앉음',
      Mood.up => '기분 좋음',
      Mood.neutral => '기분 평온',
    };
    return '$m · $time';
  }

  Color? _moodTint(Mood mood) {
    switch (mood) {
      case Mood.down:
        return const Color(0x163A4A6B);
      case Mood.up:
        return const Color(0x1AFFD27F);
      case Mood.neutral:
        return null;
    }
  }

  Color? _ambient(_Tod tod) {
    switch (tod) {
      case _Tod.night:
        return const Color(0x242A2F55);
      case _Tod.sunset:
        return const Color(0x14FF8A5C);
      case _Tod.day:
        return null;
    }
  }

  /// 현재 _hop 진행에서의 홉 높이(0=바닥, 1=정점).
  double get _bounce {
    final hv = _hop.value;
    if (hv <= 0 || hv >= 1) return 0;
    return (sin(hv * _hopSteps * pi)).abs();
  }

  @override
  Widget build(BuildContext context) {
    final mood = moodFromScore(widget.controller.moodScore);
    final tod = _tod();
    final tint = _moodTint(mood);
    final ambient = _ambient(tod);

    return LayoutBuilder(
      builder: (context, constraints) {
        _stageW = constraints.maxWidth;
        _stageH = constraints.maxHeight;
        final floorH = _stageH * 0.34;
        final noaBottom = floorH * 0.40;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            _lookAtUser();
            _spawnHeart();
          },
          child: ClipRect(
            child: SizedBox.expand(
              child: Stack(
                children: [
                  // 벽
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFFFE3D4),
                            Color(0xFFFFEEE6),
                            Color(0xFFFFF5EF),
                          ],
                          stops: [0.0, 0.5, 0.7],
                        ),
                      ),
                    ),
                  ),
                  // 창문 (시간대별 하늘)
                  Positioned(left: 24, top: 22, child: _Window(tod: tod)),
                  // 벽 액자
                  const Positioned(right: 26, top: 30, child: _WallFrame()),
                  // 바닥 + 걸레받이
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: floorH,
                    child: const _Floor(),
                  ),
                  // 스탠드 조명 (뒤쪽 좌측)
                  Positioned(
                    left: 16,
                    bottom: floorH * 0.5,
                    child: _Lamp(lit: tod == _Tod.night),
                  ),
                  // 화분 (우측 바닥)
                  Positioned(
                    right: 22,
                    bottom: floorH * 0.48,
                    child: const _Plant(),
                  ),
                  // 책 더미 (좌측 바닥)
                  Positioned(
                    left: 64,
                    bottom: floorH * 0.30,
                    child: const _Books(),
                  ),
                  // 러그
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: (noaBottom - 16).clamp(0.0, _stageH),
                    child: const Center(child: _Rug()),
                  ),
                  // 그림자 (x 따라가고, 점프 시 작아지고 옅어짐)
                  AnimatedPositioned(
                    duration: Duration(milliseconds: _moveMs),
                    curve: Curves.easeInOut,
                    left: _x - 42,
                    bottom: (noaBottom - 2).clamp(0.0, _stageH),
                    width: 84,
                    height: 16,
                    child: AnimatedBuilder(
                      animation: _hop,
                      builder: (_, child) {
                        final bnc = _bounce;
                        final look = _looking ? 1.1 : 1.0;
                        return Transform.scale(
                          scale: (1 - 0.45 * bnc) * look,
                          child: Opacity(opacity: 1 - 0.5 * bnc, child: child),
                        );
                      },
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius:
                              BorderRadius.all(Radius.elliptical(42, 8)),
                          gradient: RadialGradient(
                            colors: [Color(0x47963C3C), Color(0x00963C3C)],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 노아
                  AnimatedPositioned(
                    duration: Duration(milliseconds: _moveMs),
                    curve: Curves.easeInOut,
                    left: _x - _noaW / 2,
                    bottom: noaBottom,
                    width: _noaW,
                    child: _buildNoa(),
                  ),
                  // 하트 파티클
                  ..._hearts.map(
                    (id) => Positioned(
                      left: _x - 12,
                      bottom: noaBottom + _noaW * 1.0,
                      child: _Heart(
                        key: ValueKey(id),
                        onDone: () => setState(() => _hearts.remove(id)),
                      ),
                    ),
                  ),
                  // 분위기 오버레이(시간대 + mood) — 탭 통과
                  if (ambient != null)
                    Positioned.fill(
                      child: IgnorePointer(child: ColoredBox(color: ambient)),
                    ),
                  if (tint != null)
                    Positioned.fill(
                      child: IgnorePointer(child: ColoredBox(color: tint)),
                    ),
                  // status pill (관계 + 기분 + 시간대)
                  Positioned(
                    left: 16,
                    top: 116,
                    child: _statusPill(
                      mood,
                      tod,
                      bondFromAffinity(widget.controller.affinity),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoa() {
    return AnimatedScale(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      alignment: Alignment.bottomCenter,
      scale: _looking ? 1.14 : 1.0,
      child: AnimatedBuilder(
        animation: Listenable.merge([_breathe, _hop]),
        builder: (context, child) {
          final b = _breathe.value;
          final breatheSx = 1 + 0.022 * b;
          final breatheSy = 1 - 0.018 * b;

          final bnc = _bounce; // 0..1
          final dy = -10 * bnc;
          final sq = 1 - bnc; // 바닥 접촉(스쿼시) 정도
          final lean = (_facingRight ? 1 : -1) * 0.055 * bnc;

          final sx = breatheSx * (1 + 0.05 * sq * (bnc > 0 ? 1 : 0));
          final sy = breatheSy * (1 - 0.05 * sq * (bnc > 0 ? 1 : 0));

          return Transform.translate(
            offset: Offset(0, dy),
            child: Transform.rotate(
              angle: lean,
              alignment: Alignment.bottomCenter,
              child: Transform.scale(
                scaleX: sx,
                scaleY: sy,
                alignment: Alignment.bottomCenter,
                child: child,
              ),
            ),
          );
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _indicatorBubble(),
            Image.asset(
              'assets/character/noa_cut.png',
              width: _noaW,
              filterQuality: FilterQuality.medium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _indicatorBubble() {
    final ind = _indicator;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: ind == null ? 0 : 1,
      child: Container(
        margin: const EdgeInsets.only(bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x33C95A5A), blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Text(
          ind ?? '·',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: Color(0xFFE2474F),
          ),
        ),
      ),
    );
  }

  Widget _statusPill(Mood mood, _Tod tod, Bond bond) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x29BE5A5A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Text(
        '${_bondLabel(bond)}  ·  ${_statusText(mood, tod)}',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFFA8425A),
        ),
      ),
    );
  }

  String _bondLabel(Bond bond) {
    switch (bond) {
      case Bond.distant:
        return '🤍 서먹';
      case Bond.warming:
        return '💗 친해지는 중';
      case Bond.close:
        return '❤️ 단짝';
    }
  }
}

// ───────────────────────── 씬 소품 ─────────────────────────

class _Floor extends StatelessWidget {
  const _Floor();
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFF7CCB4), Color(0xFFEEB89C)],
              ),
            ),
          ),
        ),
        // 걸레받이(벽-바닥 경계선)
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 7,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFE6A98C),
              border: Border(
                top: BorderSide(color: Color(0x55FFFFFF), width: 1.5),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Window extends StatelessWidget {
  final _Tod tod;
  const _Window({required this.tod});

  @override
  Widget build(BuildContext context) {
    final sky = switch (tod) {
      _Tod.day => const [Color(0xFFBFE4FF), Color(0xFFE9F7FF)],
      _Tod.sunset => const [Color(0xFFFFC58A), Color(0xFFFFB0C4)],
      _Tod.night => const [Color(0xFF26345F), Color(0xFF3E4E80)],
    };
    return Container(
      width: 96,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 5),
        boxShadow: const [
          BoxShadow(
              color: Color(0x2EAA786E), blurRadius: 18, offset: Offset(0, 8)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: sky,
                  ),
                ),
              ),
            ),
            // 해/달
            Positioned(
              right: tod == _Tod.night ? 12 : 10,
              top: tod == _Tod.sunset ? 34 : 10,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: switch (tod) {
                    _Tod.day => const Color(0xFFFFE08A),
                    _Tod.sunset => const Color(0xFFFFD089),
                    _Tod.night => const Color(0xFFEFEFFF),
                  },
                ),
              ),
            ),
            // 별 (밤) / 구름 (낮)
            if (tod == _Tod.night) ...[
              const Positioned(left: 14, top: 16, child: _Star()),
              const Positioned(left: 34, top: 40, child: _Star()),
              const Positioned(left: 60, top: 24, child: _Star()),
            ] else
              Positioned(
                left: 14,
                top: 44,
                child: Container(
                  width: 30,
                  height: 9,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            // 창틀 십자
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              right: 0,
              child: Center(child: Container(width: 4, color: Colors.white)),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(child: Container(height: 4, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _Star extends StatelessWidget {
  const _Star();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      decoration: const BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _WallFrame extends StatelessWidget {
  const _WallFrame();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 54,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        boxShadow: const [
          BoxShadow(
              color: Color(0x22AA786E), blurRadius: 10, offset: Offset(0, 5)),
        ],
      ),
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFFFFEAEF),
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        child: Center(
          child: Icon(Icons.favorite, size: 16, color: Color(0xFFF3A0B0)),
        ),
      ),
    );
  }
}

class _Lamp extends StatelessWidget {
  final bool lit;
  const _Lamp({required this.lit});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 갓
        Container(
          width: 36,
          height: 24,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: lit
                  ? const [Color(0xFFFFE9A8), Color(0xFFFFCF7A)]
                  : const [Color(0xFFF3D9C4), Color(0xFFE7C3A8)],
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(14),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: lit
                ? const [
                    BoxShadow(
                        color: Color(0x66FFD27F),
                        blurRadius: 20,
                        spreadRadius: 2)
                  ]
                : null,
          ),
        ),
        // 기둥
        Container(width: 4, height: 70, color: const Color(0xFFCBA88E)),
        // 받침
        Container(
          width: 26,
          height: 6,
          decoration: const BoxDecoration(
            color: Color(0xFFCBA88E),
            borderRadius: BorderRadius.all(Radius.circular(3)),
          ),
        ),
      ],
    );
  }
}

class _Plant extends StatelessWidget {
  const _Plant();
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 56,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // 잎
          Positioned(
            bottom: 18,
            child: SizedBox(
              width: 44,
              height: 40,
              child: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  _leaf(-0.5, const Color(0xFF7BB661)),
                  _leaf(0.0, const Color(0xFF8FCB6E)),
                  _leaf(0.5, const Color(0xFF6FA854)),
                ],
              ),
            ),
          ),
          // 화분
          Container(
            width: 30,
            height: 22,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFFE08A6E), Color(0xFFC9745A)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _leaf(double angle, Color c) {
    return Transform.rotate(
      angle: angle,
      alignment: Alignment.bottomCenter,
      child: Container(
        width: 16,
        height: 34,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}

class _Books extends StatelessWidget {
  const _Books();
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _book(34, const Color(0xFFE08AA0)),
        _book(40, const Color(0xFFF0B96B)),
        _book(30, const Color(0xFF8FB7D9)),
      ],
    );
  }

  Widget _book(double w, Color c) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      width: w,
      height: 9,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _Rug extends StatelessWidget {
  const _Rug();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 210,
      height: 56,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.elliptical(105, 28)),
        gradient: RadialGradient(
          colors: [Color(0x55FFD34D), Color(0x11FFB84D)],
        ),
      ),
    );
  }
}

/// 탭하면 위로 떠오르며 사라지는 하트 한 개.
class _Heart extends StatefulWidget {
  final VoidCallback onDone;
  const _Heart({super.key, required this.onDone});

  @override
  State<_Heart> createState() => _HeartState();
}

class _HeartState extends State<_Heart> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 950),
  );
  late final double _drift = (Random().nextDouble() - 0.5) * 36;

  @override
  void initState() {
    super.initState();
    _c.forward();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        final pop = t < 0.2 ? t / 0.2 : 1.0;
        return Transform.translate(
          offset: Offset(_drift * t, -70 * t),
          child: Opacity(
            opacity: (1 - t).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.6 + 0.6 * pop,
              child: const Icon(Icons.favorite,
                  size: 22, color: Color(0xFFE2474F)),
            ),
          ),
        );
      },
    );
  }
}
