import '../character/character_state.dart';

/// 누가 보낸 메시지인가.
enum Sender { me, noa }

/// 화면에 박히는 말풍선 하나.
class ChatMessage {
  final Sender sender;
  final String text;
  final Emotion emotion;
  bool read; // 내 메시지의 '읽음' 여부 (카톡 1 사라짐)

  ChatMessage({
    required this.sender,
    required this.text,
    this.emotion = Emotion.idle,
    this.read = false,
  });

  bool get isMe => sender == Sender.me;

  Map<String, dynamic> toJson() => {
        'sender': sender.name,
        'text': text,
        'emotion': emotion.name,
        'read': read,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        sender: j['sender'] == 'me' ? Sender.me : Sender.noa,
        text: (j['text'] ?? '').toString(),
        emotion: emotionFromString(j['emotion'] as String?),
        read: j['read'] as bool? ?? true,
      );
}

/// LLM 출력의 버블 1개 (대화 엔진 계약: text + emotion).
class Bubble {
  final String text;
  final Emotion emotion;
  const Bubble(this.text, {this.emotion = Emotion.talking});
}

/// LLM 한 턴의 구조화 출력: bubbles[] + mood_shift + memory_note.
/// → docs/01 대화 엔진 설계서의 출력 계약.
class NoaReply {
  final List<Bubble> bubbles;
  final int moodShift; // -1 | 0 | 1
  final String? memoryNote;

  /// 노아가 고른 방 행동: sleep|desk|sofa|window|wander|come (없으면 null).
  final String? action;

  const NoaReply({
    required this.bubbles,
    this.moodShift = 0,
    this.memoryNote,
    this.action,
  });

  factory NoaReply.fromJson(Map<String, dynamic> j) {
    final raw = (j['bubbles'] as List<dynamic>? ?? const []);
    final bubbles = raw
        .map((b) {
          final m = b as Map<String, dynamic>;
          return Bubble(
            (m['text'] ?? '').toString(),
            emotion: emotionFromString(m['emotion'] as String?),
          );
        })
        .where((b) => b.text.trim().isNotEmpty)
        .toList();
    final act = (j['action'] as String?)?.trim();
    return NoaReply(
      bubbles: bubbles.isEmpty
          ? const [Bubble('…', emotion: Emotion.idle)]
          : bubbles,
      moodShift: (j['mood_shift'] as num?)?.toInt() ?? 0,
      memoryNote: j['memory_note'] as String?,
      action: (act == null || act.isEmpty || act == 'none') ? null : act,
    );
  }
}
