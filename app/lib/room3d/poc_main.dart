// 3D 방 POC — 독립 엔트리포인트. 기존 앱과 분리.
//   flutter build web --release -t lib/room3d/poc_main.dart
//   flutter run -d chrome -t lib/room3d/poc_main.dart
//
// Kenney Furniture Kit(CC0 glTF) 3D 가구 + 물리 그림자 + 노아 빌보드.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:three_js/three_js.dart' as three;
import 'package:three_js_advanced_loaders/three_js_advanced_loaders.dart'
    as loaders;

void main() => runApp(const Poc3DApp());

class Poc3DApp extends StatelessWidget {
  const Poc3DApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Room3DPoc(),
      );
}

class Room3DPoc extends StatefulWidget {
  const Room3DPoc({super.key});
  @override
  State<Room3DPoc> createState() => _Room3DPocState();
}

class _Room3DPocState extends State<Room3DPoc> {
  late three.ThreeJS threeJs;

  // ── 노아 행동(보행) 상태 ──
  three.Object3D? _noa; // 노아 빌보드
  double _noaH = 0.9; // 노아 높이(발=바닥 기준 y=_noaH/2)
  final math.Random _rng = math.Random();
  // 노아가 오가는 행동 지점(바닥 x,z) — 가구 앞 칸
  final List<List<double>> _spots = [
    [0.4, 1.0], // 거실 러그 가운데
    [-1.3, -0.5], // 침대 앞
    [-0.2, 0.9], // 소파 앞
    [-1.3, 1.5], // 책상 앞
    [0.6, -1.2], // 주방/창가
    [1.7, 1.1], // 화분 옆
  ];
  double _tx = -0.2, _tz = 0.9; // 현재 목표
  double _hold = 0; // 도착 후 머무는 시간(초)
  double _phase = 0; // 걸음 위상(폴짝)

  @override
  void initState() {
    threeJs = three.ThreeJS(
      onSetupComplete: () => setState(() {}),
      setup: _setup,
    );
    super.initState();
  }

  @override
  void dispose() {
    threeJs.dispose();
    three.loading.clear();
    super.dispose();
  }

  // Kenney glb 한 점 로드 → 배치 + 그림자.
  Future<void> _add(String name, double x, double z,
      {double s = 1.0, double ryDeg = 0, double y = 0}) async {
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
        }
      });
      threeJs.scene.add(o);
    } catch (_) {}
  }

  // 노아 누끼 PNG를 카메라 보는 빌보드(평면)로 방에 세운다.
  Future<void> _addNoa(double x, double z, {double height = 1.35}) async {
    _noaH = height;
    const aspect = 0.82; // w/h (noa_cut.png 대략)
    final w = height * aspect;
    // 1) 플레이스홀더 평면 먼저(텍스처 없어도 위치 보이게)
    final plane = three.Mesh(
      three.PlaneGeometry(w, height),
      three.MeshBasicMaterial.fromMap({'color': 0xFF77AA, 'side': three.DoubleSide}),
    );
    plane.position.setValues(x, height / 2, z);
    plane.rotation.y = math.pi / 4; // 아이소 카메라 보게
    threeJs.scene.add(plane);
    _noa = plane; // 행동 루프가 움직임
    // 2) 텍스처 로드되면 교체 (web의 fromAsset URL 버그 우회 → 바이트로 직접)
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
    threeJs.scene.background = three.Color.fromHex32(0xDFF1EA);

    // ── 직교 아이소 카메라 ──
    final aspect = threeJs.width / threeJs.height;
    const w = 3.15;
    threeJs.camera =
        three.OrthographicCamera(-w, w, w / aspect, -w / aspect, 0.1, 2000);
    threeJs.camera.position.setValues(60, 60, 60);
    threeJs.camera.lookAt(three.Vector3(0, 0.5, 0));

    // ── 라이팅 ──
    threeJs.scene.add(three.HemisphereLight(0xf3fbf7, 0xe6f2ec, 0.62));
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

    // ── 방: 바닥 + 두 벽 (~5m 원룸) ──
    const half = 2.6;
    final floor = three.Mesh(
      three.PlaneGeometry(half * 2, half * 2),
      three.MeshStandardMaterial.fromMap({'color': 0xBFE0D2, 'roughness': 1.0}),
    );
    floor.rotation.x = -math.pi / 2;
    floor.receiveShadow = true;
    threeJs.scene.add(floor);

    const wallH = 2.6;
    final wallMat =
        three.MeshStandardMaterial.fromMap({'color': 0xCFEADF, 'roughness': 1.0});
    final wallBack = three.Mesh(three.PlaneGeometry(half * 2, wallH), wallMat);
    wallBack.position.setValues(0, wallH / 2, -half);
    wallBack.receiveShadow = true;
    threeJs.scene.add(wallBack);
    final wallLeft = three.Mesh(three.PlaneGeometry(half * 2, wallH), wallMat);
    wallLeft.rotation.y = math.pi / 2;
    wallLeft.position.setValues(-half, wallH / 2, 0);
    wallLeft.receiveShadow = true;
    threeJs.scene.add(wallLeft);

    // ── 가구(Kenney glb) — 구역 배치 ──
    await _add('bedDouble', -1.5, -1.4, ryDeg: 0); // 수면
    await _add('kitchenSink', -0.2, -2.05, ryDeg: 0); // 주방
    await _add('kitchenFridge', 1.3, -2.05, ryDeg: 0, s: 1.1);
    await _add('desk', -2.0, 1.0, ryDeg: 90); // 작업
    await _add('chairDesk', -1.3, 1.0, ryDeg: -90);
    await _add('rugRounded', 0.3, 0.6); // 거실
    await _add('loungeSofa', -0.2, 0.1, ryDeg: 0);
    await _add('tableCoffee', 0.3, 1.2);
    await _add('lampRoundFloor', 1.6, 0.3, s: 1.25);
    await _add('pottedPlant', 2.0, 1.8, s: 1.15);

    // ── 노아 행동 루프: 지점들 사이를 걸어다니며 폴짝 + 도착 시 잠깐 머묾 ──
    threeJs.addAnimationEvent(_tickNoa);

    // ── 노아 (러그 위) — 텍스처 로드가 setup을 막지 않게 await 없이 ──
    _addNoa(0.4, 1.0, height: 0.9);
  }

  void _tickNoa(double dt) {
    final n = _noa;
    if (n == null) return;
    final baseY = _noaH / 2;
    if (_hold > 0) {
      _hold -= dt;
      n.position.y = baseY; // 머무는 동안은 가만히
      if (_hold <= 0) {
        // 다음 행동 지점 선택(현재와 다른 곳)
        List<double> s;
        do {
          s = _spots[_rng.nextInt(_spots.length)];
        } while ((s[0] - _tx).abs() < 0.01 && (s[1] - _tz).abs() < 0.01);
        _tx = s[0];
        _tz = s[1];
      }
      return;
    }
    final dx = _tx - n.position.x;
    final dz = _tz - n.position.z;
    final dist = math.sqrt(dx * dx + dz * dz);
    if (dist < 0.05) {
      _hold = 1.6 + _rng.nextDouble() * 2.8; // 1.6~4.4초 머묾
      n.position.y = baseY;
      return;
    }
    const speed = 0.75; // 유닛/초
    final step = math.min(speed * dt, dist);
    n.position.x += dx / dist * step;
    n.position.z += dz / dist * step;
    _phase += dt * 11;
    n.position.y = baseY + math.sin(_phase).abs() * 0.06; // 폴짝
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDFF1EA),
      body: threeJs.build(),
    );
  }
}
