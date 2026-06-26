// 3D 방 단독 실행 엔트리포인트(개발/검증용).
//   flutter build web --release -t lib/room3d/poc_main.dart
//   flutter run -d chrome -t lib/room3d/poc_main.dart
// 실제 방 위젯은 room3d_view.dart 의 Room3DView. 본 앱은 home_shell 에서 사용.
import 'package:flutter/material.dart';

import 'room3d_view.dart';

void main() => runApp(const Poc3DApp());

class Poc3DApp extends StatelessWidget {
  const Poc3DApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Room3DView()),
      );
}
