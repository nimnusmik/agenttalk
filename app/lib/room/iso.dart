import 'dart:ui';

/// 아이소메트릭 방 격자 설정 + 좌표 투영.
///
/// 격자 좌표 (gx, gy) — gx는 우하향 축, gy는 좌하향 축(실수 허용).
/// 화면 좌표로의 투영은 표준 2:1 다이아몬드 아이소:
///   screenX = origin.dx + (gx - gy) * tileW/2
///   screenY = origin.dy + (gx + gy) * tileH/2
class IsoConfig {
  final int cols;
  final int rows;
  final double tileW; // 마름모 한 칸 가로 폭(px)
  final double tileH; // 마름모 한 칸 세로 높이(px) = tileW/2
  final double wallH; // 벽 높이(px)
  final Offset origin; // 격자 (0,0) 꼭짓점의 화면 좌표(= 방의 가장 안쪽 모서리)

  const IsoConfig({
    required this.cols,
    required this.rows,
    required this.tileW,
    required this.tileH,
    required this.wallH,
    required this.origin,
  });

  double get halfW => tileW / 2;
  double get halfH => tileH / 2;

  Offset project(double gx, double gy) => Offset(
        origin.dx + (gx - gy) * halfW,
        origin.dy + (gx + gy) * halfH,
      );

  /// 가용 크기 안에 방이 들어가도록 맞춘 IsoConfig.
  factory IsoConfig.fit({
    required int cols,
    required int rows,
    required double availW,
    required double availH,
    double baseTileW = 64,
    double wallRatio = 3.1, // wallH = wallRatio * tileH (파니룸처럼 벽 높게)
    double topPad = 18,
  }) {
    final baseHalfW = baseTileW / 2;
    final baseTileH = baseTileW / 2;
    final baseHalfH = baseTileH / 2;
    final baseWallH = wallRatio * baseTileH;

    final sceneW = (cols + rows) * baseHalfW;
    final sceneH = (cols + rows) * baseHalfH + baseWallH;

    // 가로는 94%까지 채우고, 세로는 80% 안에서. 작은 방은 키워서 채운다.
    final fitW = (availW * 0.94) / sceneW;
    final fitH = (availH * 0.80) / sceneH;
    final scale = (fitW < fitH ? fitW : fitH).clamp(0.3, 2.4);

    final tileW = baseTileW * scale;
    final tileH = tileW / 2;
    final wallH = wallRatio * tileH;
    final halfW = tileW / 2;
    final scaledSceneH = (cols + rows) * (tileH / 2) + wallH;

    // 가로 중앙: isoX 범위 [-rows*halfW, cols*halfW]. 세로 중앙 정렬.
    final originX = availW / 2 + (rows - cols) * halfW / 2;
    final originY = (availH - scaledSceneH) / 2 + wallH + topPad;

    return IsoConfig(
      cols: cols,
      rows: rows,
      tileW: tileW,
      tileH: tileH,
      wallH: wallH,
      origin: Offset(originX, originY),
    );
  }
}
