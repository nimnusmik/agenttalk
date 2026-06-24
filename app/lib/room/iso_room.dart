import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../character/character_state.dart';
import '../chat/chat_controller.dart';
import 'furniture.dart';
import 'iso.dart';
import 'room_store.dart';

/// 노아의 방 — 아이소메트릭(2.5D, 파니룸 컨셉).
///
/// 마름모 격자 바닥 + 두 벽 위에서 노아(누끼)가 격자를 2D로 돌아다니며 생활한다.
/// 시간대/기분/호감도 기반 앰비언트 스케줄러로 침대(잠)·책상(앉기)·소파(쉬기)·
/// 창가(멍)로 알아서 이동. 말 걸면 가운데로 와 응시. 탭하면 하트.
/// 가구는 데이터(FurnitureItem)로 배치 → 2B 꾸미기 에디터로 편집 예정.
class RoomScreen extends StatefulWidget {
  final ChatController controller;
  final List<FurnitureItem> layout;
  const RoomScreen({
    super.key,
    required this.controller,
    this.layout = kDefaultLayout,
  });

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

enum _Tod { day, sunset, night }

enum _Activity { wander, sleep, desk, sofa, gaze, lookUser }

class _RoomScreenState extends State<RoomScreen> with TickerProviderStateMixin {
  static const int _cols = 5;
  static const int _rows = 5;

  // 방 배치(꾸미기로 편집·저장). widget.layout 을 초기값으로, 저장된 게 있으면 그걸로.
  late List<FurnitureItem> _layout;
  final RoomStore _roomStore = RoomStore();
  bool _edit = false; // 꾸미기 모드
  int? _sel; // 선택된 가구 index

  final _rng = Random();

  late final AnimationController _breathe;
  late final AnimationController _walk; // 한 번의 이동(0→1)

  // 격자 위 연속 좌표(타일 중심 기준). 시작: 방 가운데.
  double _fromFx = 2.5, _fromFy = 2.5;
  double _toFx = 2.5, _toFy = 2.5;
  int _hopSteps = 2;
  bool _facingRight = true;
  bool _looking = false;
  double _lift = 0; // 가구에 앉/눕을 때 몸을 띄우는 정도(px)
  String? _indicator;
  _Activity _activity = _Activity.wander;

  Timer? _actTimer;
  Timer? _lookTimer;
  Timer? _indTimer;

  int _lastMsgCount = 0;
  int _lastTick = 0;
  int _lastActionTick = 0;

  final List<int> _hearts = [];
  int _heartSeq = 0;
  Offset _lastFeet = Offset.zero; // 하트 스폰 위치용

  @override
  void initState() {
    super.initState();
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);
    _walk = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      value: 1,
    );
    _layout = List.of(widget.layout);
    _lastMsgCount = widget.controller.messages.length;
    _lastTick = widget.controller.attentionTick;
    _lastActionTick = widget.controller.actionTick;
    widget.controller.addListener(_onChange);
    _armNextActivity(const Duration(milliseconds: 1200));
    // 저장된 배치 복원
    _roomStore.load().then((saved) {
      if (saved != null && saved.isNotEmpty && mounted) {
        setState(() => _layout = saved);
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _actTimer?.cancel();
    _lookTimer?.cancel();
    _indTimer?.cancel();
    _breathe.dispose();
    _walk.dispose();
    super.dispose();
  }

  // 현재 보간된 격자 좌표
  double get _fx {
    final t = Curves.easeInOut.transform(_walk.value);
    return _fromFx + (_toFx - _fromFx) * t;
  }

  double get _fy {
    final t = Curves.easeInOut.transform(_walk.value);
    return _fromFy + (_toFy - _fromFy) * t;
  }

  double get _bounce {
    if (!_walk.isAnimating) return 0;
    final p = _walk.value;
    if (p <= 0 || p >= 1) return 0;
    return sin(p * _hopSteps * pi).abs();
  }

  /// 걸을 때 좌우로 살짝 흔들리는 값(-1..1).
  double get _sway {
    if (!_walk.isAnimating) return 0;
    final p = _walk.value;
    if (p <= 0 || p >= 1) return 0;
    return sin(p * _hopSteps * 2 * pi);
  }

  double get _poseTurns => _activity == _Activity.sleep ? -0.2 : 0.0;
  double get _poseSquash =>
      (_activity == _Activity.desk || _activity == _Activity.sofa) ? 0.9 : 1.0;

  // --- 컨트롤러 → 반응 ---
  void _onChange() {
    if (_edit) return; // 꾸미기 중엔 노아 반응 정지
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
    // 노아가 대화에서 고른 행동(LLM action) — react보다 우선해 위치를 정한다.
    if (c.actionTick != _lastActionTick) {
      _lastActionTick = c.actionTick;
      _doAction(c.pendingAction);
    }
  }

  void _doAction(String? a) {
    final act = switch (a) {
      'sleep' => _Activity.sleep,
      'desk' => _Activity.desk,
      'sofa' => _Activity.sofa,
      'window' => _Activity.gaze,
      'wander' => _Activity.wander,
      'come' => _Activity.lookUser,
      _ => null,
    };
    if (act == null) return;
    if (act == _Activity.lookUser) {
      _lookAtUser();
      return;
    }
    setState(() => _looking = false);
    _startActivity(act);
  }

  // --- 이동 ---
  void _moveToTile(double tx, double ty, {int? ms}) {
    final curFx = _fx, curFy = _fy;
    final dist = sqrt(pow(tx - curFx, 2) + pow(ty - curFy, 2));
    final dur = ms ?? (300 + dist * 320).clamp(380, 1500).round();
    // 화면상 진행 방향(isoX = gx-gy)으로 좌우 플립.
    final dx = (tx - ty) - (curFx - curFy);
    setState(() {
      if (dist > 0.05) _facingRight = dx >= 0;
      _fromFx = curFx;
      _fromFy = curFy;
      _toFx = tx;
      _toFy = ty;
      _hopSteps = max(1, dist.round());
    });
    _walk
      ..duration = Duration(milliseconds: dur)
      ..forward(from: 0);
  }

  // --- 앰비언트 스케줄러 ---
  void _armNextActivity(Duration delay) {
    _actTimer?.cancel();
    _actTimer = Timer(delay, _runScheduler);
  }

  void _runScheduler() {
    if (!mounted || _looking || _edit) return;
    _startActivity(_pickActivity());
  }

  _Activity _pickActivity() {
    final tod = _tod();
    final mood = moodFromScore(widget.controller.moodScore);
    final pool = <_Activity>[];
    void add(_Activity a, int w) {
      for (var i = 0; i < w; i++) {
        pool.add(a);
      }
    }

    switch (tod) {
      case _Tod.night:
        add(_Activity.sleep, 6);
        add(_Activity.sofa, 2);
        add(_Activity.gaze, 1);
        add(_Activity.wander, 1);
      case _Tod.sunset:
        add(_Activity.sofa, 4);
        add(_Activity.gaze, 3);
        add(_Activity.desk, 2);
        add(_Activity.wander, 1);
      case _Tod.day:
        add(_Activity.desk, 4);
        add(_Activity.gaze, 3);
        add(_Activity.sofa, 2);
        add(_Activity.wander, 2);
    }
    if (mood == Mood.down) {
      add(_Activity.sleep, 3);
      add(_Activity.sofa, 2);
    } else if (mood == Mood.up) {
      add(_Activity.gaze, 2);
      add(_Activity.wander, 1);
    }
    return pool[_rng.nextInt(pool.length)];
  }

  void _startActivity(_Activity a) {
    final target = _targetTile(a);
    setState(() {
      _activity = a;
      _lift = switch (a) {
        _Activity.sofa => 16,
        _Activity.sleep => 10,
        _Activity.desk => 12,
        _ => 0,
      };
      _indicator = _activityIndicator(a);
    });
    _indTimer?.cancel(); // 행동 표시는 행동 내내 유지
    _moveToTile(target.dx, target.dy);
    _actTimer?.cancel();
    _actTimer = Timer(Duration(milliseconds: _holdMs(a)), () {
      if (mounted && !_looking) _runScheduler();
    });
  }

  Offset _targetTile(_Activity a) {
    Offset tileOf(FurnitureType t, Offset fb) {
      for (final it in _layout) {
        if (it.type == t) return Offset(it.gx.toDouble(), it.gy.toDouble());
      }
      return fb;
    }

    switch (a) {
      case _Activity.sleep:
        final b = tileOf(FurnitureType.bed, const Offset(0, 1));
        return Offset(b.dx + 0.5, b.dy + 0.5); // 침대 위에 눕기
      case _Activity.desk:
        final d = tileOf(FurnitureType.desk, const Offset(0, 3));
        return Offset(d.dx + 1.5, d.dy + 0.5); // 책상 '앞 칸'에 앉기(겹침 방지)
      case _Activity.sofa:
        final s = tileOf(FurnitureType.sofa, const Offset(2, 3));
        return Offset(s.dx + 0.5, s.dy + 0.6); // 소파 앞쪽에 앉기(앞으로 와 안 가려짐)
      case _Activity.gaze:
        return const Offset(2.5, 1.1); // 창가/주방 쪽 멍
      case _Activity.lookUser:
        return const Offset(_cols / 2, _rows / 2);
      case _Activity.wander:
        return _randomOpenTile();
    }
  }

  /// 가구를 안 가리는 안전한 빈 칸들로만 배회 (소파 뒤·가구 칸 제외).
  static const List<List<int>> _wanderTiles = [
    [1, 1], [2, 1], [1, 2], [3, 2], [1, 3], [3, 3], [3, 1],
  ];
  Offset _randomOpenTile() {
    final t = _wanderTiles[_rng.nextInt(_wanderTiles.length)];
    return Offset(t[0] + 0.5, t[1] + 0.5);
  }

  int _holdMs(_Activity a) => switch (a) {
        _Activity.sleep => 13000,
        _Activity.desk => 8000,
        _Activity.sofa => 7000,
        _Activity.gaze => 6000,
        _Activity.wander => 2400,
        _Activity.lookUser => 0,
      };

  String? _activityIndicator(_Activity a) => switch (a) {
        _Activity.sleep => '💤',
        _Activity.desk => '✏️',
        _Activity.gaze => '☁️',
        _Activity.sofa => '🍵',
        _ => null,
      };

  void _lookAtUser() {
    _actTimer?.cancel();
    setState(() {
      _looking = true;
      _activity = _Activity.lookUser;
      _lift = 0;
      _indicator = '!';
    });
    _moveToTile(_cols / 2, _rows / 2, ms: 520);
    _indTimer?.cancel();
    _indTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _indicator = null);
    });
    _armReturnToActivity();
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
    _armReturnToActivity();
  }

  void _armReturnToActivity() {
    final lookMs = switch (bondFromAffinity(widget.controller.affinity)) {
      Bond.distant => 4500,
      Bond.warming => 6500,
      Bond.close => 9000,
    };
    _lookTimer?.cancel();
    _lookTimer = Timer(Duration(milliseconds: lookMs), () {
      if (!mounted) return;
      setState(() => _looking = false);
      _runScheduler();
    });
  }

  void _spawnHeart() {
    final id = _heartSeq++;
    setState(() => _hearts.add(id));
  }

  String? _indicatorFor(Emotion e) => switch (e) {
        Emotion.happy => '♪',
        Emotion.surprised => '!',
        Emotion.sad => '…',
        Emotion.thinking => '…',
        _ => null,
      };

  _Tod _tod() {
    final h = DateTime.now().hour;
    if (h >= 6 && h < 17) return _Tod.day;
    if (h >= 17 && h < 19) return _Tod.sunset;
    return _Tod.night;
  }

  @override
  Widget build(BuildContext context) {
    final mood = moodFromScore(widget.controller.moodScore);
    final tod = _tod();
    final bond = bondFromAffinity(widget.controller.affinity);
    final theme = _themes[kRoomTheme];

    return Scaffold(
      backgroundColor:
          tod == _Tod.night ? const Color(0xFF2A2742) : theme.bg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final cfg = IsoConfig.fit(
            cols: _cols,
            rows: _rows,
            availW: constraints.maxWidth,
            availH: constraints.maxHeight,
          );
          final noaW = cfg.tileW * 0.82;
          final noaH = noaW * 1.5;

          // ── 정적 레이어: 레이아웃/시간대가 바뀔 때만 다시 만들고 매 프레임엔 안 칠한다. ──
          final floor = RepaintBoundary(
            child: CustomPaint(
              painter: _RoomPainter(cfg, tod, theme),
              size: Size.infinite,
            ),
          );
          final furni = <_SceneObj>[];
          for (var i = 0; i < _layout.length; i++) {
            final it = _layout[i];
            final piece = _piece(it.type, cfg, theme);
            final cc = cfg.project(it.gx + 0.5, it.gy + 0.5);
            furni.add(_SceneObj(
              depth: it.gx + it.gy + 1.0,
              left: cc.dx - piece.boxW / 2,
              top: cc.dy - piece.anchorY,
              width: piece.boxW,
              height: piece.boxH,
              child: KeyedSubtree(
                key: ValueKey('f$i'),
                child: RepaintBoundary(child: piece.widget),
              ),
            ));
          }

          Widget posOf(_SceneObj o) => Positioned(
                left: o.left,
                top: o.top,
                width: o.width,
                height: o.height,
                child: o.child,
              );

          return Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _edit
                      ? null
                      : () {
                          _lookAtUser();
                          _spawnHeart();
                        },
                  onTapUp:
                      _edit ? (d) => _editSelectAt(d.localPosition, cfg) : null,
                  onPanStart:
                      _edit ? (d) => _editSelectAt(d.localPosition, cfg) : null,
                  onPanUpdate:
                      _edit ? (d) => _editDrag(d.localPosition, cfg) : null,
                  onPanEnd: _edit ? (_) => _editEnd() : null,
                  child: AnimatedBuilder(
                    // 매 프레임 다시 칠하는 건 노아뿐. 가구/바닥은 RepaintBoundary로 고정.
                    animation: Listenable.merge([_walk, _breathe]),
                    builder: (context, _) {
                      final feet = cfg.project(_fx, _fy);
                      _lastFeet = feet;
                      final noaDepth = _fx + _fy + 0.01;

                      return Stack(
                        children: [
                          Positioned.fill(child: floor),
                          // 노아보다 뒤(깊이 작음)
                          for (final o in furni)
                            if (o.depth <= noaDepth) posOf(o),
                          // 노아
                          Positioned(
                            left: feet.dx - noaW / 2,
                            top: feet.dy - noaH,
                            width: noaW,
                            height: noaH,
                            child: _buildNoa(noaW, noaH),
                          ),
                          // 노아보다 앞(깊이 큼)
                          for (final o in furni)
                            if (o.depth > noaDepth) posOf(o),
                          // 하트
                          ..._hearts.map(
                            (id) => Positioned(
                              left: _lastFeet.dx - 12,
                              top: _lastFeet.dy - noaH - 6,
                              child: _Heart(
                                key: ValueKey(id),
                                onDone: () =>
                                    setState(() => _hearts.remove(id)),
                              ),
                            ),
                          ),
                          // 분위기 오버레이
                          if (_ambient(tod) != null)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: ColoredBox(color: _ambient(tod)!),
                              ),
                            ),
                          if (_moodTint(mood) != null)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: ColoredBox(color: _moodTint(mood)!),
                              ),
                            ),
                          // 꾸미기: 선택 가구 타일 강조
                          if (_edit && _sel != null && _sel! < _layout.length)
                            _selHighlight(cfg),
                          // 상태 pill
                          Positioned(
                            left: 16,
                            top: 16,
                            child: SafeArea(
                              child: _statusPill(mood, tod, bond),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              // 꾸미기 토글
              Positioned(
                right: 14,
                top: 14,
                child: SafeArea(child: _editToggle()),
              ),
              // 선택 삭제
              if (_edit && _sel != null)
                Positioned(
                  right: 14,
                  top: 66,
                  child: SafeArea(child: _deleteBtn()),
                ),
              // 아이템 카탈로그
              if (_edit)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _catalogTray(),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildNoa(double noaW, double noaH) {
    final b = _breathe.value;
    final breatheSx = 1 + 0.022 * b;
    final breatheSy = 1 - 0.018 * b;

    final bnc = _bounce;
    final dy = -noaW * 0.18 * bnc; // 폴짝 (크기 비례)
    final dx = _sway * noaW * 0.06; // 좌우 흔들림
    final sq = 1 - bnc;
    final lean = (_facingRight ? 1 : -1) * 0.07 * bnc;

    final sx = breatheSx *
        (1 + 0.06 * sq * (bnc > 0 ? 1 : 0)) *
        (_facingRight ? 1 : -1);
    final sy = breatheSy * (1 - 0.06 * sq * (bnc > 0 ? 1 : 0)) * _poseSquash;

    final liftFade = (1 - _lift / 22).clamp(0.4, 1.0);

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        // 그림자(발밑, 바닥에 고정)
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 120),
            scale: (1 - 0.4 * bnc),
            child: Opacity(
              opacity: (1 - 0.5 * bnc) * liftFade,
              child: Container(
                width: noaW * 0.78,
                height: noaW * 0.26,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.all(Radius.elliptical(60, 16)),
                  gradient: RadialGradient(
                    colors: [Color(0x66241822), Color(0x00241822)],
                  ),
                ),
              ),
            ),
          ),
        ),
        // 노아 본체
        Align(
          alignment: Alignment.bottomCenter,
          child: Transform.translate(
            offset: Offset(dx, dy - _lift),
            child: Transform.rotate(
              angle: lean + _poseTurns * 2 * pi,
              alignment: Alignment.bottomCenter,
              child: Transform.scale(
                scaleX: sx,
                scaleY: sy,
                alignment: Alignment.bottomCenter,
                child: Image.asset(
                  'assets/character/noa_cut.png',
                  width: noaW * 0.92,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        ),
        // 머리 위 표시
        Align(
          alignment: Alignment.topCenter,
          child: _indicatorBubble(),
        ),
      ],
    );
  }

  Widget _indicatorBubble() {
    final ind = _indicator;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: ind == null ? 0 : 1,
      child: Container(
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
    final bondLabel = switch (bond) {
      Bond.distant => '🤍 서먹',
      Bond.warming => '💗 친해지는 중',
      Bond.close => '❤️ 단짝',
    };
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
              color: Color(0x29BE5A5A), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Text(
        '$bondLabel  ·  $m · $time',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          color: Color(0xFFA8425A),
        ),
      ),
    );
  }

  Color? _moodTint(Mood mood) => switch (mood) {
        Mood.down => const Color(0x163A4A6B),
        Mood.up => const Color(0x1AFFD27F),
        Mood.neutral => null,
      };

  Color? _ambient(_Tod tod) => switch (tod) {
        _Tod.night => const Color(0x242A2F55),
        _Tod.sunset => const Color(0x14FF8A5C),
        _Tod.day => null,
      };

  // ───────────────────────── 꾸미기(방 편집) ─────────────────────────

  /// 화면 좌표 → 격자 타일(역투영).
  (int, int) _tileAt(Offset p, IsoConfig cfg) {
    final a = (p.dx - cfg.origin.dx) / cfg.halfW; // gx - gy
    final b = (p.dy - cfg.origin.dy) / cfg.halfH; // gx + gy
    final gx = ((a + b) / 2).floor().clamp(0, _cols - 1);
    final gy = ((b - a) / 2).floor().clamp(0, _rows - 1);
    return (gx, gy);
  }

  int? _furnitureAt(int gx, int gy) {
    for (var i = _layout.length - 1; i >= 0; i--) {
      if (_layout[i].gx == gx && _layout[i].gy == gy) return i;
    }
    return null;
  }

  void _editSelectAt(Offset p, IsoConfig cfg) {
    final (gx, gy) = _tileAt(p, cfg);
    setState(() => _sel = _furnitureAt(gx, gy));
  }

  void _editDrag(Offset p, IsoConfig cfg) {
    if (_sel == null) return;
    final (gx, gy) = _tileAt(p, cfg);
    final cur = _layout[_sel!];
    if (cur.gx == gx && cur.gy == gy) return;
    setState(() {
      _layout = [..._layout]..[_sel!] = cur.copyWith(gx: gx, gy: gy);
    });
  }

  void _editEnd() => _saveLayout();

  void _addFurniture(FurnitureType t) {
    final occ = {for (final f in _layout) '${f.gx}_${f.gy}'};
    var gx = _cols ~/ 2, gy = _rows ~/ 2;
    outer:
    for (var y = 0; y < _rows; y++) {
      for (var x = 0; x < _cols; x++) {
        if (!occ.contains('${x}_$y')) {
          gx = x;
          gy = y;
          break outer;
        }
      }
    }
    setState(() {
      _layout = [..._layout, FurnitureItem(t, gx, gy)];
      _sel = _layout.length - 1;
    });
    _saveLayout();
  }

  void _deleteSelected() {
    if (_sel == null) return;
    setState(() {
      _layout = [..._layout]..removeAt(_sel!);
      _sel = null;
    });
    _saveLayout();
  }

  void _saveLayout() => _roomStore.save(_layout);

  void _toggleEdit() {
    setState(() {
      _edit = !_edit;
      _sel = null;
    });
    if (_edit) {
      _actTimer?.cancel();
      _lookTimer?.cancel();
    } else {
      _saveLayout();
      _armNextActivity(const Duration(milliseconds: 600));
    }
  }

  Widget _selHighlight(IsoConfig cfg) {
    final it = _layout[_sel!];
    final c = cfg.project(it.gx + 0.5, it.gy + 0.5);
    return Positioned(
      left: c.dx - cfg.tileW / 2,
      top: c.dy - cfg.tileH / 2,
      width: cfg.tileW,
      height: cfg.tileH,
      child: const IgnorePointer(child: _DiamondMarker()),
    );
  }

  Widget _editToggle() {
    return GestureDetector(
      onTap: _toggleEdit,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: _edit ? const Color(0xFFE2474F) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
                color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Text(
          _edit ? '✓ 완료' : '🛠 꾸미기',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: _edit ? Colors.white : const Color(0xFFA8425A),
          ),
        ),
      ),
    );
  }

  Widget _deleteBtn() {
    return GestureDetector(
      onTap: _deleteSelected,
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: const Icon(Icons.delete_outline,
            color: Color(0xFFE2474F), size: 22),
      ),
    );
  }

  static const Map<FurnitureType, String> _furniLabel = {
    FurnitureType.bed: '침대',
    FurnitureType.desk: '책상',
    FurnitureType.sofa: '소파',
    FurnitureType.table: '테이블',
    FurnitureType.lamp: '조명',
    FurnitureType.plant: '화분',
    FurnitureType.rug: '러그',
    FurnitureType.fridge: '냉장고',
    FurnitureType.counter: '싱크대',
  };

  Widget _catalogTray() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Color(0x22000000), blurRadius: 12, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            children: [
              for (final t in FurnitureType.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _addFurniture(t),
                    child: Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFBE7EF),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFF3C6D6)),
                      ),
                      child: Text(
                        '＋ ${_furniLabel[t] ?? t.name}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFA8425A),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 룸 테마(팔레트) ─────────────────────────

class _RoomTheme {
  final String name;
  final Color bg, floorA, floorB, wallL, wallR, outline, stripe;
  const _RoomTheme(this.name, this.bg, this.floorA, this.floorB, this.wallL,
      this.wallR, this.outline, this.stripe);
}

/// 비교용 팔레트 3종. kRoomTheme 로 선택(스크린샷 비교 후 확정).
const List<_RoomTheme> _themes = [
  _RoomTheme('핑크', Color(0xFFFDECF3), Color(0xFFFAD3E3), Color(0xFFF2BBD2),
      Color(0xFFF2A6C1), Color(0xFFF7B8CF), Color(0xFF9C5C76), Color(0x33FFFFFF)),
  _RoomTheme('크림', Color(0xFFFBF2E7), Color(0xFFF7E3CB), Color(0xFFEFD2AE),
      Color(0xFFE9C49A), Color(0xFFF1D1AB), Color(0xFF8C6A48), Color(0x33FFFFFF)),
  _RoomTheme('민트', Color(0xFFE8F5EE), Color(0xFFD7EEE1), Color(0xFFC0E1CF),
      Color(0xFFACD7C2), Color(0xFFBFE0CE), Color(0xFF4E7A66), Color(0x33FFFFFF)),
];

const int kRoomTheme = 2;

// ───────────────────────── 씬 오브젝트 ─────────────────────────

class _SceneObj {
  final double depth;
  final double left, top, width, height;
  final Widget child;
  const _SceneObj({
    required this.depth,
    required this.left,
    required this.top,
    required this.width,
    required this.height,
    required this.child,
  });
}

/// 아이소 가구 한 조각.
class _Piece {
  final Widget widget;
  final double boxW;
  final double boxH;
  final double anchorY; // 바닥 접촉점(발 위치)의 로컬 y
  const _Piece(this.widget, this.boxW, this.boxH, this.anchorY);
}

_Piece _piece(FurnitureType t, IsoConfig cfg, _RoomTheme theme) {
  if (kUseFurnitureSprites) return _spritePiece(t, cfg);
  final u = cfg.tileW * 0.70; // 가구는 타일보다 작게(방에 여백)
  final (w, h) = switch (t) {
    FurnitureType.rug => (u * 2.0, u * 1.1),
    FurnitureType.bed => (u * 2.0, u * 1.5),
    FurnitureType.desk => (u * 1.7, u * 1.7),
    FurnitureType.sofa => (u * 2.1, u * 1.7),
    FurnitureType.lamp => (u * 1.0, u * 2.3),
    FurnitureType.plant => (u * 1.0, u * 1.55),
    FurnitureType.fridge => (u * 1.4, u * 2.5),
    FurnitureType.counter => (u * 2.3, u * 1.6),
    FurnitureType.table => (u * 1.5, u * 1.0),
  };
  return _Piece(
    CustomPaint(size: Size(w, h), painter: _FurniPainter(t, u, theme.outline)),
    w,
    h,
    h - u * 0.10,
  );
}

/// 스프라이트 PNG 한 조각. 아트는 "바닥 접촉점 = 하단 중앙" 기준으로 그려졌다고 가정.
/// (폭 배수·종횡비는 실제 아트 들어오면 미세조정)
_Piece _spritePiece(FurnitureType t, IsoConfig cfg) {
  final wMul = switch (t) {
    FurnitureType.rug => 2.0,
    FurnitureType.bed => 2.0,
    FurnitureType.desk => 1.5,
    FurnitureType.sofa => 2.0,
    FurnitureType.lamp => 0.9,
    FurnitureType.plant => 1.0,
    FurnitureType.fridge => 1.3,
    FurnitureType.counter => 2.2,
    FurnitureType.table => 1.4,
  };
  final w = cfg.tileW * wMul;
  final h = w; // 정사각 캔버스 가정
  return _Piece(
    Image.asset(
      furnitureSprite(t),
      width: w,
      height: h,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      filterQuality: FilterQuality.medium,
    ),
    w,
    h,
    h - cfg.tileW * 0.06,
  );
}

/// 타입별 아이소 가구 페인터. 외곽선(셀룩) + 음영으로 "그려진 가구" 느낌.
class _FurniPainter extends CustomPainter {
  final FurnitureType type;
  final double u;
  final Color outline;
  _FurniPainter(this.type, this.u, this.outline);

  Paint get _ol => Paint()
    ..color = outline
    ..style = PaintingStyle.stroke
    ..strokeWidth = (u * 0.03).clamp(1.4, 3.2)
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas c, Size size) {
    final f = Offset(size.width / 2, size.height - u * 0.10); // 바닥 접촉점(발)
    switch (type) {
      case FurnitureType.rug:
        _rug(c, f);
      case FurnitureType.bed:
        _bed(c, f);
      case FurnitureType.desk:
        _desk(c, f);
      case FurnitureType.sofa:
        _sofa(c, f);
      case FurnitureType.lamp:
        _lamp(c, f);
      case FurnitureType.plant:
        _plant(c, f);
      case FurnitureType.fridge:
        _fridge(c, f);
      case FurnitureType.counter:
        _counter(c, f);
      case FurnitureType.table:
        _table(c, f);
    }
  }

  /// 아이소 큐브 + 외곽선. topCenter = 윗면 다이아몬드 중심.
  void _block(Canvas c, Offset topCenter, double hw, double h, Color top,
      Color left, Color right) {
    final hh = hw / 2;
    final t = Offset(topCenter.dx, topCenter.dy - hh);
    final r = Offset(topCenter.dx + hw, topCenter.dy);
    final b = Offset(topCenter.dx, topCenter.dy + hh);
    final l = Offset(topCenter.dx - hw, topCenter.dy);
    final ol = _ol;
    if (h > 0) {
      final rf = Path()
        ..moveTo(r.dx, r.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(b.dx, b.dy + h)
        ..lineTo(r.dx, r.dy + h)
        ..close();
      c.drawPath(rf, _vgrad(right, rf.getBounds()));
      c.drawPath(rf, ol);
      final lf = Path()
        ..moveTo(l.dx, l.dy)
        ..lineTo(b.dx, b.dy)
        ..lineTo(b.dx, b.dy + h)
        ..lineTo(l.dx, l.dy + h)
        ..close();
      c.drawPath(lf, _vgrad(left, lf.getBounds()));
      c.drawPath(lf, ol);
    }
    final tf = Path()
      ..moveTo(t.dx, t.dy)
      ..lineTo(r.dx, r.dy)
      ..lineTo(b.dx, b.dy)
      ..lineTo(l.dx, l.dy)
      ..close();
    c.drawPath(tf, _vgrad(top, tf.getBounds(), hl: true));
    c.drawPath(tf, ol);
  }

  /// 면에 세로 그라데이션(입체감). hl=true면 윗면(위가 더 밝게).
  Paint _vgrad(Color base, Rect r, {bool hl = false}) {
    final c1 = hl ? Color.lerp(base, Colors.white, 0.16)! : base;
    final c2 = hl ? base : Color.lerp(base, const Color(0xFF241018), 0.22)!;
    return Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [c1, c2],
      ).createShader(r);
  }

  void _ground(Canvas c, Offset base, double hw, double h, Color top, Color left,
          Color right) =>
      _block(c, Offset(base.dx, base.dy - h), hw, h, top, left, right);

  void _diamond(Canvas c, Offset center, double hw, Color color,
      {bool stroke = true}) {
    final hh = hw / 2;
    final p = Path()
      ..moveTo(center.dx, center.dy - hh)
      ..lineTo(center.dx + hw, center.dy)
      ..lineTo(center.dx, center.dy + hh)
      ..lineTo(center.dx - hw, center.dy)
      ..close();
    c.drawPath(p, Paint()..color = color);
    if (stroke) c.drawPath(p, _ol);
  }

  void _circle(Canvas c, Offset center, double r, Color color) {
    c.drawCircle(center, r, Paint()..color = color);
    c.drawCircle(center, r, _ol);
  }

  // 큐브 앞 두 면에 가로 이음선(쿠션/문짝 분할). frac: 0=윗면, 1=바닥.
  void _seam(Canvas c, Offset topCenter, double hw, double h, double frac) {
    final hh = hw / 2;
    final r = Offset(topCenter.dx + hw, topCenter.dy);
    final b = Offset(topCenter.dx, topCenter.dy + hh);
    final l = Offset(topCenter.dx - hw, topCenter.dy);
    final y = h * frac;
    c.drawLine(Offset(r.dx, r.dy + y), Offset(b.dx, b.dy + y), _ol);
    c.drawLine(Offset(l.dx, l.dy + y), Offset(b.dx, b.dy + y), _ol);
  }

  void _rug(Canvas c, Offset f) {
    _diamond(c, f, u * 0.95, const Color(0x88F2C14E));
    _diamond(c, f, u * 0.74, const Color(0x55E0A93A));
    _diamond(c, f, u * 0.52, const Color(0x77FFE7A0));
    final dot = Paint()..color = const Color(0x66E0A93A);
    for (final o in [
      Offset(0, -u * 0.30),
      Offset(0, u * 0.30),
      Offset(-u * 0.6, 0),
      Offset(u * 0.6, 0),
    ]) {
      c.drawCircle(f + o, u * 0.05, dot);
    }
  }

  void _table(Canvas c, Offset f) {
    final legH = u * 0.34;
    const cw = 0.5;
    for (final cnr in [
      Offset(0, -u * cw * 0.5),
      Offset(-u * cw, 0),
      Offset(u * cw, 0),
      Offset(0, u * cw * 0.5),
    ]) {
      _ground(c, f + cnr, u * 0.06, legH, const Color(0xFFC79B72),
          const Color(0xFFA67E58), const Color(0xFFB98C64));
    }
    final topC = f - Offset(0, legH + u * 0.07);
    _block(c, topC, u * 0.6, u * 0.07, const Color(0xFFE7C39B),
        const Color(0xFFC49A6E), const Color(0xFFD6AE82));
    // 책
    _block(c, topC + Offset(-u * 0.16, -u * 0.10), u * 0.14, u * 0.06,
        const Color(0xFF8FB7D9), const Color(0xFF6E97BC), const Color(0xFF7DA6CB));
    // 작은 화병
    _block(c, topC + Offset(u * 0.14, -u * 0.13), u * 0.07, u * 0.17,
        const Color(0xFFF3A6BC), const Color(0xFFD98298), const Color(0xFFE793A8));
  }

  void _bed(Canvas c, Offset f) {
    // 프레임
    _ground(c, f, u * 0.86, u * 0.16, const Color(0xFFC9B79E),
        const Color(0xFFA88E72), const Color(0xFFBBA084));
    final frameTop = f - Offset(0, u * 0.16);
    // 매트리스 + 이불
    final matC = frameTop - Offset(0, u * 0.22);
    _block(c, matC, u * 0.78, u * 0.22, const Color(0xFFDCEEF8),
        const Color(0xFFA9CBE0), const Color(0xFFBFD9EC));
    // 이불 접힘선
    _seam(c, matC, u * 0.78, u * 0.22, 0.5);
    // 베개 2개(머리쪽)
    final matTop = frameTop - Offset(0, u * 0.44);
    _block(c, matTop + Offset(-u * 0.34, -u * 0.05), u * 0.26, u * 0.12,
        Colors.white, const Color(0xFFD8E2EA), const Color(0xFFE8EEF3));
    _block(c, matTop + Offset(-u * 0.05, -u * 0.05), u * 0.26, u * 0.12,
        Colors.white, const Color(0xFFD8E2EA), const Color(0xFFE8EEF3));
  }

  void _sofa(Canvas c, Offset f) {
    final seatTop = f - Offset(0, u * 0.30);
    final backC = seatTop - Offset(0, u * 0.62);
    // 등받이
    _block(c, backC, u * 0.8, u * 0.46, const Color(0xFFF2A0B4),
        const Color(0xFFD9809A), const Color(0xFFE791A6));
    // 등 쿠션 2개
    _block(c, backC + Offset(-u * 0.34, 0), u * 0.3, u * 0.22,
        const Color(0xFFF8BACB), const Color(0xFFE49AAE), const Color(0xFFEEA6B8));
    _block(c, backC + Offset(u * 0.34, 0), u * 0.3, u * 0.22,
        const Color(0xFFF8BACB), const Color(0xFFE49AAE), const Color(0xFFEEA6B8));
    // 좌석
    _ground(c, f, u * 0.84, u * 0.30, const Color(0xFFF6AEC2),
        const Color(0xFFDB8197), const Color(0xFFEA94AA));
    // 좌석 쿠션 분할선(윗면 중앙)
    c.drawLine(Offset(seatTop.dx, seatTop.dy - u * 0.42),
        Offset(seatTop.dx, seatTop.dy + u * 0.42), _ol);
    // 팔걸이 좌/우
    _block(c, seatTop - Offset(u * 0.66, u * 0.34), u * 0.18, u * 0.34,
        const Color(0xFFF8BACB), const Color(0xFFE08AA0), const Color(0xFFEEA0B4));
    _block(c, seatTop + Offset(u * 0.66, 0) - Offset(0, u * 0.34), u * 0.18,
        u * 0.34, const Color(0xFFF8BACB), const Color(0xFFE08AA0),
        const Color(0xFFEEA0B4));
  }

  void _desk(Canvas c, Offset f) {
    final legH = u * 0.62;
    const cw = 0.52;
    final corners = [
      Offset(0, -u * cw * 0.5),
      Offset(-u * cw, 0),
      Offset(u * cw, 0),
      Offset(0, u * cw * 0.5),
    ];
    for (final cnr in corners) {
      _ground(c, f + cnr, u * 0.07, legH, const Color(0xFFCBA078),
          const Color(0xFFA9805C), const Color(0xFFBC8F68));
    }
    final topCenter = f - Offset(0, legH + u * 0.10);
    _block(c, topCenter, u * 0.66, u * 0.10, const Color(0xFFE7C39B),
        const Color(0xFFC49A6E), const Color(0xFFD6AE82));
    // 책 한 권
    _block(c, topCenter + Offset(-u * 0.20, -u * 0.14), u * 0.16, u * 0.08,
        const Color(0xFFE08AA0), const Color(0xFFC06A82), const Color(0xFFD17B92));
    // 머그컵
    _block(c, topCenter + Offset(u * 0.22, -u * 0.12), u * 0.08, u * 0.13,
        const Color(0xFFF3A6BC), const Color(0xFFD98298), const Color(0xFFE793A8));
  }

  void _lamp(Canvas c, Offset f) {
    _ground(c, f, u * 0.2, u * 0.06, const Color(0xFFCBA88E),
        const Color(0xFFA9876E), const Color(0xFFBC987E));
    _ground(c, f, u * 0.045, u * 1.15, const Color(0xFFCBA88E),
        const Color(0xFFB08B70), const Color(0xFFBE987C));
    final poleTop = f - Offset(0, u * 1.15);
    _block(c, poleTop - Offset(0, u * 0.26), u * 0.3, u * 0.26,
        const Color(0xFFFFE9A8), const Color(0xFFE9C77A), const Color(0xFFF4D88E));
  }

  void _plant(Canvas c, Offset f) {
    _ground(c, f, u * 0.22, u * 0.30, const Color(0xFFD98A6E),
        const Color(0xFFB06A52), const Color(0xFFC47A60));
    final potTop = f - Offset(0, u * 0.30);
    _circle(c, potTop + Offset(0, -u * 0.17), u * 0.20, const Color(0xFF8FCB6E));
    _circle(c, potTop + Offset(-u * 0.14, -u * 0.27), u * 0.14,
        const Color(0xFF79B85A));
    _circle(c, potTop + Offset(u * 0.14, -u * 0.27), u * 0.14,
        const Color(0xFF79B85A));
    _circle(c, potTop + Offset(0, -u * 0.38), u * 0.15, const Color(0xFF8FCB6E));
  }

  void _fridge(Canvas c, Offset f) {
    final w = u * 0.46;
    // 냉장(아래)
    _ground(c, f, w, u * 1.15, const Color(0xFFF1EEE9), const Color(0xFFCEC8C0),
        const Color(0xFFE0DAD2));
    // 냉동(위) — 도어 분리선
    final lowTop = f - Offset(0, u * 1.15);
    _block(c, lowTop - Offset(0, u * 0.62), w, u * 0.62, const Color(0xFFF6F4F0),
        const Color(0xFFD6D0C9), const Color(0xFFE7E2DB));
    // 손잡이 2개(앞 모서리)
    _block(c, f - Offset(w * 0.6, u * 0.55), u * 0.05, u * 0.34,
        const Color(0xFFBFB8AF), const Color(0xFFA39C93), const Color(0xFFB0A99F));
    _block(c, lowTop - Offset(w * 0.6, u * 0.18), u * 0.05, u * 0.24,
        const Color(0xFFBFB8AF), const Color(0xFFA39C93), const Color(0xFFB0A99F));
    // 하트 자석
    _circle(c, f + Offset(w * 0.2, -u * 0.72), u * 0.07, const Color(0xFFF3A6BC));
  }

  void _counter(Canvas c, Offset f) {
    // 하부장
    _ground(c, f, u * 0.95, u * 0.66, const Color(0xFFF3E7D6),
        const Color(0xFFCBB89E), const Color(0xFFE0CEB4));
    final cabC = f - Offset(0, u * 0.66);
    // 서랍선 + 손잡이
    _seam(c, cabC, u * 0.95, u * 0.66, 0.30);
    _circle(c, f + Offset(-u * 0.30, -u * 0.30), u * 0.045, const Color(0xFF9A8E7A));
    _circle(c, f + Offset(u * 0.30, -u * 0.30), u * 0.045, const Color(0xFF9A8E7A));
    // 상판
    _block(c, cabC - Offset(0, u * 0.08), u * 1.0, u * 0.08,
        const Color(0xFFEDE3D6), const Color(0xFFC9BBA6), const Color(0xFFDBCDB6));
    // 싱크볼 + 수도꼭지
    final surf = cabC - Offset(0, u * 0.08);
    _diamond(c, surf + Offset(u * 0.28, 0), u * 0.34, const Color(0xFFB9C6C9));
    final fp = surf + Offset(-u * 0.18, -u * 0.02);
    c.drawLine(fp, fp - Offset(0, u * 0.26), _ol);
    c.drawLine(fp - Offset(0, u * 0.26), fp + Offset(u * 0.16, -u * 0.2), _ol);
  }

  @override
  bool shouldRepaint(_FurniPainter old) =>
      old.type != type || old.u != u || old.outline != outline;
}

// ───────────────────────── 바닥 + 벽 ─────────────────────────

class _RoomPainter extends CustomPainter {
  final IsoConfig cfg;
  final _Tod tod;
  final _RoomTheme theme;
  _RoomPainter(this.cfg, this.tod, this.theme);

  bool get _dark => tod == _Tod.night;
  Color get _wallR => _dark ? const Color(0xFF53507A) : theme.wallR;
  Color get _wallL => _dark ? const Color(0xFF45426A) : theme.wallL;
  Color get _floorA => _dark ? const Color(0xFF6A6690) : theme.floorA;
  Color get _floorB => _dark ? const Color(0xFF5E5A85) : theme.floorB;
  Color get _outlineC => _dark ? const Color(0x66FFFFFF) : theme.outline;

  Paint get _ol => Paint()
    ..color = _outlineC
    ..style = PaintingStyle.stroke
    ..strokeWidth = (cfg.tileW * 0.03).clamp(1.4, 3.0)
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas c, Size size) {
    _paintWalls(c);
    _paintFloor(c);
    _paintDoor(c);
    _paintWindow(c);
    _paintWallDecor(c);
  }

  void _paintWalls(Canvas c) {
    final p0 = cfg.project(0, 0);
    final pR = cfg.project(cfg.cols.toDouble(), 0);
    final pL = cfg.project(0, cfg.rows.toDouble());
    final h = cfg.wallH;

    final right = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(pR.dx, pR.dy)
      ..lineTo(pR.dx, pR.dy - h)
      ..lineTo(p0.dx, p0.dy - h)
      ..close();
    c.drawPath(right, Paint()..color = _wallR);

    final left = Path()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(pL.dx, pL.dy)
      ..lineTo(pL.dx, pL.dy - h)
      ..lineTo(p0.dx, p0.dy - h)
      ..close();
    c.drawPath(left, Paint()..color = _wallL);

    // 세로 줄무늬
    final stripe = Paint()
      ..color = theme.stripe
      ..strokeWidth = 2;
    for (var gx = 1; gx < cfg.cols; gx++) {
      final b = cfg.project(gx.toDouble(), 0);
      c.drawLine(Offset(b.dx, b.dy), Offset(b.dx, b.dy - h), stripe);
    }
    for (var gy = 1; gy < cfg.rows; gy++) {
      final b = cfg.project(0, gy.toDouble());
      c.drawLine(Offset(b.dx, b.dy), Offset(b.dx, b.dy - h), stripe);
    }

    // 벽 외곽선 + 뒤 모서리
    c.drawPath(right, _ol);
    c.drawPath(left, _ol);
    c.drawLine(Offset(p0.dx, p0.dy), Offset(p0.dx, p0.dy - h), _ol);
  }

  void _paintFloor(Canvas c) {
    for (var gx = 0; gx < cfg.cols; gx++) {
      for (var gy = 0; gy < cfg.rows; gy++) {
        final t = cfg.project(gx.toDouble(), gy.toDouble());
        final r = cfg.project(gx + 1.0, gy.toDouble());
        final bot = cfg.project(gx + 1.0, gy + 1.0);
        final l = cfg.project(gx.toDouble(), gy + 1.0);
        final path = Path()
          ..moveTo(t.dx, t.dy)
          ..lineTo(r.dx, r.dy)
          ..lineTo(bot.dx, bot.dy)
          ..lineTo(l.dx, l.dy)
          ..close();
        c.drawPath(path, Paint()..color = (gx + gy).isEven ? _floorA : _floorB);
      }
    }
    // 방 바닥 테두리 외곽선
    final c0 = cfg.project(0, 0);
    final cR = cfg.project(cfg.cols.toDouble(), 0);
    final cF = cfg.project(cfg.cols.toDouble(), cfg.rows.toDouble());
    final cL = cfg.project(0, cfg.rows.toDouble());
    c.drawPath(
      Path()
        ..moveTo(c0.dx, c0.dy)
        ..lineTo(cR.dx, cR.dy)
        ..lineTo(cF.dx, cF.dy)
        ..lineTo(cL.dx, cL.dy)
        ..close(),
      _ol,
    );
  }

  Color _skyColor() => switch (tod) {
        _Tod.day => const Color(0xFFBFE4FF),
        _Tod.sunset => const Color(0xFFFFC58A),
        _Tod.night => const Color(0xFF2B3B66),
      };

  void _paintWindow(Canvas c) {
    final p0 = cfg.project(0, 0);
    final pR = cfg.project(cfg.cols.toDouble(), 0);
    final h = cfg.wallH;
    Offset along(double tt) => Offset.lerp(p0, pR, tt)!;
    final bl = along(0.45), br = along(0.86);
    final y1 = h * 0.30, y2 = h * 0.82;
    final quad = Path()
      ..moveTo(bl.dx, bl.dy - y1)
      ..lineTo(br.dx, br.dy - y1)
      ..lineTo(br.dx, br.dy - y2)
      ..lineTo(bl.dx, bl.dy - y2)
      ..close();
    c.drawPath(quad, Paint()..color = _skyColor());
    // 창틀 십자
    final mx = Offset.lerp(bl, br, 0.5)!;
    c.drawLine(Offset(mx.dx, mx.dy - y1), Offset(mx.dx, mx.dy - y2), _ol);
    final ymid = (y1 + y2) / 2;
    c.drawLine(Offset(bl.dx, bl.dy - ymid), Offset(br.dx, br.dy - ymid), _ol);
    // 프레임
    c.drawPath(
      quad,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = (cfg.tileW * 0.06).clamp(3, 7),
    );
    c.drawPath(quad, _ol);
  }

  void _paintDoor(Canvas c) {
    final p0 = cfg.project(0, 0);
    final pL = cfg.project(0, cfg.rows.toDouble());
    final h = cfg.wallH;
    Offset along(double tt) => Offset.lerp(p0, pL, tt)!;
    final bl = along(0.24), br = along(0.64);
    final y2 = h * 0.87;
    final quad = Path()
      ..moveTo(bl.dx, bl.dy)
      ..lineTo(br.dx, br.dy)
      ..lineTo(br.dx, br.dy - y2)
      ..lineTo(bl.dx, bl.dy - y2)
      ..close();
    c.drawPath(quad, Paint()..color = const Color(0xFFD9B48F));
    c.drawPath(quad, _ol);
    // 손잡이
    final knob = Offset.lerp(bl, br, 0.82)!;
    final ko = Offset(knob.dx, knob.dy - y2 * 0.5);
    final kr = (cfg.tileW * 0.05).clamp(2.5, 5.0);
    c.drawCircle(ko, kr, Paint()..color = const Color(0xFFEFC04A));
    c.drawCircle(ko, kr, _ol);
  }

  /// 벽 소품 — 오른쪽 벽 벽시계, 왼쪽 벽 액자.
  void _paintWallDecor(Canvas c) {
    final p0 = cfg.project(0, 0);
    final pR = cfg.project(cfg.cols.toDouble(), 0);
    final pL = cfg.project(0, cfg.rows.toDouble());
    final h = cfg.wallH;

    // 에어컨 (오른쪽 벽 위쪽)
    final a0 = Offset.lerp(p0, pR, 0.08)!;
    final a1 = Offset.lerp(p0, pR, 0.32)!;
    final ay0 = h * 0.74, ay1 = h * 0.90;
    final ac = Path()
      ..moveTo(a0.dx, a0.dy - ay0)
      ..lineTo(a1.dx, a1.dy - ay0)
      ..lineTo(a1.dx, a1.dy - ay1)
      ..lineTo(a0.dx, a0.dy - ay1)
      ..close();
    c.drawPath(ac, Paint()..color = Colors.white);
    c.drawPath(ac, _ol);
    final av = ay0 + (ay1 - ay0) * 0.32;
    c.drawLine(Offset(a0.dx, a0.dy - av), Offset(a1.dx, a1.dy - av), _ol);

    // 벽시계 (오른쪽 벽, 에어컨 아래)
    final cc = Offset.lerp(p0, pR, 0.22)!;
    final co = Offset(cc.dx, cc.dy - h * 0.52);
    final cr = (cfg.tileW * 0.14).clamp(7.0, 14.0);
    c.drawCircle(co, cr, Paint()..color = Colors.white);
    c.drawCircle(co, cr, _ol);
    c.drawLine(co, co + Offset(0, -cr * 0.62), _ol);
    c.drawLine(co, co + Offset(cr * 0.5, cr * 0.12), _ol);

    // 액자 (왼쪽 벽 위쪽)
    final a = Offset.lerp(p0, pL, 0.72)!;
    final b = Offset.lerp(p0, pL, 0.9)!;
    final y0 = h * 0.50, y1 = h * 0.72;
    final frame = Path()
      ..moveTo(a.dx, a.dy - y0)
      ..lineTo(b.dx, b.dy - y0)
      ..lineTo(b.dx, b.dy - y1)
      ..lineTo(a.dx, a.dy - y1)
      ..close();
    c.drawPath(frame, Paint()..color = const Color(0xFFFFF4E2));
    c.drawPath(frame, _ol);
    final ci = Offset.lerp(a, b, 0.5)!;
    c.drawCircle(
      Offset(ci.dx, ci.dy - (y0 + y1) / 2),
      cr * 0.46,
      Paint()..color = const Color(0xFFF3A6BC),
    );
  }

  @override
  bool shouldRepaint(_RoomPainter old) =>
      old.tod != tod ||
      old.theme != theme ||
      old.cfg.tileW != cfg.tileW ||
      old.cfg.origin != cfg.origin;
}

// ───────────────────────── 꾸미기 선택 마커 ─────────────────────────

class _DiamondMarker extends StatelessWidget {
  const _DiamondMarker();
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DiamondPainter());
}

class _DiamondPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Path()
      ..moveTo(s.width / 2, 0)
      ..lineTo(s.width, s.height / 2)
      ..lineTo(s.width / 2, s.height)
      ..lineTo(0, s.height / 2)
      ..close();
    c.drawPath(p, Paint()..color = const Color(0x553BE0A0));
    c.drawPath(
      p,
      Paint()
        ..color = const Color(0xFF2BB07A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_DiamondPainter old) => false;
}

// ───────────────────────── 하트 파티클 ─────────────────────────

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
