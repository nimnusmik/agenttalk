생성한 가구 이미지를 여기에 두세요.

개별 모드: bed.png, desk.png, sofa.png, lamp.png, plant.png,
          fridge.png, counter.png, table.png, rug.png  (png/jpg/webp 가능)
시트 모드: sheet.png (3x3 한 장)  →  실행 시 --sheet 옵션

그다음:
  python3 scripts/cutout_furniture.py            # 개별
  python3 scripts/cutout_furniture.py --sheet     # 시트

→ app/assets/room/<name>.png (투명) 생성됨.
이 _raw/ 폴더는 앱 번들에 포함되지 않습니다(생성 원본 보관용).
