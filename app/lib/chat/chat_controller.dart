import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../character/character_state.dart';
import 'models.dart';
import 'noa_client.dart';
import 'noa_store.dart';

/// 대화 엔진 오케스트레이터 (docs/01).
/// 사용자 전송 → 읽음 처리 → 입력중 → LLM 호출 → 버블 순차 재생 → mood 누적.
class ChatController extends ChangeNotifier {
  final NoaClient client;
  final NoaStore? store; // 로컬 영속화(있으면 매 턴 저장)
  final Random _rng = Random();

  ChatController(this.client, {this.store});

  final List<ChatMessage> messages = [];
  final List<String> memories = []; // 노아의 장기 기억 (사용자에 대한 사실)
  int affinity = 0; // 호감도 0~100 (사귈수록 누적 → 말투·행동 변화)
  bool typing = false; // '입력 중…' 인디케이터
  Emotion avatarEmotion = Emotion.idle; // 현재 아바타 감정 (sprite 연결 지점)
  int moodScore = 0; // -3..3
  bool _busy = false;

  static const int _maxMemories = 40; // 프롬프트 비대화 방지 상한

  /// 저장된 상태 복원(앱 시작 시 1회). 기존 대화가 있으면 첫인사는 건너뛴다.
  void restore(NoaState s) {
    messages
      ..clear()
      ..addAll(s.messages);
    memories
      ..clear()
      ..addAll(s.memories);
    moodScore = s.moodScore;
    affinity = s.affinity;
    if (messages.isNotEmpty) _greeted = true;
    notifyListeners();
  }

  void _persist() {
    store?.save(NoaState(
      messages: List.unmodifiable(messages),
      moodScore: moodScore,
      memories: List.unmodifiable(memories),
      affinity: affinity,
    ));
  }

  /// 입력창 포커스 등 "노아야 봐줘" 신호. 방 위젯이 tick 증가를 감지해 쳐다본다.
  int attentionTick = 0;
  void lookAtMe() {
    attentionTick++;
    notifyListeners();
  }

  bool _greeted = false;

  /// 진입 시 노아가 먼저 한마디(첫인사). LLM 없이 정해진 데드팬 인사.
  Future<void> openingGreeting() async {
    if (_greeted || messages.isNotEmpty || _busy) return;
    _greeted = true;
    _busy = true;
    typing = true;
    avatarEmotion = Emotion.thinking;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 1500));
    typing = false;
    avatarEmotion = Emotion.idle;
    messages.add(ChatMessage(
      sender: Sender.noa,
      text: '왔어? …딱히 기다린 건 아닌데.',
      emotion: Emotion.idle,
    ));
    notifyListeners();
    _persist();
    _busy = false;
  }

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
        memories: List.unmodifiable(memories),
        affinity: affinity,
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
      _persist();
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
    // 호감도 누적: 매 턴 천천히 오름(긍정 상호작용은 가산). 친구는 힘든 날도 곁이라 깎진 않음.
    // 증가 곡선은 튜닝 포인트(docs/01 §9): 현재 +2/턴, 긍정 시 +2.
    affinity = (affinity + 2 + (reply.moodShift > 0 ? 2 : 0)).clamp(0, 100);
    avatarEmotion = Emotion.idle;
    typing = false;
    notifyListeners();

    // 장기 기억: 노아가 뽑은 memory_note 누적 (직전과 중복 제외, 상한 관리)
    final note = reply.memoryNote?.trim();
    if (note != null &&
        note.isNotEmpty &&
        (memories.isEmpty || memories.last != note)) {
      memories.add(note);
      if (memories.length > _maxMemories) {
        memories.removeRange(0, memories.length - _maxMemories);
      }
    }
    _persist();
    _busy = false;
  }
}
