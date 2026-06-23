// 대화 엔진 emotion(논리 감정) ↔ sprite-gen state(시각) 매핑.
// 설계서 docs/01(대화 엔진)·04(노아)·05(sprite-gen 연동) 와 동기화.

enum Emotion { idle, talking, thinking, happy, sad, surprised }

enum Mood { down, neutral, up }

/// mood 점수(-3..+3) → 3단계 baseline 버킷.
Mood moodFromScore(int score) {
  if (score <= -1) return Mood.down;
  if (score >= 1) return Mood.up;
  return Mood.neutral;
}

/// emotion=idle 일 때 mood 버킷이 고르는 idle baseline sprite state.
/// (idle_down/idle_up 은 sprite-gen Wave 2 상태 — 없으면 CharacterView 가 'idle' 로 폴백)
String idleStateForMood(Mood mood) {
  switch (mood) {
    case Mood.down:
      return 'idle_down';
    case Mood.up:
      return 'idle_up';
    case Mood.neutral:
      return 'idle';
  }
}

/// 논리 emotion + 현재 mood → sprite-gen state 이름.
String spriteStateFor(Emotion emotion, Mood mood) {
  switch (emotion) {
    case Emotion.idle:
      return idleStateForMood(mood);
    case Emotion.talking:
      return 'talk'; // sprite-gen 관례 명칭
    case Emotion.thinking:
      return 'thinking';
    case Emotion.happy:
      return 'happy';
    case Emotion.sad:
      return 'sad';
    case Emotion.surprised:
      return 'surprised';
  }
}

/// 1회 재생 후 idle baseline 으로 복귀하는 transient(반응) 감정인지.
/// 실제 loop 여부는 manifest 의 animation.loop 가 최종 권위 — 이건 의도 힌트.
bool isTransientEmotion(Emotion e) =>
    e == Emotion.happy || e == Emotion.sad || e == Emotion.surprised;

/// LLM 버블의 emotion 문자열 → enum.
Emotion emotionFromString(String? s) {
  switch (s) {
    case 'talk':
    case 'talking':
      return Emotion.talking;
    case 'thinking':
      return Emotion.thinking;
    case 'happy':
      return Emotion.happy;
    case 'sad':
      return Emotion.sad;
    case 'surprised':
      return Emotion.surprised;
    case 'idle':
    default:
      return Emotion.idle;
  }
}

/// 관계/호감도 (Affinity 0~100) → 3단계 관계 레벨 (docs/01 §1-C).
/// "대화할수록 얘가 점점 달라진다"의 누적 진행 축.
enum Bond { distant, warming, close }

Bond bondFromAffinity(int affinity) {
  if (affinity >= 70) return Bond.close;
  if (affinity >= 30) return Bond.warming;
  return Bond.distant;
}
