// 3D 노아의 방 — 재사용 위젯(셸 안에 들어감, Scaffold 없음).
// Kenney Furniture Kit(CC0 glTF) 가구 + 물리 그림자 + 노아 빌보드 행동.
// 가구는 노아(딸기고양이) 색감으로 리컬러.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_advanced_loaders/three_js_advanced_loaders.dart'
    as loaders;

import '../chat/chat_controller.dart';

/// 행동 지점(바닥 x,z + 행동 종류).
class _Spot {
  final double x, z;
  final String act; // sleep / sofa / desk / gaze / idle
  const _Spot(this.x, this.z, this.act);
}

/// 노아 머리 위 이모지 표시(화면 좌표).
class _Hud {
  final double left, top;
  final String emoji;
  const _Hud(this.left, this.top, this.emoji);
}

class Room3DView extends StatefulWidget {
  /// 톡과 공유되는 컨트롤러(향후 대화 action ↔ 노아 행동 연동에 사용).
  final ChatController? controller;
  const Room3DView({super.key, this.controller});

  @override
  State<Room3DView> createState() => _Room3DViewState();
}

class _Room3DViewState extends State<Room3DView> {
  late three.ThreeJS threeJs;

  three.Object3D? _noa;
  double _noaH = 0.9;
  final math.Random _rng = math.Random();
  final List<_Spot> _spots = const [
    _Spot(-1.3, -0.5, 'sleep'),
    _Spot(-0.2, 0.95, 'sofa'),
    _Spot(-1.25, 1.5, 'desk'),
    _Spot(0.7, -1.1, 'gaze'),
    _Spot(0.5, 1.0, 'idle'),
    _Spot(1.7, 1.1, 'idle'),
  ];
  late _Spot _target = _spots[1];
  double _hold = 0;
  double _phase = 0;
  int _lastActionTick = 0;
  final ValueNotifier<_Hud?> _hud = ValueNotifier<_Hud?>(null);

  @override
  void initState() {
    threeJs = three.ThreeJS(
      onSetupComplete: () => setState(() {}),
      setup: _setup,
    );
    final c = widget.controller;
    if (c != null) {
      _lastActionTick = c.actionTick;
      c.addListener(_onController);
    }
    super.initState();
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onController);
    _hud.dispose();
    threeJs.dispose();
    three.loading.clear();
    super.dispose();
  }

  // 대화에서 노아가 고른 행동(LLM action) → 해당 지점으로 즉시 이동.
  void _onController() {
    final c = widget.controller;
    if (c == null) return;
    if (c.actionTick != _lastActionTick) {
      _lastActionTick = c.actionTick;
      final act = switch (c.pendingAction) {
        'sleep' => 'sleep',
        'desk' => 'desk',
        'sofa' => 'sofa',
        'window' => 'gaze',
        'wander' => 'idle',
        'come' => 'idle',
        _ => null,
      };
      if (act == null) return;
      _target = _spots.firstWhere((s) => s.act == act, orElse: () => _spots[4]);
      _hold = 0; // 머무는 중이어도 새 명령 지점으로 바로 출발
    }
  }

  Future<void> _add(String name, double x, double z,
      {double s = 1.0, double ryDeg = 0, double y = 0, int? colorHex}) async {
    try {
      final g = await loaders.GLTFLoader().fromAsset('assets/room3d/$name.glb');
      if (g == null) return;
      final o = g.scene;
      o.scale.setValues(s, s, s);
      o.position.setValues(x, y, z);
      o.rotation.y = ryDeg * math.pi / 180;
      o.traverse((c) {
        if (c is three.Mesh) {
          c.castShadow = true;
          c.receiveShadow = true;
          if (colorHex != null) {
            final m = c.material;
            if (m is three.MeshStandardMaterial) {
              m.map = null;
              m.color = three.Color.fromHex32(colorHex);
              m.needsUpdate = true;
            }
          }
        }
      });
      threeJs.scene.add(o);
    } catch (_) {}
  }

  Future<void> _addNoa(double x, double z, {double height = 0.9}) async {
    _noaH = height;
    const aspect = 0.82;
    final w = height * aspect;
    final plane = three.Mesh(
      three.PlaneGeometry(w, height),
      three.MeshBasicMaterial.fromMap({'color': 0xFF77AA, 'side': three.DoubleSide}),
    );
    plane.position.setValues(x, height / 2, z);
    plane.rotation.y = math.pi / 4;
    threeJs.scene.add(plane);
    _noa = plane;
    try {
      final data = await rootBundle.load('assets/character/noa_cut.png');
      final tex = await three.TextureLoader(flipY: true)
          .fromBytes(data.buffer.asUint8List());
      if (tex == null) return;
      tex.colorSpace = three.SRGBColorSpace;
      plane.material = three.MeshBasicMaterial.fromMap({
        'map': tex,
        'transparent': true,
        'alphaTest': 0.5,
        'side': three.DoubleSide,
      });
    } catch (_) {}
  }

  Future<void> _setup() async {
    threeJs.scene = three.Scene();
    threeJs.scene.background = three.Color.fromHex32(0xF6EAE3);

    final aspect = threeJs.width / threeJs.height;
    const w = 3.15;
    threeJs.camera =
        three.OrthographicCamera(-w, w, w / aspect, -w / aspect, 0.1, 2000);
    threeJs.camera.position.setValues(60, 60, 60);
    threeJs.camera.lookAt(three.Vector3(0, 0.5, 0));

    threeJs.scene.add(three.HemisphereLight(0xf3fbf7, 0xf0e6de, 0.66));
    final sun = three.DirectionalLight(0xfff3df, 0.55);
    sun.position.setValues(-6, 12, 6);
    sun.castShadow = true;
    sun.shadow?.camera?.left = -8;
    sun.shadow?.camera?.right = 8;
    sun.shadow?.camera?.top = 8;
    sun.shadow?.camera?.bottom = -8;
    sun.shadow?.camera?.near = 0.5;
    sun.shadow?.camera?.far = 60;
    sun.shadow?.mapSize.width = 2048;
    sun.shadow?.mapSize.height = 2048;
    sun.shadow?.bias = -0.0006;
    threeJs.scene.add(sun);

    threeJs.renderer?.shadowMap.enabled = true;
    threeJs.renderer?.shadowMap.type = three.PCFSoftShadowMap;

    const half = 2.6;
    final floor = three.Mesh(
      three.PlaneGeometry(half * 2, half * 2),
      three.MeshStandardMaterial.fromMap({'color': 0xEAD9D0, 'roughness': 1.0}),
    );
    floor.rotation.x = -math.pi / 2;
    floor.receiveShadow = true;
    threeJs.scene.add(floor);

    const wallH = 2.6;
    final wallMat =
        three.MeshStandardMaterial.fromMap({'color': 0xF3E7DF, 'roughness': 1.0});
    final wallBack = three.Mesh(three.PlaneGeometry(half * 2, wallH), wallMat);
    wallBack.position.setValues(0, wallH / 2, -half);
    wallBack.receiveShadow = true;
    threeJs.scene.add(wallBack);
    final wallLeft = three.Mesh(three.PlaneGeometry(half * 2, wallH), wallMat);
    wallLeft.rotation.y = math.pi / 2;
    wallLeft.position.setValues(-half, wallH / 2, 0);
    wallLeft.receiveShadow = true;
    threeJs.scene.add(wallLeft);

    // 노아(딸기고양이) 색감 팔레트: 딸기 레드/핑크 + 크림(털) + 잎 그린
    await _add('bedDouble', -1.5, -1.4, ryDeg: 0, colorHex: 0xF0AEA4);
    await _add('kitchenSink', -0.2, -2.05, ryDeg: 0, colorHex: 0xF1E7DC);
    await _add('kitchenFridge', 1.3, -2.05, ryDeg: 0, s: 1.1, colorHex: 0xF3EAE0);
    await _add('desk', -2.0, 1.0, ryDeg: 90, colorHex: 0xE7CDB0);
    await _add('chairDesk', -1.3, 1.0, ryDeg: -90, colorHex: 0xEBB3A8);
    await _add('rugRounded', 0.3, 0.6, colorHex: 0xE3A39B);
    await _add('loungeSofa', -0.2, 0.1, ryDeg: 0, colorHex: 0xEC9E94);
    await _add('tableCoffee', 0.3, 1.2, colorHex: 0xE7CDB0);
    await _add('lampRoundFloor', 1.6, 0.3, s: 1.25, colorHex: 0xEAD9C4);
    await _add('pottedPlant', 2.0, 1.8, s: 1.15, colorHex: 0x86B96A);

    threeJs.addAnimationEvent(_tickNoa);
    _addNoa(0.5, 1.0);
  }

  String? _emojiFor(String act) => switch (act) {
        'sleep' => '💤',
        'sofa' => '🍵',
        'desk' => '✏️',
        'gaze' => '☁️',
        _ => null,
      };

  void _applyPose(three.Object3D n, String act) {
    switch (act) {
      case 'sleep':
        n.scale.setValues(1.45, 0.42, 1);
        n.position.y = _noaH * 0.42 / 2;
        break;
      case 'sofa':
        n.scale.setValues(1.0, 0.76, 1);
        n.position.y = _noaH * 0.76 / 2;
        break;
      default:
        n.scale.setValues(1, 1, 1);
        n.position.y = _noaH / 2;
    }
  }

  void _resetPose(three.Object3D n) {
    n.scale.setValues(1, 1, 1);
    n.position.y = _noaH / 2;
  }

  void _updateHud(three.Object3D n) {
    final emoji = _emojiFor(_target.act);
    if (emoji == null) {
      _hud.value = null;
      return;
    }
    final v = three.Vector3(n.position.x, _noaH + 0.25, n.position.z);
    v.project(threeJs.camera);
    final sx = (v.x + 1) / 2 * threeJs.width;
    final sy = (1 - v.y) / 2 * threeJs.height;
    _hud.value = _Hud(sx, sy, emoji);
  }

  void _pickNext() {
    _Spot s;
    do {
      s = _spots[_rng.nextInt(_spots.length)];
    } while (s.x == _target.x && s.z == _target.z);
    _target = s;
  }

  void _tickNoa(double dt) {
    final n = _noa;
    if (n == null) return;

    if (_hold > 0) {
      _hold -= dt;
      _updateHud(n);
      if (_hold <= 0) {
        _resetPose(n);
        _hud.value = null;
        _pickNext();
      }
      return;
    }

    final dx = _target.x - n.position.x;
    final dz = _target.z - n.position.z;
    final dist = math.sqrt(dx * dx + dz * dz);
    if (dist < 0.05) {
      _applyPose(n, _target.act);
      _hold = switch (_target.act) {
        'sleep' => 5.5,
        'sofa' => 4.0,
        'desk' => 4.0,
        'gaze' => 3.0,
        _ => 1.8 + _rng.nextDouble() * 1.5,
      };
      _updateHud(n);
      return;
    }
    const speed = 0.75;
    final step = math.min(speed * dt, dist);
    n.position.x += dx / dist * step;
    n.position.z += dz / dist * step;
    _phase += dt * 11;
    n.position.y = _noaH / 2 + math.sin(_phase).abs() * 0.06;
    _hud.value = null;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF6EAE3),
      child: Stack(
        children: [
          threeJs.build(),
          ValueListenableBuilder<_Hud?>(
            valueListenable: _hud,
            builder: (context, h, _) {
              if (h == null) return const SizedBox.shrink();
              return Positioned(
                left: h.left - 18,
                top: h.top - 36,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(h.emoji, style: const TextStyle(fontSize: 18)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
