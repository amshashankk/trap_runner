import 'package:flutter/material.dart';

/// Tuning constants for game feel and layout. Levels are authored at a fixed
/// 30x17 tile grid (32px tiles) so a whole level fits on screen with no scroll.
class Config {
  static const double tileSize = 32;
  static const int mapWidth = 30;
  static const int mapHeight = 17;
  static double get worldWidth => mapWidth * tileSize; // 960
  static double get worldHeight => mapHeight * tileSize; // 544

  // Player physics (px, px/s, px/s^2). Tuned for a tight, snappy feel with a
  // generous jump so the player can clear ~3.5 tiles up and ~4 tiles across.
  static const double gravity = 1800;
  static const double maxFallSpeed = 820;
  static const double moveSpeed = 190;
  static const double jumpSpeed = 680; // ~128px peak => clears ~3.7 tiles up
  static const double airControl = 0.85;
  static const double coyoteTime = 0.11; // grace after leaving a ledge
  static const double jumpBuffer = 0.13; // grace before landing
  static const double jumpCutMultiplier = 0.45; // variable-height jump

  // Derived jump reach used by the level generator to keep levels solvable.
  // peak height = jumpSpeed^2 / (2*gravity); airtime = 2*jumpSpeed/gravity.
  static const int maxJumpUpTiles = 3; // safe vertical step the player can make
  static const int maxJumpGapTiles = 4; // safe horizontal gap to clear

  static const double playerWidth = 22;
  static const double playerHeight = 28;

  static const int livesPerLevel = 3;

  // Palette
  static const Color sky = Color(0xFF2B3A67);
  static const Color skyLow = Color(0xFF496A9C);
  static const Color player = Color(0xFFFFD166);
  static const Color playerDark = Color(0xFFE0A93B);
  static const Color spike = Color(0xFFD64545);
  static const Color crusher = Color(0xFF8A8FA3);
  static const Color crusherTeeth = Color(0xFFB94A4A);
  static const Color mover = Color(0xFF6BCB77);
  static const Color gate = Color(0xFF9B5DE5);
  static const Color exit = Color(0xFF45D6A0);
  static const Color accent = Color(0xFFFFD166);
}
