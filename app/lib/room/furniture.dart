/// 방 가구 — 처음부터 "옮길 수 있는 데이터 객체"로 설계(2B 꾸미기 에디터에서 편집·저장).
///
/// 각 가구는 격자 칸(gx, gy)에 앵커된다. 렌더(아이소 큐보이드)와 활동 매핑은
/// iso_room.dart 가 이 데이터를 읽어 처리한다.
enum FurnitureType { rug, bed, desk, sofa, lamp, plant, fridge, counter, table }

/// 가구를 스프라이트 PNG로 렌더할지 여부.
/// `app/assets/room/<type>.png` 를 채우고 pubspec 에 `assets/room/` 등록 후 true 로.
/// (false면 코드로 그린 벡터 가구 폴백 — assets/room/SPEC.md 참고)
const bool kUseFurnitureSprites = false;

/// 가구 스프라이트 경로 (파일명 = enum 이름).
String furnitureSprite(FurnitureType t) => 'assets/room/${t.name}.png';

class FurnitureItem {
  final FurnitureType type;
  final int gx;
  final int gy;
  const FurnitureItem(this.type, this.gx, this.gy);

  FurnitureItem copyWith({FurnitureType? type, int? gx, int? gy}) =>
      FurnitureItem(type ?? this.type, gx ?? this.gx, gy ?? this.gy);

  Map<String, dynamic> toJson() => {'type': type.name, 'gx': gx, 'gy': gy};

  factory FurnitureItem.fromJson(Map<String, dynamic> j) => FurnitureItem(
        FurnitureType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => FurnitureType.rug,
        ),
        (j['gx'] as num).toInt(),
        (j['gy'] as num).toInt(),
      );
}

/// 5x5 방 기본 배치. 2B에서 사용자가 바꾸면 저장된 배치로 대체된다.
const List<FurnitureItem> kDefaultLayout = [
  // 주방 코너 (뒤쪽 벽)
  FurnitureItem(FurnitureType.counter, 3, 0), // 싱크대
  FurnitureItem(FurnitureType.fridge, 4, 0), // 냉장고 (뒤 오른쪽 코너)
  // 생활 구역
  FurnitureItem(FurnitureType.bed, 0, 1), // 침대 (왼쪽 벽)
  FurnitureItem(FurnitureType.lamp, 4, 2), // 조명 (오른쪽)
  FurnitureItem(FurnitureType.rug, 2, 2), // 러그 (가운데)
  FurnitureItem(FurnitureType.desk, 0, 3), // 책상 (왼쪽 앞)
  FurnitureItem(FurnitureType.sofa, 2, 3), // 소파 (가운데, 정면)
  FurnitureItem(FurnitureType.table, 1, 4), // 커피테이블 (소파 앞 살짝 왼쪽)
  FurnitureItem(FurnitureType.plant, 4, 4), // 화분 (앞 오른쪽 코너)
];
