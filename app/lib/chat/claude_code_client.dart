import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'noa_client.dart';

/// 방법 B 클라이언트 — 로컬 백엔드(scripts/noa_backend.py) 경유로 노아를 부른다.
///
/// 백엔드가 본인 머신의 Claude Code "구독"으로 `claude -p`를 호출하므로
/// 앱에 API 키를 들고 있을 필요가 없다. (개발/데모 전용)
///
/// 실행:
///   터미널1) python3 scripts/noa_backend.py
///   터미널2) flutter run --dart-define=NOA_BACKEND=local
///
/// ⚠️ 실기기는 localhost가 PC를 못 가리킨다 → 데스크톱/시뮬레이터/웹에서 사용.
///    (실기기 테스트 시 baseUrl 을 PC의 LAN IP로 바꿀 것)
class ClaudeCodeNoaClient implements NoaClient {
  final String baseUrl;
  ClaudeCodeNoaClient({this.baseUrl = 'http://localhost:8787'});

  @override
  Future<NoaReply> reply({
    required List<ChatMessage> history,
    required int moodScore,
    required List<String> memories,
    required int affinity,
  }) async {
    final body = jsonEncode({
      'moodScore': moodScore,
      'affinity': affinity,
      'memories': memories,
      'history': history
          .where((m) => m.text.trim().isNotEmpty)
          .map((m) => {
                'role': m.sender == Sender.me ? 'me' : 'noa',
                'text': m.text,
              })
          .toList(),
    });

    final res = await http
        .post(
          Uri.parse('$baseUrl/noa'),
          headers: {'content-type': 'application/json'},
          body: body,
        )
        .timeout(const Duration(seconds: 130));

    if (res.statusCode != 200) {
      throw Exception('노아 백엔드 ${res.statusCode}: ${res.body}');
    }

    return NoaReply.fromJson(
      jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>,
    );
  }
}
