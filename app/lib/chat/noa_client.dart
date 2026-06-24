import 'dart:convert';

import 'package:http/http.dart' as http;

import '../character/character_state.dart';
import 'models.dart';
import 'noa_persona.dart';

/// 노아 응답 제공자. 프로토타입은 ClaudeNoaClient(실 LLM) 또는 FakeNoaClient(오프라인).
abstract class NoaClient {
  Future<NoaReply> reply({
    required List<ChatMessage> history,
    required int moodScore,
    required List<String> memories,
    required int affinity,
  });
}

/// Claude(`claude-opus-4-8`)를 raw HTTP 로 호출. structured output 으로 버블 배열 강제.
///
/// ⚠️ 프로토타입 전용 — 앱에서 키를 직접 들고 호출한다(로컬 검증용).
/// 출시 전 반드시 백엔드(Supabase Edge Function 등)로 옮길 것. (docs/00 / docs/01)
/// ⚠️ Flutter Web 에서는 CORS + 키 노출 때문에 동작 안 함 → iOS/Android/데스크톱에서 실행.
class ClaudeNoaClient implements NoaClient {
  final String apiKey;
  final String model;
  ClaudeNoaClient({required this.apiKey, this.model = 'claude-opus-4-8'});

  // 대화 엔진 출력 계약을 JSON Schema 로 고정 (output_config.format).
  static const Map<String, dynamic> _schema = {
    'type': 'object',
    'properties': {
      'bubbles': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'text': {'type': 'string'},
            'emotion': {
              'type': 'string',
              'enum': ['idle', 'talking', 'thinking', 'happy', 'sad', 'surprised'],
            },
          },
          'required': ['text'],
          'additionalProperties': false,
        },
      },
      'mood_shift': {
        'type': 'integer',
        'enum': [-1, 0, 1],
      },
      'memory_note': {'type': 'string'},
      'action': {
        'type': 'string',
        'enum': ['none', 'sleep', 'desk', 'sofa', 'window', 'wander', 'come'],
      },
    },
    'required': ['bubbles', 'mood_shift'],
    'additionalProperties': false,
  };

  @override
  Future<NoaReply> reply({
    required List<ChatMessage> history,
    required int moodScore,
    required List<String> memories,
    required int affinity,
  }) async {
    final messages = history
        .where((m) => m.text.trim().isNotEmpty)
        .map((m) => {
              'role': m.sender == Sender.me ? 'user' : 'assistant',
              'content': m.text,
            })
        .toList();

    final res = await http.post(
      Uri.parse('https://api.anthropic.com/v1/messages'),
      headers: {
        'content-type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        // 프로토타입 전용: 브라우저(Flutter Web)에서 직접 호출 허용(CORS).
        // 출시 빌드에선 백엔드 경유로 바꾸면서 제거.
        'anthropic-dangerous-direct-browser-access': 'true',
      },
      body: jsonEncode({
        'model': model,
        'max_tokens': 1024,
        'system': buildNoaSystemPrompt(moodScore, memories, affinity),
        'messages': messages,
        'output_config': {
          'format': {'type': 'json_schema', 'schema': _schema},
        },
      }),
    );

    if (res.statusCode != 200) {
      throw Exception('Claude API ${res.statusCode}: ${res.body}');
    }

    final body = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final content = body['content'] as List<dynamic>;
    final textBlock = content.cast<Map<String, dynamic>>().firstWhere(
          (b) => b['type'] == 'text',
          orElse: () => <String, dynamic>{},
        );
    final text = textBlock['text'] as String?;
    if (text == null) throw Exception('응답에 text 블록 없음');
    // output_config.format 보장: 첫 text 블록은 유효한 JSON.
    return NoaReply.fromJson(jsonDecode(text) as Map<String, dynamic>);
  }
}

/// 키/네트워크 없이 "느낌"을 즉시 검증하는 가짜 클라이언트. 노아 톤의 캔드 응답.
class FakeNoaClient implements NoaClient {
  int _turn = 0;

  @override
  Future<NoaReply> reply({
    required List<ChatMessage> history,
    required int moodScore,
    required List<String> memories,
    required int affinity,
  }) async {
    final last = history.lastWhere(
      (m) => m.sender == Sender.me,
      orElse: () => ChatMessage(sender: Sender.me, text: ''),
    ).text;
    _turn++;

    if (last.contains('안녕') || last.contains('하이') || last.contains('ㅎㅇ')) {
      return const NoaReply(
        bubbles: [
          Bubble('왔어?', emotion: Emotion.idle),
          Bubble('딱히 기다린 건 아닌데.', emotion: Emotion.talking),
        ],
      );
    }
    if (last.contains('힘들') || last.contains('우울') || last.contains('지쳐')) {
      return const NoaReply(
        bubbles: [
          Bubble('음.', emotion: Emotion.idle),
          Bubble('…힘들었겠네.', emotion: Emotion.sad),
          Bubble('딱히 걱정하는 건 아닌데. 여기 있을게.', emotion: Emotion.sad),
        ],
        moodShift: -1,
        memoryNote: '사용자가 힘들어함',
        action: 'come', // 곁으로 옴
      );
    }
    if (last.contains('졸') ||
        last.contains('자야') ||
        last.contains('잘래') ||
        last.contains('잔다') ||
        last.contains('피곤')) {
      return const NoaReply(
        bubbles: [
          Bubble('…졸려.', emotion: Emotion.idle),
          Bubble('잘래. 깨우지 마.', emotion: Emotion.talking),
        ],
        action: 'sleep',
      );
    }
    if (last.contains('심심') || last.contains('뭐해') || last.contains('뭐 해')) {
      return const NoaReply(
        bubbles: [
          Bubble('딱히.', emotion: Emotion.idle),
          Bubble('그냥 돌아다니는 중.', emotion: Emotion.talking),
        ],
        action: 'wander',
      );
    }
    if (last.contains('!') || last.contains('ㅋㅋ') || last.contains('좋')) {
      return const NoaReply(
        bubbles: [
          Bubble('오 뭔데.', emotion: Emotion.surprised),
          Bubble('…뭐. 잘됐네.', emotion: Emotion.happy),
        ],
        moodShift: 1,
      );
    }
    const pool = [
      [
        Bubble('왔어?', emotion: Emotion.idle),
        Bubble('딱히 기다린 건 아닌데.', emotion: Emotion.talking),
      ],
      [
        Bubble('그래서?', emotion: Emotion.talking),
        Bubble('별로 안 궁금한데. …말해봐.', emotion: Emotion.idle),
      ],
      [
        Bubble('흐음.', emotion: Emotion.thinking),
        Bubble('뭐, 그럴 수도 있지.', emotion: Emotion.talking),
      ],
    ];
    return NoaReply(bubbles: pool[_turn % pool.length], moodShift: 0);
  }
}
