import 'package:flutter/material.dart';

import 'chat/chat_controller.dart';
import 'chat/chat_screen.dart';
import 'chat/noa_client.dart';

void main() {
  // 키가 없으면 FakeNoaClient 로 즉시 실행(오프라인 느낌 검증).
  // 실제 노아(Claude): flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-...
  const apiKey = String.fromEnvironment('ANTHROPIC_API_KEY');
  final NoaClient client =
      apiKey.isEmpty ? FakeNoaClient() : ClaudeNoaClient(apiKey: apiKey);
  runApp(AgentTalkApp(controller: ChatController(client)));
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
      home: ChatScreen(controller: controller),
    );
  }
}
