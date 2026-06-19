import 'dart:convert';

/// sprite-gen `manifest.json` 모델 (compose_sprite_atlas.py v1.7.0 출력 스키마에 1:1 대응).
///
/// 런타임 SSoT 는 `frame_layout.rows.<state>[i]` 의 **절대 아틀라스 rect**.
/// 그리드 추측·전체 아틀라스 통짜 렌더는 실패 통합이다 — 반드시 rect 만 샘플링.

class SpriteRect {
  final int x, y, w, h;
  const SpriteRect(this.x, this.y, this.w, this.h);

  factory SpriteRect.fromJson(Map<String, dynamic> j) =>
      SpriteRect(j['x'] as int, j['y'] as int, j['w'] as int, j['h'] as int);

  @override
  bool operator ==(Object o) =>
      o is SpriteRect && o.x == x && o.y == y && o.w == w && o.h == h;

  @override
  int get hashCode => Object.hash(x, y, w, h);
}

class SpriteAnimationRow {
  final int row;
  final int frames;
  final int fps;
  final bool loop;
  const SpriteAnimationRow({
    required this.row,
    required this.frames,
    required this.fps,
    required this.loop,
  });

  factory SpriteAnimationRow.fromJson(Map<String, dynamic> j) => SpriteAnimationRow(
        row: j['row'] as int,
        frames: j['frames'] as int,
        fps: j['fps'] as int,
        loop: j['loop'] as bool,
      );
}

class SpriteManifest {
  final String characterId;
  final String gameInput; // 아틀라스 PNG 파일명 (game_input)
  final int cellWidth;
  final int cellHeight;
  final int sheetWidth;
  final int sheetHeight;
  final Map<String, List<SpriteRect>> frameLayoutRows;
  final Map<String, SpriteAnimationRow> animationRows;

  const SpriteManifest({
    required this.characterId,
    required this.gameInput,
    required this.cellWidth,
    required this.cellHeight,
    required this.sheetWidth,
    required this.sheetHeight,
    required this.frameLayoutRows,
    required this.animationRows,
  });

  bool hasState(String state) => frameLayoutRows.containsKey(state);
  List<String> get states => frameLayoutRows.keys.toList();
  List<SpriteRect>? framesFor(String state) => frameLayoutRows[state];
  SpriteAnimationRow? animFor(String state) => animationRows[state];

  factory SpriteManifest.fromJsonString(String s) =>
      SpriteManifest.fromJson(jsonDecode(s) as Map<String, dynamic>);

  factory SpriteManifest.fromJson(Map<String, dynamic> j) {
    final fl = j['frame_layout'] as Map<String, dynamic>;
    final flRows = (fl['rows'] as Map<String, dynamic>).map(
      (state, list) => MapEntry(
        state,
        (list as List)
            .map((r) => SpriteRect.fromJson(r as Map<String, dynamic>))
            .toList(),
      ),
    );
    final anim = j['animation'] as Map<String, dynamic>;
    final animRows = (anim['rows'] as Map<String, dynamic>).map(
      (state, v) =>
          MapEntry(state, SpriteAnimationRow.fromJson(v as Map<String, dynamic>)),
    );
    return SpriteManifest(
      characterId: j['characterId'] as String? ?? 'unknown',
      gameInput: (j['game_input'] ?? j['sprite_sheet_alpha'] ?? '') as String,
      cellWidth: fl['cellWidth'] as int,
      cellHeight: fl['cellHeight'] as int,
      sheetWidth: fl['sheetWidth'] as int,
      sheetHeight: fl['sheetHeight'] as int,
      frameLayoutRows: flRows,
      animationRows: animRows,
    );
  }
}
