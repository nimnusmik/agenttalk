import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'furniture.dart';

/// 방 배치(가구 목록) 로컬 영속화. 사용자가 꾸민 배치를 앱 재시작 후에도 유지.
/// 프로토타입용 단일 방 슬롯. 출시 시 Supabase로 이관.
class RoomStore {
  static const _key = 'noa_room_layout_v1';

  /// 저장된 배치 (없으면 null → 호출 측에서 기본 배치 사용).
  Future<List<FurnitureItem>?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => FurnitureItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> save(List<FurnitureItem> layout) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(layout.map((f) => f.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
