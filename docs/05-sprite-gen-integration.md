# sprite-gen 연동 (Sprite Pipeline Integration)

> sprite-gen **v1.7.0** 실제 스키마·스크립트 분석(2026-06-19) 기반.
> 입력 = `states{}` 객체 `sprite-request.json`(SSoT) / 출력 = `sprite-sheet-alpha.png` + `manifest.json`(frame_layout).
> ✅ 노아 요청 파일([`sprites/noa/noa.request.json`](../sprites/noa/noa.request.json))은 `prepare_sprite_run.py`로 **검증 완료**(8 states 전부 prompts/layout-guides 생성, `ok:true`).

---

## 0. ⚠️ Base Lock Gate (BLOCKING) — 베이스 도트 작화 브리프
sprite-gen은 베이스 idle을 "락"하기 전엔 파이프라인을 시작하지 않는다. 약한 베이스가 모든 state row의 비율·스타일·정체성을 오염시키기 때문(드리프트는 row가 늘수록 누적). **노아 베이스 한 장은 아래를 *모두* 만족해야 락된다. 못 하면 다시 그린다 — "일단 이걸로"는 불가:**

- [ ] 전신, 잘림 없음 (머리~발끝이 프레임 안)
- [ ] **최종 스타일·비율이 이미 정확** — 도트(픽셀) 룩, 1~2px 두꺼운 외곽선, 2.5등신 SD/치비, 제한 팔레트, 평면 셀셰이딩(하이라이트 1 + 그림자 1단). *나중에 고치기 금지 — 베이스가 타겟을 정의한다.*
- [ ] 진저/크림 고양이 정체성 고정 (주황 줄무늬·크고 둥근 눈·흰 가슴/배·소품)
- [ ] 단일 idle 포즈, 정면 카메라 응시, 작게 봐도 읽히는 실루엣
- [ ] 배경 = 단색 깨끗한 키잉 가능 fill. **흰/검 배경·그림자·글로우 금지**
- [ ] 런타임 작은 크기에서 사라질 디테일 없음 (복잡한 소형 액세서리 X)

→ **이 체크리스트가 외주/직접 작화 브리프다.** 락 통과(`y`) 전까지 `prepare_sprite_run.py` 실행 금지.

---

## 1. 입력: `states{}` 객체 (초안의 `actions[]` 배열 아님)
`prepare_sprite_run.py`가 요청 파일에서 읽는 건 `states`·`cell`·`style`·`motion_phase_guides`뿐(나머지 envelope는 CLI 인자로 생성). 노아 feed-ready 파일: [`sprites/noa/noa.request.json`](../sprites/noa/noa.request.json).

상태 전체 8개 — **2 wave로 생성**:
- **Wave 1 (핵심 느낌, 6)**: `idle` · `talk` · `thinking` · `happy` · `sad` · `surprised`
- **Wave 2 (무드 baseline, 2)**: `idle_down` · `idle_up`

규칙(sprite-gen 가이드):
- **frame 수**: 4 기본 / 5는 *복귀 프레임* 있는 비루프 제스처(예: surprised) / 6 보수적 상한 / **9·12 금지**(추출 실패·중복 프레임↑)
- **loop**: 지속 상태 `idle`·`talk`·`thinking` = `true` / 1회 반응 `happy`·`sad`·`surprised` = `false`
- 감정 상태(happy/sad/surprised/thinking)는 sprite-gen "stable default"가 아닌 custom → **state별 모션 QA 필수**

---

## 2. 의존성 / 환경
- **`kuma:image-gen` 스킬 필요** — sprite-gen은 각 state row를 *base + layout guide*로 image-gen 생성한다. 이 환경엔 미설치일 수 있음.
  - **옵션 A**: `kuma:image-gen` 설치 → row 자동 생성
  - **옵션 B**: 각 `raw/<state>.png` strip을 직접 작화해 넣고 extract부터 진행 (베이스만 외주 시 row는 image-gen이 자연스러움)
- **Pillow** 필요 (`python3 -m pip install pillow`). venv 권장.
- 로컬 클론: `/Users/bkan/sprite-gen` (skill 설치 시 정본 경로는 `$ALEX_EXTENSIONS_DIR/sprite-gen`)
- **크로마키**: 진저/크림(따뜻한 주황) 고양이 → **green 키 권장**. warm/red 계열은 magenta-adjacent(둘 다 high R)라 magenta 키를 쓰면 주황이 먹혀 near-black 됨(SKILL.md 명시). 추출 후 주황이 살아남았는지 반드시 확인. *(베이스 없이 auto는 magenta로 fallback)*

---

## 3. 명령어 시퀀스
```bash
SG=/Users/bkan/sprite-gen
OUT=/Users/bkan/agenttalk/assets/generated/sprites/noa
REQ=/Users/bkan/agenttalk/sprites/noa/noa.request.json

# 0) Base Lock Gate 통과(y) 후. noa-base.png = 락된 베이스 idle (절대경로)
python3 "$SG/scripts/prepare_sprite_run.py" \
  --out-dir "$OUT" --character-id noa \
  --base-image /abs/path/to/noa-base.png \
  --description "cute aloof/tsundere ginger/cream cat with big round eyes; 2.5-head pixel mascot" \
  --request "$REQ" \
  --chroma-key "#00FF00" --cell-size 256 --safe-margin 24 --force   # 진저=warm → green 키 (auto도 가능, 추출 후 색 확인)
#  → sprite-request.json, base-source.png, references/layout-guides/<state>.png,
#    prompts/<state>.txt, raw/, frames/ 생성

# 1) state별 row 1장씩 생성 (kuma:image-gen, prompts/<state>.txt 사용) → raw/<state>.png 저장
#    (또는 raw/<state>.png 직접 작화)

# 2) 프레임 추출 (크로마 제거 + connected-component)
python3 "$SG/scripts/extract_sprite_row_frames.py" --run-dir "$OUT"

# 3) (선택) 큐레이션 웹뷰 — 프레임 선택/회전/스케일 비파괴 보정 (사람 판단 단계)
python3 "$SG/scripts/serve_curation.py" --run-dir "$OUT" --lang ko &

# 4) 런타임 아틀라스 합성
python3 "$SG/scripts/compose_sprite_atlas.py" --run-dir "$OUT"
#  → sprite-sheet-alpha.png, manifest.json (frame_layout)

# 5) 모션 QA 프리뷰 (컨택트시트 + state GIF) — 루프 seam·모션 연속성 검수
python3 "$SG/scripts/preview_animation.py" --run-dir "$OUT"
```

---

## 4. 출력 → Flutter 런타임 계약
`manifest.json` 필수 필드:
- `game_input: "sprite-sheet-alpha.png"`
- `degraded_static_fallback: false`
- `animation.rows.<state>` = `{ frames, fps, loop }`
- `frame_layout.rows.<state>[i]` = **절대 아틀라스 사각형(rect)**

**Flutter `CharacterView` 계약**:
- `sprite-sheet-alpha.png` + `manifest.json` 로드
- `emotion = X` → `frame_layout.rows.X`의 rect들을 `animation.rows.X.fps`로 순차 재생
- **emotion → sprite state 매핑**: `talking`→`talk`, `idle`→현재 무드 버킷에 따라 `idle`/`idle_down`/`idle_up`. 나머지는 1:1
- ⚠️ **rect만 샘플링**. 그리드 추측·전체 아틀라스 통짜 렌더·런타임 알파에서 프레임 복원 = 실패 통합

---

## 5. 초안 → 실제 스키마 정합 변경점

| 항목 | 초안([04](04-character-noa.md) 최초) | 실제 sprite-gen v1.7.0 |
|---|---|---|
| 구조 | `actions: [ {name, ...} ]` 배열 | `states: { "<name>": {...} }` 객체 |
| 설명 필드 | `desc` | `action` |
| fps | 없음 | **필수**(기본 6) |
| 상태명 | `talking` | `talk`(관례) — 앱이 emotion→state 매핑 |
| happy / surprised frames | 6 / 5 | **4 / 5** (가이드 준수) |
| 무드 baseline | "idle 3종" 묶음 | **독립 state 3개** (idle / idle_down / idle_up) |

---

## 6. 다음
1. **베이스 락 게이트 통과** — 노아 베이스 1장(§0 브리프)
2. `noa.request.json`으로 `prepare` → **Wave 1 (6 states)** image-gen → extract → curate → compose
3. `manifest.json`을 Flutter `CharacterView`에 연결 → 감정 재생 + 무드 baseline 전환 검증
4. (Wave 2) `idle_down`/`idle_up` 추가
