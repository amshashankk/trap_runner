import 'package:flutter/material.dart';

import '../../audio/sound.dart';
import '../../data/progress_store.dart';

/// Two independent audio toggles — music and sound-effects — used on the menu.
/// (The in-game HUD has its own compact versions.)
class SoundToggles extends StatelessWidget {
  const SoundToggles({super.key, required this.progress, this.onChanged});

  final ProgressStore progress;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Music',
          onPressed: () async {
            await Sound.setMusicEnabled(!Sound.musicEnabled);
            await progress.setMusicEnabled(Sound.musicEnabled);
            onChanged?.call();
          },
          icon: Icon(
            Sound.musicEnabled ? Icons.music_note : Icons.music_off,
            color: Sound.musicEnabled ? Colors.white : Colors.white38,
          ),
        ),
        IconButton(
          tooltip: 'Sound effects',
          onPressed: () async {
            Sound.setSfxEnabled(!Sound.sfxEnabled);
            await progress.setSfxEnabled(Sound.sfxEnabled);
            onChanged?.call();
          },
          icon: Icon(
            Sound.sfxEnabled ? Icons.volume_up : Icons.volume_off,
            color: Sound.sfxEnabled ? Colors.white : Colors.white38,
          ),
        ),
      ],
    );
  }
}
