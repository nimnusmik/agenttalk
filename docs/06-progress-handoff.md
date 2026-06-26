# 06 · 진행 상황 & 핸드오프 (2026-06-26)

다른 노트북에서 이어서 작업하기 위한 작업 기록. 아키텍처·실행법·보안·다음 할 일을 한 장에 정리한다.

## 한 줄 요약

AI 카톡형 컴패니언 **노아**(딸기 옷 데드팬 고양이). 하단 탭 **[방]/[톡]**.
- **방**: 3D 파니룸 — 노아가 가구 사이를 돌아다니고, 대화 맥락에 따라 행동(수면/소파/책상/응시).
- **톡**: 카톡형 말풍선 채팅.
- 대화·기분·기억·호감도는 로컬에 **영속**되어 다음에 켜도 이어진다.

## 현재 아키텍처

```
app/lib/
  main.dart            진입점 — 백엔드 선택 + NoaStore 복원 → HomeShell
  home_shell.dart      하단 탭 셸: [방]=Room3DView / [톡]=ChatScreen (ChatController 공유)
  chat/
    chat_controller.dart  대화 오케스트레이터(전송→읽음→입력중→버블 재생→mood/기억)
    chat_screen.dart      카톡형 버블 UI
    models.dart           ChatMessage / Bubble / NoaReply
    noa_persona.dart      노아 시스템 프롬프트(데드팬 고양이)
    noa_client.dart       ClaudeNoaClient(API 직접) + FakeNoaClient(오프라인)
    claude_code_client.dart ClaudeCodeNoaClient(로컬 백엔드=구독, 키 불필요)
    noa_store.dart        NoaStore — 대화/기분/기억/호감도 로컬 저장·복원
  room/                  2D 아이소 방(폴백): iso.dart(좌표) iso_room.dart(렌더)
                         furniture.dart(가구) room_store.dart(배치 영속) sprite_sizes.dart
  room3d/
    room3d_view.dart     ★ 본체: three_js 직교 아이소 카메라 + Kenney CC0 glTF 가구
                         + 물리 그림자 + 노아 빌보드(누끼) 보행 행동 루프
    poc_main.dart        3D 방 단독 실행 엔트리(개발/검증용)
  character/             sprite-gen 연동 파이프라인(현재는 정적 누끼 사용)
app/assets/character/    noa_cut.png(누끼·투명), noa.jpg
scripts/                 noa_backend.py(로컬 백엔드), cutout_*.py, gen_*_mockup.py 등
docs/00-05               기획서(제품/대화엔진/캐릭터/UX모션/노아/sprite-gen)
```

방 렌더는 `home_shell.dart`의 `kUse3DRoom`(기본 true=3D, false=2D 아이소 폴백)로 전환.

## 노아 두뇌(백엔드) 3종 — `main.dart`에서 자동 선택

| 우선순위 | 조건 | 클라이언트 | 비고 |
|---|---|---|---|
| 1 | `NOA_BACKEND=local` | `ClaudeCodeNoaClient` | **권장**. 로컬 `scripts/noa_backend.py`(구독 기반, API 키 불필요) |
| 2 | `ANTHROPIC_API_KEY` 존재 | `ClaudeNoaClient` | Claude API 직접 호출(`claude-opus-4-8`) |
| 3 | 둘 다 없음 | `FakeNoaClient` | 오프라인 캔드 응답(데모용) |

## 새 노트북에서 시작하기

```bash
git clone https://github.com/nimnusmik/agenttalk.git
cd agenttalk/app
flutter --version          # Flutter 3.22+ 필요(검증 환경 3.44.2)
flutter pub get

# 실행 — 택1
flutter run -d chrome                                   # (A) 오프라인 데모(FakeNoaClient)
# (B) 구독 기반 진짜 노아: 터미널1에서 백엔드 먼저
python3 scripts/noa_backend.py
flutter run -d chrome --dart-define=NOA_BACKEND=local   #     터미널2
# (C) API 키 직접
flutter run -d chrome --dart-define=ANTHROPIC_API_KEY=sk-ant-...
```

iOS/Android는 `flutter run -d <device>`. 3D 방(three_js)은 웹·모바일 모두 동작.

## 보안 (반드시 지킬 것)

- **API 키·구독 토큰·DB 접속정보·SSH 정보는 절대 커밋 금지.** 키는 `--dart-define` 또는 셸 환경변수로 **로컬에서만** 주입한다(소스에 `String.fromEnvironment`로만 읽음).
- `.claude/`(로컬 Claude Code 상태), `app/build/`, `app/.dart_tool/`는 git에서 무시됨.

## 현재 WIP / 다음 할 일

- ✅ 방금 커밋: 3D 방을 재사용 위젯 `Room3DView`로 분리(`poc_main`에서), 셸에 연결.
- ▢ 대화 `action` ↔ 3D 노아 행동 연동 심화(현재 `Room3DView`에 `controller` 훅 자리만 있음).
- ▢ 3D 가구 배치 에디터(현재 2D `room_store` 드래그 에디터를 3D로 확장).
- ▢ 멀티 캐릭터 / 단톡방, 스프라이트 표정 애니메이션(sprite-gen 파이프라인).
- 1차 오픈 목표를 최상위 제약으로 유지.
