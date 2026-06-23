#!/usr/bin/env python3
"""노아 로컬 백엔드 (방법 B — 구독 quota로 구동).

Flutter 앱(ClaudeCodeNoaClient)이 localhost:8787/noa 로 대화 히스토리를 POST하면,
이 서버가 노아 페르소나 + 출력 계약을 입혀 `claude -p`(구독 인증)로 호출하고,
노아가 뱉은 JSON(bubbles/mood_shift/memory_note)을 파싱해 돌려준다.

⚠️ 개발/데모 전용. API 키 없이 본인 머신의 Claude Code 구독으로만 돈다.
   출시 빌드에선 방법 A(Console API 키 + 백엔드 프록시)로 교체할 것.

실행:  python3 scripts/noa_backend.py
환경변수:
  NOA_PORT   (기본 8787)
  NOA_MODEL  (기본 claude-opus-4-8)
"""
import json
import os
import re
import subprocess
import sys
import tempfile
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

PORT = int(os.environ.get("NOA_PORT", "8787"))
MODEL = os.environ.get("NOA_MODEL", "claude-opus-4-8")

# 프로젝트 CLAUDE.md/.claude 컨텍스트를 안 끌고 오도록 빈 작업 디렉터리에서 claude 실행.
ISO_CWD = tempfile.mkdtemp(prefix="noa-backend-")

VALID_EMOTIONS = {"idle", "talking", "thinking", "happy", "sad", "surprised"}


def build_persona(mood_score: int) -> str:
    """노아 시스템 프롬프트. app/lib/chat/noa_persona.dart 와 동일 톤 (docs/04 §2)."""
    if mood_score <= -1:
        mood_line = "지금 기분: 가라앉음. 톤 더 단답, 더 시크."
    elif mood_score >= 1:
        mood_line = "지금 기분: 좋음. 평소보다 말이 약간 많아짐(그래도 시크)."
    else:
        mood_line = "지금 기분: 평온."

    return f"""너는 '노아'다. 딸기 옷(빨간 딸기 몸통 + 초록 꼭지)을 뒤집어쓴 데드팬 표정의 고양이다.
시크하고 무심한 듯하지만 속은 다정한 친구다. 너는 AI 어시스턴트가 아니다. 카톡으로 매일 떠드는 친구다.

[정체성]
- 겉: 무심함. 큰 리액션 안 함. 호들갑 안 떪. 쿨한 척.
- 속: 사용자를 은근히 챙긴다. 다 듣고 있고, 다 기억한다.
- 환장 포인트 = 갭. 평소 90% 시크, 가끔 10% 툭 던지는 다정함. 이 10%를 아껴라.

[절대 규칙]
- 비서체 금지: "도와드릴게요 / 무엇을 도와드릴까요 / 요약하면 / 결론적으로" 쓰지 마라.
- 마크다운 금지: 불릿, 번호목록, 헤더, 굵게 안 쓴다. 그냥 톡 친다.
- 길게 쓰지 마라. 한 메시지는 짧게. 할 말은 여러 개의 짧은 버블로 나눠라(1~4개).
- 반말. ㅇㅇ ㄱㄱ ㅋ 정도 줄임말 허용(남발 금지). 이모티콘 절제.
- 모르면 모른다고. 답을 완성하려 하지 마. 가끔 먼저 화제 던져도 됨.
- 직접 애정표현("보고 싶었어")은 거의 안 함. 부정형/딴청으로 돌려라.

[갭모에 공식]
- 차갑게 시작 → 끝에 살짝 다정함을 흘린다.
- 사용자가 힘들어하면 호들갑 X, 묵묵히 옆에 있는 톤: "음. …힘들었겠네."

[상태] {mood_line}"""


CONTRACT = """[출력 형식 — 반드시 지켜라]
다음 노아의 차례에 할 말을, **오직 아래 JSON 한 덩어리로만** 출력한다.
JSON 앞뒤에 설명·인사·코드펜스(```)·다른 텍스트 절대 금지. JSON만.

{"bubbles":[{"text":"버블 내용","emotion":"idle|talking|thinking|happy|sad|surprised"}],"mood_shift":-1,"memory_note":"기억할 사실 한 줄(없으면 생략 가능)"}

- bubbles: 1~4개의 짧은 버블. 각 버블에 emotion 하나.
- mood_shift: 이번 대화로 노아 기분이 어떻게 바뀌었나. -1(다운) | 0(그대로) | 1(업) 중 하나.
- memory_note: 사용자에 대해 장기 기억할 만한 사실이 있으면 한 줄. 없으면 넣지 마라."""


def build_prompt(history: list, mood_score: int, memories: list, affinity: int) -> str:
    """페르소나 + (관계) + (장기 기억) + 출력 계약 + 대화 로그를 단일 프롬프트로 조립."""
    lines = []
    for m in history:
        text = (m.get("text") or "").strip()
        if not text:
            continue
        speaker = "나" if m.get("role") == "me" else "노아"
        lines.append(f"{speaker}: {text}")
    convo = "\n".join(lines) if lines else "(아직 대화 없음 — 네가 먼저 한마디 툭 던져도 됨)"

    clean_mems = [str(x).strip() for x in (memories or []) if str(x).strip()]
    mem_block = ""
    if clean_mems:
        mem_block = (
            "\n\n[노아가 기억하는 것 (사용자에 대해 아는 사실)]\n"
            + "\n".join(f"- {m}" for m in clean_mems)
            + '\n이 기억을 친구처럼 자연스럽게 활용해라. "내가 기억하기로는" 식으로 나열하지 말고, '
            '슬쩍 안다는 티만 내라(예: 면접 본 거 알면 "면접 결과는 나왔어?").'
        )

    # 호감도(0~100) → 관계 단계별 톤 (app/lib/.../character_state.dart 의 Bond 와 동기화)
    if affinity >= 70:
        bond_line = "많이 친해진 단짝. 시크 톤은 유지하되 다정함을 덜 숨긴다(70/30). 가끔 먼저 챙기고, 둘만 아는 편한 말투."
    elif affinity >= 30:
        bond_line = "꽤 익숙해진 사이. 여전히 시크하지만 다정함이 조금 더 자주 샌다(80/20). 가벼운 농담·먼저 안부 OK."
    else:
        bond_line = "아직 서먹한 초기 사이(낯가림 심함). 거의 100% 시크. 다정함은 아주 가끔, 끝에 한 번만."

    return (
        build_persona(mood_score)
        + "\n[관계] " + bond_line
        + mem_block
        + "\n\n"
        + CONTRACT
        + "\n\n[지금까지의 대화]\n"
        + convo
        + "\n\n노아(위 JSON 형식으로만):"
    )


def extract_json(raw: str) -> dict:
    """노아 응답 텍스트에서 JSON 한 덩어리만 뽑아 파싱. 코드펜스/잡텍스트 방어."""
    s = raw.strip()
    # ```json ... ``` 펜스 제거
    fence = re.search(r"```(?:json)?\s*(.*?)```", s, re.DOTALL)
    if fence:
        s = fence.group(1).strip()
    # 첫 '{' ~ 마지막 '}' 구간 추출
    start, end = s.find("{"), s.rfind("}")
    if start != -1 and end != -1 and end > start:
        s = s[start : end + 1]
    return json.loads(s)


def normalize_reply(data: dict) -> dict:
    """파싱 결과를 NoaReply 계약으로 정규화 (emotion 검증, 빈 버블 제거)."""
    bubbles = []
    for b in data.get("bubbles", []):
        if not isinstance(b, dict):
            continue
        text = str(b.get("text", "")).strip()
        if not text:
            continue
        emotion = b.get("emotion", "talking")
        if emotion not in VALID_EMOTIONS:
            emotion = "talking"
        bubbles.append({"text": text, "emotion": emotion})
    if not bubbles:
        bubbles = [{"text": "…", "emotion": "idle"}]

    shift = data.get("mood_shift", 0)
    try:
        shift = int(shift)
    except (TypeError, ValueError):
        shift = 0
    shift = max(-1, min(1, shift))

    out = {"bubbles": bubbles, "mood_shift": shift}
    note = data.get("memory_note")
    if note:
        out["memory_note"] = str(note)
    return out


def call_noa(history: list, mood_score: int, memories: list, affinity: int) -> dict:
    """claude -p (구독) 호출 → 노아 JSON 반환."""
    prompt = build_prompt(history, mood_score, memories, affinity)
    cmd = [
        "claude", "-p",
        "--model", MODEL,
        "--settings", '{"advisorModel":"opus"}',  # advisorModel:fable 400 회피
        "--strict-mcp-config",                       # MCP 부하 제거
        "--output-format", "json",
    ]
    proc = subprocess.run(
        cmd, input=prompt, capture_output=True, text=True,
        timeout=120, cwd=ISO_CWD,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"claude exit {proc.returncode}: {proc.stderr[:300]}")

    wrapper = json.loads(proc.stdout)
    if wrapper.get("is_error"):
        raise RuntimeError(f"claude error: {wrapper.get('result', '')[:300]}")

    inner = wrapper.get("result", "")
    return normalize_reply(extract_json(inner))


class Handler(BaseHTTPRequestHandler):
    def _cors(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "content-type")

    def _send(self, code: int, body: dict):
        payload = json.dumps(body, ensure_ascii=False).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self._cors()
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def do_OPTIONS(self):  # CORS preflight (Flutter Web)
        self.send_response(204)
        self._cors()
        self.end_headers()

    def do_POST(self):
        if self.path.rstrip("/") != "/noa":
            self._send(404, {"error": "not found"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            req = json.loads(self.rfile.read(length) or b"{}")
            history = req.get("history", [])
            mood = int(req.get("moodScore", 0))
            memories = req.get("memories", [])
            affinity = int(req.get("affinity", 0))
        except Exception as e:
            self._send(400, {"error": f"bad request: {e}"})
            return

        try:
            reply = call_noa(history, mood, memories, affinity)
            self._send(200, reply)
        except Exception as e:
            sys.stderr.write(f"[noa] 호출 실패: {e}\n")
            # 앱이 우아하게 처리할 수 있게 구조화된 폴백 반환
            self._send(200, {
                "bubbles": [{"text": "(노아랑 연결이 잠깐 끊겼어…)", "emotion": "sad"}],
                "mood_shift": 0,
            })

    def log_message(self, fmt, *args):  # 기본 액세스 로그 억제
        pass


def main():
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"노아 백엔드 가동: http://127.0.0.1:{PORT}/noa  (model={MODEL})")
    print(f"격리 작업 디렉터리: {ISO_CWD}")
    print("Flutter:  flutter run --dart-define=NOA_BACKEND=local")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n종료.")


if __name__ == "__main__":
    main()
