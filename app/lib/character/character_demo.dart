import 'package:flutter/material.dart';

import 'character_loader.dart';
import 'character_state.dart';
import 'character_view.dart';

/// CharacterView 수동 테스트용 데모 화면.
/// 노아 아틀라스가 준비되면 이 화면으로 감정/무드 전환을 눈으로 검증한다.
class CharacterDemoScreen extends StatefulWidget {
  final String manifestAsset;
  final String atlasAsset;
  const CharacterDemoScreen({
    super.key,
    this.manifestAsset = 'assets/sprites/noa/manifest.json',
    this.atlasAsset = 'assets/sprites/noa/sprite-sheet-alpha.png',
  });

  @override
  State<CharacterDemoScreen> createState() => _CharacterDemoScreenState();
}

class _CharacterDemoScreenState extends State<CharacterDemoScreen> {
  CharacterBundle? _bundle;
  String? _error;
  Emotion _emotion = Emotion.idle;
  int _mood = 0;

  @override
  void initState() {
    super.initState();
    loadCharacterFromAssets(
      manifestAsset: widget.manifestAsset,
      atlasAsset: widget.atlasAsset,
    ).then((b) {
      if (mounted) setState(() => _bundle = b);
    }).catchError((e) {
      if (mounted) setState(() => _error = '$e');
    });
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    return Scaffold(
      appBar: AppBar(title: const Text('노아 — CharacterView 데모')),
      body: _error != null
          ? Center(child: Text('로드 실패: $_error'))
          : bundle == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: CharacterView(
                        atlas: bundle.atlas,
                        manifest: bundle.manifest,
                        emotion: _emotion,
                        moodScore: _mood,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Wrap(
                        spacing: 8,
                        children: Emotion.values
                            .map((e) => ChoiceChip(
                                  label: Text(e.name),
                                  selected: _emotion == e,
                                  onSelected: (_) =>
                                      setState(() => _emotion = e),
                                ))
                            .toList(),
                      ),
                    ),
                    Row(
                      children: [
                        const SizedBox(width: 12),
                        const Text('mood'),
                        Expanded(
                          child: Slider(
                            value: _mood.toDouble(),
                            min: -3,
                            max: 3,
                            divisions: 6,
                            label: '$_mood',
                            onChanged: (v) =>
                                setState(() => _mood = v.round()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
    );
  }
}
