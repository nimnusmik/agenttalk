import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../character/character_state.dart';
import 'models.dart';
import 'noa_client.dart';

/// 대화 엔진 오케스트레이터 (docs/01).
/// 사용자 전송 → 읽음 처리 → 입력중 → LLM 호출 → 버블 순차 재생 → mood 누적.
class ChatController extends ChangeNotifier {
  final NoaClient client;
  final Random _rng = Random();

  ChatController(this.client);

  final List<ChatMessage> messages = [];
  bool typing = false; // '입력 중…' 인디케이터
  Emotion avatarEmotion = Emotion.idle; // 현재 아바타 감정 (sprite 연결 지점)
  int moodScore = 0; // -3..3
  bool _busy = false;

  Future<void> send(String raw) async {
    final t = raw.trim();
    if (t.isEmpty || _busy) return;
    _busy = true;

    final userMsg = ChatMessage(sender: Sender.me, text: t, read: false);
    messages.add(userMsg);
    notifyListeners();

    // 사람다운 지연 후 '읽음' 처리 (카톡 1 사라짐)
    await Future.delayed(Duration(milliseconds: 300 + _rng.nextInt(900)));
    userMsg.read = true;
    typing = true;
    avatarEmotion = Emotion.thinking; // 응답 대기 = thinking
    notifyListeners();

    NoaReply reply;
    try {
      reply = await client.reply(
        history: List.unmodifiable(messages),
        moodScore: moodScore,
      );
    } catch (e) {
      typing = false;
      avatarEmotion = Emotion.sad;
      messages.add(ChatMessage(
        sender: Sender.noa,
        text: '(연결이 안 됐어… $e)',
        emotion: Emotion.sad,
      ));
      notifyListeners();
      _busy = false;
      return;
    }

    // 버블 순차 재생: 각 버블 전 입력중 표시 → 타이핑 시간만큼 지연 → 버블 드롭
    for (final bubble in reply.bubbles) {
      typing = true;
      avatarEmotion = Emotion.thinking;
      notifyListeners();

      final base = (400 + 45 * bubble.text.length).clamp(500, 3500).toDouble();
      final jitter = 0.8 + _rng.nextDouble() * 0.4; // ±20%
      await Future.delayed(Duration(milliseconds: (base * jitter).round()));

      typing = false;
      avatarEmotion = bubble.emotion;
      messages.add(ChatMessage(
        sender: Sender.noa,
        text: bubble.text,
        emotion: bubble.emotion,
      ));
      notifyListeners();
    }

    // mood 누적 + idle baseline 복귀
    moodScore = (moodScore + reply.moodShift).clamp(-3, 3);
    avatarEmotion = Emotion.idle;
    typing = false;
    notifyListeners();

    // TODO: reply.memoryNote 를 장기 기억(memories)으로 영속화 (docs/01)
    _busy = false;
  }
}
