#!/usr/bin/env python3
"""노아의 방(Direction 01) 인터랙티브 목업 생성기.
노아 누끼(noa_cut.png)를 data URI 로 임베드. 노아가 방을 돌아다니고, 말 걸면 쳐다봄.
출력: 인자로 받은 경로(기본 /tmp/noa-room.html). Artifact 로 배포."""
import base64
import io
import os
import sys

from PIL import Image

SRC = os.path.join(os.path.dirname(__file__), "..", "app", "assets", "character", "noa_cut.png")
OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/noa-room.html"

im = Image.open(SRC).convert("RGBA")
im.thumbnail((240, 240))
buf = io.BytesIO()
im.save(buf, format="PNG")
noa = "data:image/png;base64," + base64.b64encode(buf.getvalue()).decode()

HTML = r"""<style>
*{box-sizing:border-box;margin:0;padding:0;}
body{font-family:ui-rounded,'SF Pro Rounded','Apple SD Gothic Neo',system-ui,sans-serif;
  background:#16121d;display:flex;flex-direction:column;align-items:center;gap:14px;
  padding:26px 14px 50px;color:#e9dff0;-webkit-font-smoothing:antialiased;}
.cap{max-width:380px;text-align:center;}
.cap h1{font-size:19px;font-weight:850;}
.cap p{font-size:13px;color:#b4a7c2;margin-top:6px;line-height:1.5;}
.cap b{color:#ffb39f;}

.phone{width:360px;height:720px;border-radius:46px;overflow:hidden;position:relative;
  background:#fff;box-shadow:0 28px 70px rgba(0,0,0,.5),0 0 0 9px #0b0810,0 0 0 10px #2a2034;
  display:flex;flex-direction:column;}

/* ---- 방 ---- */
.room{position:relative;height:432px;overflow:hidden;cursor:pointer;
  background:linear-gradient(180deg,#ffe3d4 0%,#ffeee6 46%,#fff5ef 64%);}
.win{position:absolute;top:34px;left:30px;width:104px;height:88px;border-radius:12px;
  background:linear-gradient(180deg,#bfe4ff,#e9f7ff);border:5px solid #fff;
  box-shadow:0 8px 18px rgba(170,120,110,.18);}
.win::before,.win::after{content:"";position:absolute;background:#fff;}
.win::before{left:50%;top:0;bottom:0;width:5px;margin-left:-2px;}
.win::after{top:50%;left:0;right:0;height:5px;margin-top:-2px;}
.cloud{position:absolute;top:54px;left:46px;width:34px;height:12px;background:#fff;border-radius:10px;opacity:.9;}
.plant{position:absolute;right:20px;bottom:118px;font-size:34px;filter:drop-shadow(0 4px 4px rgba(150,90,80,.2));}
.floor{position:absolute;left:0;right:0;bottom:0;height:128px;
  background:linear-gradient(180deg,#f7ccb4,#eeb89c);}
.rug{position:absolute;left:50%;bottom:30px;transform:translateX(-50%);width:230px;height:64px;
  border-radius:50%;background:radial-gradient(closest-side,#ffd34d55,#ffb84d22);}
.status{position:absolute;left:16px;top:140px;background:#ffffffdd;border-radius:20px;padding:7px 13px;
  font-size:12px;font-weight:800;color:#a8425a;backdrop-filter:blur(4px);box-shadow:0 4px 12px rgba(190,90,90,.16);}

.shadow{position:absolute;bottom:80px;width:78px;height:18px;border-radius:50%;
  background:rgba(150,70,60,.22);filter:blur(2px);transform:translateX(-50%);transition:left .8s cubic-bezier(.4,0,.5,1),opacity .3s;}
.noa{position:absolute;bottom:92px;left:180px;transform:translateX(-50%) scaleX(1);
  transition:left .8s cubic-bezier(.4,0,.5,1),transform .26s ease;will-change:left,transform;}
.noa img{width:92px;display:block;transform-origin:bottom center;
  animation:breathe 3.2s ease-in-out infinite;filter:drop-shadow(0 6px 5px rgba(150,60,60,.22));}
.noa.move img{animation:hop var(--t,.8s) ease;}
@keyframes breathe{0%,100%{transform:scale(1,1)}50%{transform:scale(1.035,.98)}}
@keyframes hop{0%{transform:translateY(0)}14%{transform:translateY(-17px)}30%{transform:translateY(0)}
  46%{transform:translateY(-12px)}62%{transform:translateY(0)}80%{transform:translateY(-8px)}100%{transform:translateY(0)}}
.ind{position:absolute;left:50%;top:-26px;transform:translateX(-50%);background:#fff;border-radius:14px;
  padding:2px 9px;font-size:14px;font-weight:800;color:#e2474f;opacity:0;transition:opacity .2s;
  box-shadow:0 4px 10px rgba(190,90,90,.2);white-space:nowrap;}
.ind.on{opacity:1;}
@media (prefers-reduced-motion:reduce){.noa{transition:none}.noa img,.noa.move img{animation:none}}

/* ---- 대화 ---- */
.chat{flex:1;background:linear-gradient(180deg,#fff5ef,#fff);padding:14px 16px;overflow:hidden;
  display:flex;flex-direction:column;gap:8px;}
.bub{max-width:80%;padding:9px 13px;font-size:14px;line-height:1.34;}
.bub.noa-b{align-self:flex-start;background:#fff;color:#5b2333;border-radius:18px 18px 18px 6px;
  box-shadow:0 5px 14px rgba(190,90,90,.12);}
.bub.me{align-self:flex-end;background:#e2474f;color:#fff;border-radius:18px 18px 6px 18px;font-weight:600;}
.bar{display:flex;align-items:center;gap:8px;padding:10px 10px 10px 16px;background:#fff;
  box-shadow:0 -4px 16px rgba(190,90,90,.08);}
.bar input{flex:1;border:0;background:#f6ece8;border-radius:22px;padding:11px 15px;font:inherit;
  font-size:14px;color:#5b2333;outline:none;}
.bar input::placeholder{color:#caa3a3;}
.bar button{width:42px;height:42px;border:0;border-radius:50%;background:#e2474f;color:#fff;font-size:17px;cursor:pointer;
  transition:transform .09s;}
.bar button:active{transform:scale(.84);}
</style>

<div class="cap">
  <h1>노아의 방 · Direction 01</h1>
  <p>노아가 방을 <b>뽈뽈뽈 돌아다녀요.</b> 입력창에 말을 걸거나 <b>방을 톡 누르면</b> 가운데로 와서 <b>정면으로 쳐다봅니다.</b> 직접 해보세요.</p>
</div>

<div class="phone">
  <div class="room" id="room">
    <div class="win"></div><div class="cloud"></div>
    <div class="plant">🪴</div>
    <div class="floor"></div>
    <div class="rug"></div>
    <div class="status" id="status">기분 평온 · ☀️ 낮</div>
    <div class="shadow" id="shadow"></div>
    <div class="noa" id="noa"><div class="ind" id="ind"></div><img alt="노아" src="__NOA__"></div>
  </div>
  <div class="chat" id="chat">
    <div class="bub noa-b">왔어? 딱히 기다린 건 아닌데.</div>
  </div>
  <div class="bar">
    <input id="inp" placeholder="노아한테 말 걸기" autocomplete="off">
    <button id="send" aria-label="보내기">♥</button>
  </div>
</div>

<script>
(function(){
  var room=document.getElementById('room'), noa=document.getElementById('noa'),
      ind=document.getElementById('ind'), shadow=document.getElementById('shadow'),
      chat=document.getElementById('chat'), inp=document.getElementById('inp'),
      send=document.getElementById('send'), status=document.getElementById('status');
  var faceRight=true, looking=false, wanderT=null, lookT=null, busy=false;
  var reduce = window.matchMedia('(prefers-reduced-motion:reduce)').matches;

  function rw(){return room.clientWidth;}
  function setX(x){ noa.style.left=x+'px'; shadow.style.left=x+'px'; }
  function curX(){ return parseFloat(noa.style.left)||rw()/2; }
  function applyTransform(){
    noa.style.transform = looking ? 'translateX(-50%) scale(1.16)'
                                  : 'translateX(-50%) scaleX('+(faceRight?1:-1)+')';
  }
  function moveTo(x,dur){
    var d=dur||Math.max(0.45,Math.min(1.5,Math.abs(x-curX())/170));
    noa.style.setProperty('--t',d+'s');
    shadow.style.transition='left '+d+'s cubic-bezier(.4,0,.5,1)';
    noa.style.transition='left '+d+'s cubic-bezier(.4,0,.5,1),transform .26s ease';
    noa.classList.add('move'); applyTransform();
    requestAnimationFrame(function(){ setX(x); });
    clearTimeout(noa._mv); noa._mv=setTimeout(function(){noa.classList.remove('move');}, d*1000+40);
  }
  function showInd(t){ ind.textContent=t; ind.classList.add('on'); }
  function hideInd(){ ind.classList.remove('on'); }

  function wander(){
    if(looking||reduce) return;
    var a=46,b=rw()-46; faceRight = (Math.random()<0.5)?false:true;
    var tx=a+Math.random()*(b-a); faceRight = tx>=curX();
    moveTo(tx);
    clearTimeout(wanderT); wanderT=setTimeout(wander, 1300+Math.random()*1900);
  }
  function lookAtUser(){
    looking=true; clearTimeout(wanderT); showInd('!');
    faceRight=true; moveTo(rw()/2,0.5);
    clearTimeout(lookT);
    lookT=setTimeout(function(){ looking=false; hideInd(); applyTransform(); wander(); }, 4200);
  }

  var EMO={happy:'♪',sad:'…',surprised:'!',thinking:'…'};
  function reply(text){
    var t=text.toLowerCase(), bubbles, mood='기분 평온 · ☀️ 낮', emo='';
    if(/안녕|하이|ㅎㅇ|hi|hello/.test(t)){ bubbles=['왔어?','딱히 기다린 건 아닌데.']; }
    else if(/힘들|우울|지쳐|슬프|속상/.test(t)){ bubbles=['음.','…힘들었겠네.','딱히 걱정하는 건 아닌데. 여기 있을게.']; emo='sad'; mood='기분 가라앉음 · 🌧'; }
    else if(/!|ㅋㅋ|좋|행복|개꿀|대박/.test(t)){ bubbles=['오 뭔데.','…뭐. 잘됐네.']; emo='happy'; mood='기분 좋음 · ☀️'; }
    else { var p=[['그래서?','별로 안 궁금한데. …말해봐.'],['흐음.','뭐, 그럴 수도 있지.'],['음.','듣고 있어. 계속해.']]; bubbles=p[Math.floor(Math.random()*p.length)]; }
    status.textContent=mood;
    var i=0;
    (function next(){
      if(i>=bubbles.length){ busy=false; return; }
      var d=document.createElement('div'); d.className='bub noa-b'; d.textContent=bubbles[i];
      chat.appendChild(d); chat.scrollTop=chat.scrollHeight;
      if(emo&&EMO[emo]){ showInd(EMO[emo]); }
      // 작은 반응 홉
      noa.classList.add('move'); noa.style.setProperty('--t','.5s');
      clearTimeout(noa._mv); noa._mv=setTimeout(function(){noa.classList.remove('move');},520);
      i++; setTimeout(next, 750+bubbles[i-1].length*40);
    })();
  }
  function userSay(text){
    if(busy||!text.trim()) return; busy=true;
    var d=document.createElement('div'); d.className='bub me'; d.textContent=text;
    chat.appendChild(d); chat.scrollTop=chat.scrollHeight;
    lookAtUser();
    setTimeout(function(){ reply(text); }, 900);
  }

  send.addEventListener('click',function(){ var v=inp.value; inp.value=''; userSay(v); });
  inp.addEventListener('keydown',function(e){ if(e.key==='Enter'){ var v=inp.value; inp.value=''; userSay(v); } });
  inp.addEventListener('focus', lookAtUser);
  room.addEventListener('click', function(e){ if(e.target.closest('.noa')||true){ lookAtUser(); } });

  // 시작: 가운데서 한 박자 뒤 산책 시작
  setX(rw()/2); applyTransform();
  setTimeout(wander, 900);
})();
</script>
""".replace("__NOA__", noa)

with open(OUT, "w") as f:
    f.write(HTML)
print("wrote", OUT, "(", len(HTML), "bytes )")
