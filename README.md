# agenttalk

> AI랑 카카오톡처럼 대화하는 도트 캐릭터 컴패니언 앱

기존 클라우드 AI 웹챗(ChatGPT/Claude)과 다르게, **진짜 카톡으로 친구와 톡하는 느낌**을 목표로 하는 모바일 앱입니다. 귀엽고(도트 픽셀아트), 통통 튀는 UX, 그리고 대화할수록 캐릭터의 상태가 *눈에 보이게* 변하는 컴패니언.

## 핵심 컨셉
- **메시징 느낌이 차대(chassis)** — 비서가 아니라 사람처럼 톡 친다 (짧은 버블 여러 개, 입력 중…, 읽음, 먼저 연락)
- **귀여움** — 도트 캐릭터(sprite-gen으로 에셋 생성) + 통통 튀는 모션·햅틱·사운드
- **살아있는 상태** — 순간 감정 + 무드 + 호감도가 시각적으로 변함
- **자유도** — 테마 꾸미기 / 멀티 캐릭터·단톡방 / 자유로운 대화

## 기술 스택
- **앱**: Flutter (iOS + Android 크로스플랫폼)
- **백엔드**: Supabase (인증 + Postgres + Realtime) + LLM 오케스트레이션 함수
- **LLM**: 프론티어 모델(프로토타입 단계), 정책·비용 윤곽 후 재검토
- **캐릭터 에셋**: [sprite-gen](https://github.com/aldegad/sprite-gen) (디자인타임 스프라이트 아틀라스 생성)

## 문서
- [00. 제품 개요](docs/00-product-overview.md)
- [01. 대화 엔진 설계서](docs/01-conversation-engine-spec.md)
- [02. 캐릭터 컨셉](docs/02-character-concepts.md)
- [03. UX·모션 아이디어](docs/03-ux-motion-ideas.md)
- [04. 캐릭터: 노아](docs/04-character-noa.md) — 첫 번째 캐릭터

## 현재 단계
기획 정리 완료 → 첫 캐릭터(노아) 확정 → 프로토타입 직전.

**다음 순서**: 노아 베이스 도트 1장 → sprite-gen 실행 → Flutter 수직 슬라이스("느낌" 검증).
