# agenttalk Flutter 앱

> 현재 단계: **대화 느낌 슬라이스**(`lib/chat/`) + 캐릭터 렌더링 골격(`lib/character/`). `main.dart`/`pubspec.yaml` 포함 — 실행 가능한 셸.
> ⚠️ 이 환경에 Flutter SDK 가 없어 **컴파일 검증은 미실시**. 스키마 정확성 기준 작성 — 아래 실행법으로 `flutter analyze`/`flutter run` 검증할 것.

## 실행법
```bash
cd app
flutter create .          # 플랫폼 폴더(ios/android/...) 생성, 기존 lib/ 유지
flutter pub get
flutter run               # 키 없이 FakeNoaClient 로 즉시 "느낌" 검증
# 실제 노아(Claude):
flutter run --dart-define=ANTHROPIC_API_KEY=sk-ant-...
```
- **키 없으면 FakeNoaClient** — 노아 톤 캔드 응답으로 버블/입력중/읽음/통통 흐름이 바로 돈다.
- ⚠️ **Web 으로 실행 금지** (real Claude 시): CORS + 키 노출. iOS/Android/데스크톱에서 실행.
- ⚠️ 앱이 LLM 키를 직접 들고 호출하는 건 **프로토타입 한정**. 출시 전 백엔드로 이동([docs/00](../docs/00-product-overview.md)/[docs/01](../docs/01-conversation-engine-spec.md)).

## 구성

### `lib/chat/` — 대화 느낌 슬라이스 (실행 진입점)
- `models.dart` — `ChatMessage`/`Bubble`/`NoaReply`(bubbles+mood_shift+memory_note)
- `noa_persona.dart` — 노아(딸기 데드팬 고양이) 시스템 프롬프트, mood 반영([docs/04](../docs/04-character-noa.md))
- `noa_client.dart` — `ClaudeNoaClient`(raw HTTP, `claude-opus-4-8`, structured output) + `FakeNoaClient`(오프라인)
- `chat_controller.dart` — 오케스트레이터: 읽음→입력중→LLM→버블 순차 재생→mood 누적([docs/01](../docs/01-conversation-engine-spec.md))
- `chat_screen.dart` — 카톡 UI: 말풍선·입력중·읽음·말풍선 스프링 등장·전송 squash. 상단에 현재 감정/무드 표기

### `lib/character/` — 캐릭터 렌더러 골격 (스프라이트 준비 후 결합)
- `sprite_manifest.dart` / `character_state.dart` / `character_view.dart` / `character_loader.dart` / `character_demo.dart`
- sprite-gen 아틀라스가 나오면 `assets/sprites/noa/` 에 넣고 `CharacterView` 를 채팅 상단 아바타로 교체([docs/05](../docs/05-sprite-gen-integration.md))

## 의존성
- `http` (Claude raw HTTP). 그 외 `material`/`scheduler`/`services`/`dart:ui` 는 SDK 내장.

## 알려진 한계 (슬라이스 단계)
- 아바타는 임시 🍓 이모지 + 감정/무드 텍스트. 실제 도트 캐릭터는 `CharacterView` 연결 대기(스프라이트 필요).
- 대화 이력은 메모리에만(영속화·계정 없음). `memory_note` 영속화는 TODO.
- 스티커·먼저 연락(푸시)·단톡방 미구현(스키마만 docs 에 설계).

## 다음
- 노아 베이스 도트 → sprite-gen → `CharacterView` 결합(상단 아바타가 `thinking`/`talk`/감정 재생)
- 통통 4종 중 햅틱/사운드·레벨업 하트팝 추가 → [docs/03](../docs/03-ux-motion-ideas.md)
- 백엔드(Supabase) + LLM 오케스트레이션 함수로 키 이동
