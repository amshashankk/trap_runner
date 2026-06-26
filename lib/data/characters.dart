import 'package:flutter/material.dart';

/// A playable character. Each has its own colour scheme (used to draw the
/// avatar) and its own set of sound effects (files `c<id>_jump/die/fall/win`).
class GameCharacter {
  const GameCharacter({
    required this.id,
    required this.name,
    required this.tagline,
    required this.color,
    required this.dark,
  });

  final int id;
  final String name;
  final String tagline;
  final Color color;
  final Color dark;

  /// sfx asset prefix, e.g. 'c0' -> c0_jump.wav, c0_die.wav, ...
  String get sfx => 'c$id';
}

const List<GameCharacter> kCharacters = [
  GameCharacter(
    id: 0,
    name: 'Blip',
    tagline: 'The original. Springy and bright.',
    color: Color(0xFFFFD166),
    dark: Color(0xFFE0A93B),
  ),
  GameCharacter(
    id: 1,
    name: 'Vox',
    tagline: 'Heavy steps, low rumble.',
    color: Color(0xFF6BCB77),
    dark: Color(0xFF3FA45A),
  ),
  GameCharacter(
    id: 2,
    name: 'Pixel',
    tagline: 'Quick, chirpy, fearless.',
    color: Color(0xFF4CC9F0),
    dark: Color(0xFF2F8FB8),
  ),
  GameCharacter(
    id: 3,
    name: 'Zap',
    tagline: 'Buzzy and a little chaotic.',
    color: Color(0xFFF06595),
    dark: Color(0xFFC64477),
  ),
];

int get kCharacterCount => kCharacters.length;

GameCharacter characterById(int id) =>
    kCharacters.firstWhere((c) => c.id == id, orElse: () => kCharacters.first);
