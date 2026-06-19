import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;

import 'sprite_manifest.dart';

class CharacterBundle {
  final ui.Image atlas;
  final SpriteManifest manifest;
  const CharacterBundle({required this.atlas, required this.manifest});
}

/// assets 에서 manifest.json + 아틀라스 PNG 로드.
/// pubspec.yaml 의 `flutter.assets` 에 두 파일 경로를 등록해야 한다.
Future<CharacterBundle> loadCharacterFromAssets({
  required String manifestAsset, // 예: assets/sprites/noa/manifest.json
  required String atlasAsset, //     예: assets/sprites/noa/sprite-sheet-alpha.png
}) async {
  final manifestStr = await rootBundle.loadString(manifestAsset);
  final manifest = SpriteManifest.fromJsonString(manifestStr);

  final bytes = await rootBundle.load(atlasAsset);
  final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  return CharacterBundle(atlas: frame.image, manifest: manifest);
}
