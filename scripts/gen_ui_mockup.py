#!/usr/bin/env python3
"""agenttalk UI 방향 3안 목업(HTML) 생성기. 노아 실제 이미지를 data URI 로 임베드.
출력: scratchpad 의 ui-directions.html (Artifact 로 배포)."""
import base64
import io
import os
import sys

from PIL import Image

SRC = os.path.join(os.path.dirname(__file__), "..", "app", "assets", "character", "noa.jpg")
OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/ui-directions.html"

im = Image.open(SRC).convert("RGB")
im.thumbnail((260, 260))
buf = io.BytesIO()
im.save(buf, format="JPEG", quality=82)
noa = "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()

HTML = """<style>
:root{--noa:url('%NOA%');}
*{box-sizing:border-box;margin:0;padding:0;}
body{font-family:ui-rounded,'SF Pro Rounded','Apple SD Gothic Neo',system-ui,sans-serif;
  background:radial-gradient(120%% 90%% at 50%% 0%%,#241b2b,#14101a);color:#efe7f0;
  -webkit-font-smoothing:antialiased;padding:34px 0 60px;}
.head{max-width:1040px;margin:0 auto 26px;padding:0 22px;}
.head .kick{font-size:12px;letter-spacing:.22em;text-transform:uppercase;color:#b79bd0;font-weight:700;}
.head h1{font-size:30px;font-weight:850;margin:6px 0 8px;letter-spacing:-.01em;}
.head p{color:#b5a9bd;max-width:620px;line-height:1.55;font-size:14.5px;}
.rail{display:flex;gap:26px;padding:6px 22px 10px;overflow-x:auto;scroll-snap-type:x proximity;}
.rail::-webkit-scrollbar{height:8px;}.rail::-webkit-scrollbar-thumb{background:#3a2f47;border-radius:8px;}
figure{flex:0 0 auto;width:312px;scroll-snap-align:center;}
.phone{width:312px;height:624px;border-radius:42px;overflow:hidden;position:relative;
  box-shadow:0 24px 60px rgba(0,0,0,.45),0 0 0 8px #0c0911,0 0 0 9px #2b2233;display:flex;flex-direction:column;}
figcaption{margin-top:16px;}
figcaption .num{font-size:12px;font-weight:800;color:#8a78a0;letter-spacing:.1em;}
figcaption b{display:block;font-size:18px;margin:3px 0 6px;font-weight:800;}
figcaption p{color:#b5a9bd;font-size:13px;line-height:1.5;}
figcaption .diff{margin-top:9px;font-size:12px;color:#9ed0b4;line-height:1.5;}
.msgs{flex:1;overflow:hidden;display:flex;flex-direction:column;gap:9px;}
.b{max-width:78%%;padding:9px 13px;font-size:14px;line-height:1.34;}
.me{align-self:flex-end;}
@media (prefers-reduced-motion:no-preference){.float{animation:f 3.6s ease-in-out infinite;}}
@keyframes f{0%%,100%%{transform:translateY(0)}50%%{transform:translateY(-7px)}}

/* ============ 01 노아의 방 ============ */
.d1{background:linear-gradient(180deg,#ffd9c9 0%%,#ffe7df 30%%,#fff4ee 60%%,#fff8f3 100%%);}
.d1 .stage{height:248px;position:relative;overflow:hidden;
  background:radial-gradient(90%% 70%% at 50%% 18%%,#ffe1a8,#ffd2bf 55%%,transparent 75%%);}
.d1 .sun{position:absolute;top:26px;right:34px;width:46px;height:46px;border-radius:50%%;
  background:radial-gradient(#fff3b0,#ffd24d);box-shadow:0 0 30px #ffd86b;}
.d1 .spark{position:absolute;color:#ffae9b;font-size:13px;opacity:.8;}
.d1 .noa{position:absolute;left:50%%;bottom:8px;transform:translateX(-50%%);width:158px;height:158px;
  background:var(--noa) center/contain no-repeat;filter:drop-shadow(0 12px 10px rgba(150,60,60,.28));}
.d1 .shelf{position:absolute;left:0;right:0;bottom:0;height:30px;
  background:linear-gradient(#ffae8f,#ff9d7e);border-radius:50%% 50%% 0 0/30px;}
.d1 .status{position:absolute;left:18px;top:18px;background:#ffffffcc;border-radius:20px;
  padding:6px 12px;font-size:12px;font-weight:700;color:#a8425a;backdrop-filter:blur(4px);}
.d1 .msgs{padding:14px 16px 0;}
.d1 .noa-b{align-self:flex-start;background:#fff;border-radius:20px 20px 20px 6px;color:#5b2333;
  box-shadow:0 6px 16px rgba(190,90,90,.14);}
.d1 .me{background:#e2474f;color:#fff;border-radius:20px 20px 6px 20px;font-weight:600;}
.d1 .bar{margin:auto 14px 18px;background:#fff;border-radius:26px;display:flex;align-items:center;
  gap:8px;padding:8px 8px 8px 16px;box-shadow:0 8px 20px rgba(190,90,90,.16);}
.d1 .bar input{border:0;flex:1;font:inherit;font-size:13.5px;color:#5b2333;background:none;outline:none;}
.d1 .bar input::placeholder{color:#c9a3a3;}
.d1 .send{width:38px;height:38px;border-radius:50%%;background:#e2474f;color:#fff;border:0;
  display:grid;place-items:center;font-size:16px;}

/* ============ 02 스티커 다이어리 ============ */
.d2{background:#f3dfc6;background-image:radial-gradient(#e9d2b3 1px,transparent 1.4px);
  background-size:14px 14px;}
.d2 .top{position:relative;padding:18px 18px 4px;}
.d2 .tape{position:absolute;top:-6px;left:50%%;transform:translateX(-50%%) rotate(-3deg);
  width:128px;height:26px;background:#a7d7c5cc;box-shadow:0 3px 8px rgba(120,90,60,.18);}
.d2 .date{font-size:12px;font-weight:800;color:#9a6b4f;letter-spacing:.12em;}
.d2 .who{display:flex;align-items:center;gap:10px;margin-top:8px;}
.d2 .who .pic{width:54px;height:54px;border-radius:14px;background:var(--noa) center/cover;
  transform:rotate(-5deg);box-shadow:0 5px 12px rgba(120,80,50,.28);border:3px solid #fff;}
.d2 .who b{font-size:17px;color:#4a3b33;font-weight:850;}
.d2 .who span{display:block;font-size:11.5px;color:#b98a5e;font-weight:700;}
.d2 .msgs{padding:14px 18px 0;gap:13px;}
.d2 .note{background:#fffaf2;padding:11px 14px;font-size:14px;color:#4a3b33;line-height:1.35;max-width:80%%;
  box-shadow:0 6px 14px rgba(120,80,50,.16);position:relative;}
.d2 .noa-b{align-self:flex-start;transform:rotate(-1.4deg);border-left:4px solid #c8455b;}
.d2 .me{align-self:flex-end;transform:rotate(1.6deg);background:#ffe7c9;border-right:4px solid #f2a13e;color:#6b4a2a;font-weight:600;}
.d2 .stk{position:absolute;right:-8px;top:-10px;font-size:18px;transform:rotate(12deg);}
.d2 .bar{margin:auto 16px 18px;border-top:2px dashed #c9a988;padding-top:10px;display:flex;align-items:center;gap:8px;}
.d2 .bar input{border:0;flex:1;font:inherit;font-size:13.5px;color:#4a3b33;background:none;outline:none;}
.d2 .bar input::placeholder{color:#bd9d7c;}
.d2 .send{border:0;background:#c8455b;color:#fff;font-weight:800;font-size:12.5px;padding:9px 14px;border-radius:10px;transform:rotate(-2deg);}

/* ============ 03 젤리 팝 ============ */
.d3{background:#fff0d6;}
.d3 .top{padding:18px 16px 6px;display:flex;align-items:center;gap:12px;
  border-bottom:3px solid #2b1b1e;background:#ffd84d;}
.d3 .badge{width:60px;height:60px;border-radius:50%%;background:var(--noa) center/cover #fff;
  border:3px solid #2b1b1e;box-shadow:4px 4px 0 #2b1b1e;}
.d3 .top b{font-size:20px;font-weight:900;color:#2b1b1e;-webkit-text-stroke:0;}
.d3 .top span{display:block;font-size:12px;font-weight:800;color:#b83a2e;}
.d3 .msgs{padding:16px 14px 0;gap:14px;}
.d3 .b{border:3px solid #2b1b1e;border-radius:18px;font-weight:700;}
.d3 .noa-b{align-self:flex-start;background:#fff;color:#2b1b1e;box-shadow:4px 4px 0 #2b1b1e;border-radius:18px 18px 18px 5px;}
.d3 .me{background:#e63950;color:#fff;box-shadow:-4px 4px 0 #2b1b1e;border-radius:18px 18px 5px 18px;}
.d3 .pop{align-self:flex-start;background:#5fc9a6;color:#08372a;box-shadow:4px 4px 0 #2b1b1e;border-radius:18px;font-weight:800;}
.d3 .bar{margin:auto 14px 18px;display:flex;gap:8px;align-items:center;}
.d3 .bar .field{flex:1;border:3px solid #2b1b1e;border-radius:16px;background:#fff;padding:9px 13px;font-size:13px;color:#8a7;box-shadow:3px 3px 0 #2b1b1e;}
.d3 .send{width:44px;height:44px;border:3px solid #2b1b1e;border-radius:50%%;background:#e63950;color:#fff;font-size:18px;box-shadow:3px 3px 0 #2b1b1e;}
</style>

<header class="head">
  <div class="kick">agenttalk · design directions</div>
  <h1>노아 컴패니언, 우리만의 UI 3안</h1>
  <p>카톡 문법(블루그레이·노란 말풍선·좌우 프로필) 탈출. 셋 다 “메신저”가 아니라 “귀여운 AI랑 노는 공간”을 목표로 했어요. 하나 고르거나 섞어주세요 — 그대로 Flutter로 구현합니다. (옆으로 스크롤)</p>
</header>

<div class="rail">

  <figure>
    <div class="phone d1">
      <div class="stage">
        <div class="sun"></div>
        <div class="spark" style="left:30px;top:60px">✦</div>
        <div class="spark" style="left:74px;top:110px">✧</div>
        <div class="spark" style="right:60px;top:90px">✦</div>
        <div class="status">기분 좋음 · ☀️ 낮</div>
        <div class="noa float"></div>
        <div class="shelf"></div>
      </div>
      <div class="msgs">
        <div class="b noa-b">왔어?</div>
        <div class="b noa-b">딱히 기다린 건 아닌데.</div>
        <div class="b me">오늘 좀 힘들었어</div>
        <div class="b noa-b">음. …힘들었겠네.</div>
      </div>
      <div class="bar"><input placeholder="노아한테 말 걸기" disabled><button class="send">♥</button></div>
    </div>
    <figcaption><span class="num">01</span><b>노아의 방</b>
      <p>캐릭터가 화면의 주인공. 상단 “방”은 노아 기분·시간대(아침/밤/비)에 따라 색과 분위기가 살아 바뀝니다. 대화는 그 아래로 한 줄기.</p>
      <p class="diff">↔ 카톡과 다른 점: 메신저 앱바·좌우 프로필 없음. 톡하러 가는 게 아니라 “보러 가는” 느낌.</p>
    </figcaption>
  </figure>

  <figure>
    <div class="phone d2">
      <div class="top">
        <div class="tape"></div>
        <div class="date">2026 · 6 · 19 · 금</div>
        <div class="who"><div class="pic"></div><div><b>노아</b><span>오늘의 기분 — 시크함 70%</span></div></div>
      </div>
      <div class="msgs">
        <div class="note noa-b">왔어? 딱히 기다린 건 아닌데.<span class="stk">🍓</span></div>
        <div class="note me">오늘 좀 힘들었어</div>
        <div class="note noa-b">음. …힘들었겠네. 여기 있을게.</div>
      </div>
      <div class="bar"><input placeholder="오늘 한 줄 적기…" disabled><button class="send">붙이기</button></div>
    </div>
    <figcaption><span class="num">02</span><b>스티커 다이어리</b>
      <p>대화가 따뜻한 종이 위 스티커 메모로 쌓입니다. 살짝 기울어진 카드·워시테이프·스티커. 무드는 카드 옆선 색으로.</p>
      <p class="diff">↔ 카톡과 다른 점: 휘발되는 채팅이 아니라 “쌓이는 교환 일기”. 촉감·손맛 중심.</p>
    </figcaption>
  </figure>

  <figure>
    <div class="phone d3">
      <div class="top"><div class="badge"></div><div><b>노아</b><span>● happy · mood +1</span></div></div>
      <div class="msgs">
        <div class="b noa-b">왔어?</div>
        <div class="b noa-b">딱히 기다린 건 아닌데.</div>
        <div class="b me">오늘 좀 힘들었어</div>
        <div class="b pop">음. …힘들었겠네.</div>
      </div>
      <div class="bar"><div class="field">메시지…</div><button class="send">➤</button></div>
    </div>
    <figcaption><span class="num">03</span><b>젤리 팝</b>
      <p>“통통 튀고 귀여움”을 끝까지. 두꺼운 외곽선 + 하드 섀도 + 캔디 컬러의 장난감/스티커 룩. 말풍선이 젤리처럼 통통 튐.</p>
      <p class="diff">↔ 카톡과 다른 점: 무채색 유틸리티 0. 밈 네이티브·Z세대 취향의 강한 개성.</p>
    </figcaption>
  </figure>

</div>
""".replace("%NOA%", noa).replace("%%", "%")

with open(OUT, "w") as f:
    f.write(HTML)
print("wrote", OUT, "(", len(HTML), "bytes )")
