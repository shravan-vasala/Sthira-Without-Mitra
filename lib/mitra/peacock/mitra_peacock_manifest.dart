import 'package:flutter/material.dart';

enum PeacockGrandDisplayState {
  ready,
  opening,
  settle,
  idle,
  closing,
}

class MitraPeacockFrame {
  final String id;
  final String asset;
  final Duration duration;

  const MitraPeacockFrame({
    required this.id,
    required this.asset,
    required this.duration,
  });
}

class MitraPeacockManifest {
  static const double canvasWidth = 1536.0;
  static const double canvasHeight = 1024.0;

  // CANONICAL PIVOT: Body Center X, Foot Contact Y
  // Derived roughly from READY frame bounds (x: 571-969 -> center 770). 
  // We will fine-tune this with the debug overlay.
  static const double pivotX = 770.0;
  static const double pivotY = 950.0;

  // Calculates the alignment needed to keep the pivot stationary
  static Alignment get alignment {
    // Alignment goes from -1.0 to 1.0
    final x = (pivotX / (canvasWidth / 2)) - 1.0;
    final y = (pivotY / (canvasHeight / 2)) - 1.0;
    return Alignment(x, y);
  }

  // Fractional offset version (0.0 to 1.0)
  static FractionalOffset get fractionalOffset {
    return FractionalOffset(
      pivotX / canvasWidth,
      pivotY / canvasHeight,
    );
  }

  static const List<MitraPeacockFrame> openingSequence = [
    MitraPeacockFrame(id: 'READY', asset: 'assets/mitra/peacock/PEACOCK_DISPLAY_READY_01.png', duration: Duration(milliseconds: 220)),
    MitraPeacockFrame(id: 'OPEN_01', asset: 'assets/mitra/peacock/PEACOCK_DISPLAY_OPEN_01.png', duration: Duration(milliseconds: 180)),
    MitraPeacockFrame(id: 'OPEN_02', asset: 'assets/mitra/peacock/PEACOCK_DISPLAY_OPEN_02.png', duration: Duration(milliseconds: 160)),
    MitraPeacockFrame(id: 'OPEN_03', asset: 'assets/mitra/peacock/PEACOCK_DISPLAY_OPEN_03.png', duration: Duration(milliseconds: 200)),
    MitraPeacockFrame(id: 'OPEN_04', asset: 'assets/mitra/peacock/PEACOCK_GRAND_DISPLAY_OPEN_04.png', duration: Duration(milliseconds: 280)),
  ];

  static const List<MitraPeacockFrame> settleSequence = [
    MitraPeacockFrame(id: 'SETTLE_01', asset: 'assets/mitra/peacock/PEACOCK_GRAND_DISPLAY_SETTLE_01.png', duration: Duration(milliseconds: 280)),
  ];

  // --- PHASE 2: PERSONALITY BEHAVIOUR FRAMES ---
  static const MitraPeacockFrame heroFrame = MitraPeacockFrame(id: 'HERO', asset: 'assets/mitra/peacock/PEACOCK_GRAND_DISPLAY_IDLE_01.png', duration: Duration(milliseconds: 350));
  static const MitraPeacockFrame blinkFrame = MitraPeacockFrame(id: 'BLINK', asset: 'assets/mitra/peacock/PEACOCK_GRAND_DISPLAY_BLINK_01.png', duration: Duration(milliseconds: 150));
  static const MitraPeacockFrame lookLeftFrame = MitraPeacockFrame(id: 'LOOK_LEFT', asset: 'assets/mitra/peacock/PEACOCK_GRAND_DISPLAY_LOOK_LEFT_01.png', duration: Duration(milliseconds: 300));
  static const MitraPeacockFrame lookRightFrame = MitraPeacockFrame(id: 'LOOK_RIGHT', asset: 'assets/mitra/peacock/PEACOCK_GRAND_DISPLAY_LOOK_RIGHT_01.png', duration: Duration(milliseconds: 300));
  static const MitraPeacockFrame lookUpFrame = MitraPeacockFrame(id: 'LOOK_UP', asset: 'assets/mitra/peacock/PEACOCK_GRAND_DISPLAY_LOOK_UP_01.png', duration: Duration(milliseconds: 300));
  static const MitraPeacockFrame lookDownFrame = MitraPeacockFrame(id: 'LOOK_DOWN', asset: 'assets/mitra/peacock/PEACOCK_GRAND_DISPLAY_LOOK_DOWN_01.png', duration: Duration(milliseconds: 300));
  static const MitraPeacockFrame winkFrame = MitraPeacockFrame(id: 'WINK', asset: 'assets/mitra/peacock/PEACOCK_GRAND_DISPLAY_WINK_01.png', duration: Duration(milliseconds: 300));

  // The static idle sequence is now obsolete. The controller will build it dynamically.
  // We keep it empty or remove it. We'll remove it.

  static const List<MitraPeacockFrame> closingSequence = [
    MitraPeacockFrame(id: 'CLOSE_01', asset: 'assets/mitra/peacock/PEACOCK_GRAND_DISPLAY_CLOSE_01.png', duration: Duration(milliseconds: 180)),
    MitraPeacockFrame(id: 'CLOSE_02', asset: 'assets/mitra/peacock/PEACOCK_GRAND_DISPLAY_CLOSE_02.png', duration: Duration(milliseconds: 170)),
    MitraPeacockFrame(id: 'CLOSE_03', asset: 'assets/mitra/peacock/PEACOCK_GRAND_DISPLAY_CLOSE_03.png', duration: Duration(milliseconds: 180)),
    MitraPeacockFrame(id: 'CLOSE_04', asset: 'assets/mitra/peacock/PEACOCK_GRAND_DISPLAY_CLOSE_04.png', duration: Duration(milliseconds: 200)),
    MitraPeacockFrame(id: 'READY', asset: 'assets/mitra/peacock/PEACOCK_DISPLAY_READY_01.png', duration: Duration(milliseconds: 250)),
  ];
}
