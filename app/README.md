# agenttalk Flutter 앱

> 현재 단계: **캐릭터 렌더링 골격**(`lib/character/`)만 선반영. Flutter 프로젝트 셸은 아직 미생성.
> ⚠️ 이 환경에 Flutter SDK 가 없어 **컴파일 검증은 미실시**. 스키마 정확성 기준으로 작성됨 — 프로젝트에 넣고 `flutter pub get` → `flutter analyze` 로 검증할 것.

## 구성 (`lib/character/`)
- `sprite_manifest.dart` — sprite-gen `manifest.json` 모델(frame_layout/animation). [docs/05](../docs/05-sprite-gen-integration.md) 스키마와 동기화
- `character_state.dart` — emotion(논리) ↔ sprite state 매핑, mood 버킷(-3..+3 → down/neutral/up)
- `character_view.dart` — 아틀라스 **rect 샘플링** + 프레임 재생 위젯. 픽셀아트 nearest-neighbor, transient→idle 복귀, mood 배경 tint
- `character_loader.dart` — assets 에서 manifest + 아틀라스 로드
- `character_demo.dart` — 감정 칩 + 무드 슬라이더 수동 테스트 화면

## 붙이는 법
1. Flutter 프로젝트 생성 (app/ 에서):
   ```bash
   flutter create .
   ```
   생성된 `lib/` 위에 `lib/character/` 가 그대로 얹힌다.
2. sprite-gen 산출물을 assets 로 복사:
   ```text
   assets/sprites/noa/manifest.json
   assets/sprites/noa/sprite-sheet-alpha.png
   ```
3. `pubspec.yaml`:
   ```yaml
   flutter:
     assets:
       - assets/sprites/noa/manifest.json
       - assets/sprites/noa/sprite-sheet-alpha.png
   ```
4. `main.dart` 에서 `CharacterDemoScreen()` 을 home 으로 띄워 감정/무드 전환 검증.

## 의존성
외부 패키지 **0** — `material`, `scheduler`, `services`, `dart:ui` 모두 Flutter SDK 내장.

## 알려진 한계 (골격 단계)
- 같은 emotion 을 연속으로 세팅하면 재생이 다시 트리거되지 않음(버블마다 동일 감정 반복 시). 필요 시 trigger 카운터 추가.
- transient 복귀는 단순 1회 재생 후 idle. 더 정교한 큐(여러 감정 연속 재생)는 대화 엔진 쪽에서 큐잉 예정([docs/01](../docs/01-conversation-engine-spec.md)).

## 다음
- 통통 4종(말풍선 스프링·전송 squash·햅틱/사운드·레벨업 하트팝) → [docs/03](../docs/03-ux-motion-ideas.md)
- 채팅 화면에 CharacterView 를 상단 아바타로 + `thinking`(응답 대기)·`talk`(스트리밍) 연동 → [docs/01](../docs/01-conversation-engine-spec.md)
