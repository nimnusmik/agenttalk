import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

/// 노아의 영속 상태 한 묶음 (docs/01 §6: messages + relationship_state + memories).
class NoaState {
  final List<ChatMessage> messages;
  final int moodScore;
  final List<String> memories; // 노아가 사용자에 대해 기억하는 사실들
  final int affinity; // 호감도 0~100 (누적 관계 진행)

  const NoaState({
    this.messages = const [],
    this.moodScore = 0,
    this.memories = const [],
    this.affinity = 0,
  });
}

/// 로컬 영속화 (shared_preferences). 앱을 꺼도 노아가 어제를 기억하게 한다.
/// 프로토타입용 단일 대화 슬롯. 출시 시 Supabase(messages/relationship_state/memories)로 이관.
class NoaStore {
  static const _key = 'noa_state_v1';

  Future<NoaState> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return const NoaState();
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return NoaState(
        messages: (j['messages'] as List<dynamic>? ?? const [])
            .map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
        moodScore: (j['moodScore'] as num?)?.toInt() ?? 0,
        memories: (j['memories'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        affinity: (j['affinity'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return const NoaState(); // 손상 시 깨끗이 시작
    }
  }

  Future<void> save(NoaState s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode({
        'messages': s.messages.map((m) => m.toJson()).toList(),
        'moodScore': s.moodScore,
        'memories': s.memories,
        'affinity': s.affinity,
      }),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
