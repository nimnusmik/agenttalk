/// 방 가구 — 처음부터 "옮길 수 있는 데이터 객체"로 설계(2B 꾸미기 에디터에서 편집·저장).
///
/// 각 가구는 격자 칸(gx, gy)에 앵커된다. 렌더(아이소 큐보이드)와 활동 매핑은
/// iso_room.dart 가 이 데이터를 읽어 처리한다.
enum FurnitureType { rug, bed, desk, sofa, lamp, plant, fridge, counter, table }

/// 가구를 스프라이트 PNG로 렌더할지 여부.
/// `app/assets/room/<type>.png` 를 채우고 pubspec 에 `assets/room/` 등록 후 true 로.
/// (false면 코드로 그린 벡터 가구 폴백 — assets/room/SPEC.md 참고)
const bool kUseFurnitureSprites = true;

/// 가구 스프라이트 경로 (파일명 = enum 이름).
String furnitureSprite(FurnitureType t) => 'assets/room/${t.name}.png';

class FurnitureItem {
  final FurnitureType type;
  final int gx;
  final int gy;

  /// 좌우반전 — 스프라이트가 한 방향(정면-오른쪽)만 보므로, 뒤 오른쪽 벽 가구 등은
  /// 이 값을 true로 줘서 방 안쪽(왼쪽-앞)을 보게 한다.
  final bool flipX;
  const FurnitureItem(this.type, this.gx, this.gy, {this.flipX = false});

  FurnitureItem copyWith({FurnitureType? type, int? gx, int? gy, bool? flipX}) =>
      FurnitureItem(type ?? this.type, gx ?? this.gx, gy ?? this.gy,
          flipX: flipX ?? this.flipX);

  Map<String, dynamic> toJson() =>
      {'type': type.name, 'gx': gx, 'gy': gy, 'flipX': flipX};

  factory FurnitureItem.fromJson(Map<String, dynamic> j) => FurnitureItem(
        FurnitureType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => FurnitureType.rug,
        ),
        (j['gx'] as num).toInt(),
        (j['gy'] as num).toInt(),
        flipX: j['flipX'] as bool? ?? false,
      );
}

/// 6x6 방 기본 배치 — 구역(수면/주방/작업/거실)으로 묶고 가운데 동선은 비움(파니룸 무드).
/// 2B에서 사용자가 바꾸면 저장된 배치로 대체된다.
const List<FurnitureItem> kDefaultLayout = [
  // ── 수면 zone: 뒤 왼쪽 코너(벽 액자 아래) ──
  FurnitureItem(FurnitureType.bed, 0, 1),
  // ── 주방 zone: 뒤 오른쪽 벽(gy=0, 창문 아래). 벽 등지게 좌우반전 ──
  FurnitureItem(FurnitureType.counter, 3, 0, flipX: true), // 싱크대
  FurnitureItem(FurnitureType.fridge, 4, 0, flipX: true), // 냉장고
  // ── 작업 zone: 앞 왼쪽(좌측 벽) ──
  FurnitureItem(FurnitureType.desk, 0, 4),
  // ── 거실 zone: 가운데~정면, 러그로 묶고 소파가 테이블을 바라봄 ──
  FurnitureItem(FurnitureType.rug, 3, 4), // 거실 앵커(가구 밑에 깔림)
  FurnitureItem(FurnitureType.sofa, 2, 3), // 소파 — 정면(테이블) 바라봄
  FurnitureItem(FurnitureType.table, 3, 5), // 커피테이블 = 소파 초점
  FurnitureItem(FurnitureType.lamp, 4, 4), // 스탠드 — 소파 옆 조명(가려지지 않게 앞으로)
  FurnitureItem(FurnitureType.plant, 5, 4), // 화분 — 우측 그린 액센트
];
