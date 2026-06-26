import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../core/log.dart';
import '../data/characters.dart';
import '../data/progress_store.dart';
import 'app.dart';
import 'game_screen.dart';

/// Pick a character before playing. Each selection previews that character's
/// jump sound and persists, so it's reused everywhere (level select, deep links).
class CharacterSelectScreen extends StatefulWidget {
  const CharacterSelectScreen({super.key, required this.progress});

  final ProgressStore progress;

  @override
  State<CharacterSelectScreen> createState() => _CharacterSelectScreenState();
}

class _CharacterSelectScreenState extends State<CharacterSelectScreen> {
  late int _selected = widget.progress.selectedCharacter;

  @override
  void initState() {
    super.initState();
    Log.i('nav', 'Character select');
  }

  void _pick(GameCharacter c) {
    setState(() => _selected = c.id);
    widget.progress.setSelectedCharacter(c.id);
    Sound.setCharacter(c.id);
    Sound.jump(); // preview voice
  }

  void _start() {
    Sound.click();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(
        progress: widget.progress,
        startIndex: widget.progress.highestUnlocked,
        character: characterById(_selected),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CHOOSE YOUR RUNNER',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 200,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: kCharacterCount,
                  itemBuilder: (context, i) {
                    final c = kCharacters[i];
                    return _CharacterCard(
                      character: c,
                      selected: c.id == _selected,
                      index: i,
                      onTap: () => _pick(c),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 18, top: 4),
              child: MenuButton(
                  label: 'START', icon: Icons.play_arrow, onTap: _start),
            ),
          ],
        ),
      ),
    );
  }
}

class _CharacterCard extends StatelessWidget {
  const _CharacterCard({
    required this.character,
    required this.selected,
    required this.index,
    required this.onTap,
  });

  final GameCharacter character;
  final bool selected;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // staggered fade+slide entrance
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + index * 90),
      curve: Curves.easeOutBack,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, (1 - t) * 24), child: child),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          decoration: BoxDecoration(
            color: const Color(0xFF20294A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? character.color : Colors.white12,
              width: selected ? 3 : 1.5,
            ),
            boxShadow: selected
                ? [BoxShadow(color: character.color.withValues(alpha: 0.5), blurRadius: 14)]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomPaint(
                size: const Size(54, 64),
                painter: _AvatarPainter(character),
              ),
              const SizedBox(height: 10),
              Text(character.name,
                  style: TextStyle(
                      color: character.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 18)),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(character.tagline,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 11)),
              ),
              if (selected) ...[
                const SizedBox(height: 6),
                Icon(Icons.check_circle, color: character.color, size: 18),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Draws the same little avatar used in-game, for the picker.
class _AvatarPainter extends CustomPainter {
  _AvatarPainter(this.c);
  final GameCharacter c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * 0.7;
    final h = size.height * 0.8;
    final left = (size.width - w) / 2;
    final top = (size.height - h) / 2;
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, w, h), const Radius.circular(8));
    canvas.drawRRect(body.shift(const Offset(0, 3)), Paint()..color = c.dark);
    canvas.drawRRect(body, Paint()..color = c.color);
    final eye = Paint()..color = const Color(0xFF2B2B2B);
    canvas.drawCircle(Offset(left + w * 0.62, top + h * 0.36), 3.2, eye);
    canvas.drawCircle(Offset(left + w * 0.86, top + h * 0.36), 3.2, eye);
  }

  @override
  bool shouldRepaint(covariant _AvatarPainter old) => old.c.id != c.id;
}
