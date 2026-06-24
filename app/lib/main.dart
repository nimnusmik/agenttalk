import 'package:flutter/material.dart';

import 'chat/chat_controller.dart';
import 'chat/claude_code_client.dart';
import 'chat/noa_client.dart';
import 'chat/noa_store.dart';
import 'home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 노아 백엔드 선택 (우선순위):
  //  1) NOA_BACKEND=local → 방법 B: 로컬 백엔드(구독, 키 불필요)
  //       터미널1) python3 scripts/noa_backend.py
  //       터미널2) flutter run --dart-define=NOA_BACKEND=local
  //  2) ANTHROPIC_API_KEY 있음 → 방법 A: Claude API 직접 호출
  //  3) 둘 다 없음 → FakeNoaClient (오프라인 캔드 응답)
  const backend = String.fromEnvironment('NOA_BACKEND');
  const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
  final NoaClient client = backend == 'local'
      ? ClaudeCodeNoaClient()
      : apiKey.isEmpty
          ? FakeNoaClient()
          : ClaudeNoaClient(apiKey: apiKey);

  // 로컬 영속 상태 복원 → 노아가 어제 대화·기분·기억을 그대로 이어간다.
  final store = NoaStore();
  final controller = ChatController(client, store: store)
    ..restore(await store.load());

  runApp(AgentTalkApp(controller: controller));
}

class AgentTalkApp extends StatelessWidget {
  final ChatController controller;
  const AgentTalkApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'agenttalk',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFFFEE500),
        fontFamily: 'Apple SD Gothic Neo',
      ),
      home: HomeShell(controller: controller),
    );
  }
}
