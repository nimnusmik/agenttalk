# 대화 엔진 설계서 (Conversation Engine Spec) v0.1

> 프로토타입 직전 설계서. AI 카톡형 도트 컴패니언 앱.
> 스택: Flutter + Supabase + 프론티어 LLM / 캐릭터 에셋: sprite-gen(디자인타임).

---

## 0. 핵심 원칙 (북극성)

1. **AI 비서가 아니라 사람처럼 톡 친다.** 긴 블록 X, 마크다운 X, "도와드릴게요" X.
2. **대화할 때마다 캐릭터 상태가 *눈에 보이게* 변한다.** (이 문서의 1순위 요구사항)
3. **메시징 느낌이 차대(chassis)다.** 페르소나·모드(힐링/수다/응원)는 그 위에 올라탄다.

---

## 1. 상태 모델 (State Model) — 엔진의 심장

"대화할 때마다 얘가 변하는 게 보인다"를 **3개 층위**로 구현한다. 각 층위는 갱신 주기와 시각 표현이 다르다.

### 1-A. 순간 감정 (Transient Emotion) — 메시지 단위
- **역할**: 지금 이 메시지에 대한 즉각 반응.
- **값(enum)**: `idle` · `talking` · `thinking` · `happy` · `sad` · `surprised`
  - 확장(2차): `laugh` · `love` · `angry`(삐짐) · `sleep` · `wave`
- **수명**: 해당 버블에서 재생 → 몇 초 뒤 **현재 무드 baseline으로 복귀**.
- **출처**: LLM이 버블마다 태깅.
- **시각**: 스프라이트 애니메이션 *재생*(반응 모션).

### 1-B. 지속 무드 (Mood) — 대화 흐름 단위
- **역할**: 이번 대화의 누적 기분. idle일 때조차 "얘 지금 기분 어떤지" 보이게.
- **값**: 정수 `-3 ~ +3` (다운 ↔ 신남). 중립으로 천천히 감쇠(decay).
- **갱신**: 매 턴 LLM이 `mood_shift`(-1|0|+1)를 평가 → 엔진이 누적·clamp·decay.
- **시각**: **idle baseline 스프라이트가 바뀐다** + 보조(눈빛/입꼬리, 배경 tint).
  - 예: mood ≤ -2 → 시무룩 idle / -1~+1 → 평온 idle / ≥ +2 → 들뜬 idle.

### 1-C. 관계/호감도 (Affinity) — 누적 진행
- **역할**: 장기 진행. "대화할수록 얘가 *점점* 달라진다"는 환장 포인트.
- **값**: 카운터 `0 ~ 100` (or 레벨).
- **갱신**: 긍정 상호작용·꾸준함·메시지 수에 따라 천천히 증가.
- **시각/언락**: 표정 레퍼토리 확장, **거리감 변화**(초기 시크 → 친해지면 다가옴), 액세서리·배경, **말투 전환(존댓→반말)**, 새 스티커, "먼저 연락" 빈도↑.

### 1-D. 컨디션/에너지 (Energy) — 시간 기반 (선택)
- 심야 → `sleep` 톤, 오래 안 보면 시무룩, 아침 인사.
- `last_interaction_at`과 현재 시각으로 계산.

> **합산 결과**: 순간 감정(반응) + 무드(베이스라인) + 호감도(누적 변화) + 에너지(시간) 이 겹쳐서, 사용자는 "톡 칠 때마다 얘가 반응하고, 오늘 기분이 보이고, 사귈수록 변한다"를 동시에 체감한다.

---

## 2. 버블 프로토콜 (LLM 출력 계약)

LLM은 한 덩어리가 아니라 **버블 배열 + 상태 신호**를 낸다(structured output 강제).

```json
{
  "bubbles": [
    { "type": "text",    "text": "헐 진짜?",            "emotion": "surprised" },
    { "type": "text",    "text": "그래서 어떻게 됐는데ㅋㅋ", "emotion": "happy" },
    { "type": "sticker", "sticker": "happy_jump",        "emotion": "happy" }
  ],
  "mood_shift": 1,
  "memory_note": "사용자가 오늘 면접 봄 (결과 대기 중)"
}
```

- `bubbles[]`: 1~5개 권장. `type` = `text` | `sticker`.
- `emotion`: 순간 감정 enum. 버블별로 지정 → 해당 버블 재생 시 스프라이트.
- `mood_shift`: -1|0|+1. 엔진이 무드 누적에 사용.
- `memory_note`(선택): 장기 기억에 저장할 사실 한 줄.
- **타이밍은 출력에 없다 — 앱이 계산**(토큰 절약).

---

## 3. 타이밍 & 인디케이터 (앱 계산)

- **입력 지연**: `delay = clamp(400 + 45*len(text), 500, 3500)ms` + jitter(±20%).
- **버블 사이**: 지연 동안 `입력 중…` 표시 → 끝나면 버블 톡 떨어짐.
- **읽음 처리**: 유저 메시지 도착 후 사람다운 지연(300~1200ms) 뒤 `읽음`/`1` 사라짐 → 그다음 `입력 중…` 시작. (읽씹 연출은 밀당 캐릭터 옵션)
- **응답 대기**: LLM 호출 동안 `입력 중…` + 아바타 `thinking`.
- ⚠️ 글자 단위 토큰 스트리밍 아님. **버블 단위**가 카톡 느낌에 정확.

---

## 4. 한 턴 처리 흐름 (Orchestration)

```
1) 유저 전송 → messages 저장(sent)
2) (사람다운 지연) 읽음 표시 + 아바타 thinking + 입력중 ON
3) 백엔드 프롬프트 조립:
     시스템(페르소나 + 비서박멸 철칙)
   + 현재 상태(mood, affinity, energy, 시간대)
   + 최근 대화 N턴
   + 장기 기억(memories)
   → LLM 호출(structured: bubbles[] + mood_shift + memory_note)
4) 엔진 상태 갱신:
     mood   = clamp(mood + mood_shift, -3, +3) 후 중립 방향 decay
     affinity += f(긍정도, 메시지수, 꾸준함)
     energy   = f(시간대, last_interaction_at)
     memory_note 있으면 memories에 insert
   → relationship_state 영속화
5) 버블 순차 렌더: 입력중 → 버블(+emotion 재생) 반복
   → 마지막에 아바타를 새 무드 baseline으로 settle
6) messages + state 영속화
```

---

## 5. 시각 렌더링 (sprite-gen 연결)

- sprite-gen 산출물: 스프라이트 시트 PNG + `manifest.json`(frame_layout).
- 감정 enum ↔ manifest의 액션(row) 1:1 매핑.
- 같은 시트가 **두 용도**: (1) 대화 중 아바타 감정 재생, (2) `sticker` 버블로 전송(카톡 이모티콘).
- 무드 baseline = idle 계열 스프라이트를 mood 버킷별로 준비(시무룩/평온/들뜸 idle).
- Flutter: manifest를 읽어 프레임 재생하는 `CharacterView` 위젯 1개로 추상화.

---

## 6. 데이터 모델 (Supabase / Postgres 초안)

- `users` — 계정.
- `characters` — 페르소나 설정, 스프라이트 시트/매니페스트 ref, 스티커 셋.
- `conversations` — (user_id, character_id).
- `messages` — (conversation_id, sender, type[text|sticker], content, emotion, created_at, read_at).
- `relationship_state` — (user_id, character_id, mood int, affinity int, energy, last_interaction_at, unlocked jsonb). **상태 모델의 영속 테이블.**
- `memories` — (user_id, character_id, note, created_at). 장기 기억.

---

## 7. 시스템 프롬프트 계약 (비서 박멸 + 상태 출력)

- 짧은 메시지 여러 개로. 마크다운·불릿·헤더·번호목록 **금지**.
- "도와드릴게요/요약하면/결론적으로" 류 비서체 **금지**. 반말·줄임말·이모티콘·가벼운 오타 허용.
- 모르면 모른다고, 되물어도 되고, 가끔 먼저 화제 던짐. 답을 "완성"하려 하지 말 것.
- **반드시** `bubbles[] + mood_shift + (필요시) memory_note` 형식으로 출력.
- **현재 상태를 톤에 반영**: 호감도 낮으면 거리감, 높으면 친근/반말. 무드 낮으면 가라앉은 톤.

---

## 8. 프로토타입(MVP) 범위

**만든다:**
- 캐릭터 1명(예: 노아). 감정 6종. 텍스트 버블 + 입력중 + 읽음. 버블 타이밍.
- 무드(-3~+3) → idle baseline 3종 전환(상태 변화 *눈에 보임* 증명).
- 호감도 카운터 + 가시적 마일스톤 1개(예: 시크→살짝 풀림)로 "점점 변한다" 느낌 검증.

**미룬다(스키마는 미리 수용):**
- 호감도 풀 언락 트리, 스티커 전송, 먼저 연락(푸시), 멀티 캐릭터, 단톡방.

---

## 9. 미해결 결정 (Open Questions)

1. 무드 시각 표현: 별도 idle 스프라이트 vs 컬러/배경 tint vs 둘 다?
2. 호감도 증가 곡선: 너무 빠르면 가벼움, 느리면 지루 — 초기 기울기?
3. `mood_shift` LLM 자가평가 신뢰도 — 초기 LLM, 후에 룰/감성분석 보강?
4. 읽씹(지연 읽음) 연출을 캐릭터별 매력으로 넣을지(녹스 등 밀당형)?
```
