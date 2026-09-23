// lib/theme/tokens.dart
//
// One place for colour, type, spacing and shape.
//
// What this replaces: every screen declared its own `const _bg = Color(...)`
// at the top of the file, so there were a dozen slightly different greens, six
// card styles, and no type scale at all. Changing the look meant editing
// twenty files and missing three.
//
// The visual direction, and the reasoning behind it:
//
//   • Depth comes from surface tint, not outlines. The old UI drew a 1px
//     border around everything, which is what dates it most — a stack of
//     outlined boxes reads as a 2014 Material app. Lighter surfaces on a dark
//     background do the same job and get out of the way.
//
//   • One accent, used sparingly. The old primary cards were saturated
//     purple, magenta and orange gradients that fought each other and had
//     nothing to do with a botanical garden. A single living green carries
//     every action; amber appears only for points and awards.
//
//   • Air. Bigger gutters, bigger radii, bigger tap targets. Most of what
//     reads as "modern" is simply space.
//
//   • Emoji stay in content, never in chrome. A 🌿 in a section heading is
//     decoration; an icon is a sign.

import 'package:flutter/material.dart';

/// Colours. Dark-first — the app is used at dusk in a greenhouse, and this one
/// is used at a night event.
abstract final class C {
  /// Page background. Near-black with a green cast, so photographs of plants
  /// sit on it without looking cut out.
  static const bg = Color(0xFF0A1410);

  /// Resting card.
  static const surface = Color(0xFF111C16);

  /// A card on a card, or a pressed state.
  static const surfaceAlt = Color(0xFF18251E);

  /// Hairline, for the rare case where two surfaces of the same tint meet.
  /// Deliberately barely visible: if a divider is doing heavy lifting, the
  /// layout needs space, not a line.
  static const line = Color(0x14FFFFFF);

  /// The one accent. Actions, progress, anything live.
  static const accent = Color(0xFF4ADE80);
  static const accentDim = Color(0xFF22C55E);

  /// Accent at low opacity, for tinted icon tiles and selected chips.
  static const accentWash = Color(0x1F4ADE80);

  /// Points, badges, anything earned. Never used for a plain action, so that
  /// gold always means the same thing.
  static const gold = Color(0xFFFBBF24);
  static const goldWash = Color(0x1FFBBF24);

  /// Live now, urgent, waiting on someone.
  static const hot = Color(0xFFFB7185);
  static const hotWash = Color(0x1FFB7185);

  static const textHi = Color(0xFFECFDF5);
  static const text = Color(0xFFCBDDD2);
  static const textSoft = Color(0xFF8FA99A);
  static const textFaint = Color(0xFF63796E);

  static const danger = Color(0xFFF87171);
}

/// Spacing scale. Four-point grid; use the names, not the numbers.
abstract final class Sp {
  static const xs = 4.0;
  static const s = 8.0;
  static const m = 12.0;
  static const l = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const huge = 40.0;

  /// Side gutter for every screen. Wider than the old 16 — the single biggest
  /// change in how modern the app feels.
  static const gutter = 20.0;
}

/// Corner radii. Larger than before and consistent, which is most of what
/// separates a considered UI from an assembled one.
abstract final class R {
  static const s = 12.0;
  static const m = 18.0;
  static const l = 24.0;
  static const pill = 999.0;

  static BorderRadius get rs => BorderRadius.circular(s);
  static BorderRadius get rm => BorderRadius.circular(m);
  static BorderRadius get rl => BorderRadius.circular(l);
}

/// Type scale. Real hierarchy: the old UI ran almost everything at 12-14pt,
/// which is why nothing looked important.
abstract final class T {
  static const display = TextStyle(
    color: C.textHi,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.6,
    height: 1.15,
  );

  static const h1 = TextStyle(
    color: C.textHi,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.25,
  );

  static const h2 = TextStyle(
    color: C.textHi,
    fontSize: 17,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.1,
    height: 1.3,
  );

  static const body = TextStyle(
    color: C.text,
    fontSize: 15,
    height: 1.5,
  );

  static const bodySm = TextStyle(
    color: C.textSoft,
    fontSize: 13.5,
    height: 1.45,
  );

  static const label = TextStyle(
    color: C.textSoft,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
  );

  /// Section headings. Uppercase with wide tracking reads as a label rather
  /// than competing with the content beneath it.
  static const overline = TextStyle(
    color: C.textFaint,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
  );

  static const numeral = TextStyle(
    color: C.gold,
    fontSize: 26,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
  );
}

/// Shadows. One, soft and low — a dark UI needs almost none, and heavy drop
/// shadows are the other half of what dates the old design.
abstract final class Sh {
  static const card = [
    BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6)),
  ];

  static List<BoxShadow> glow(Color c) => [
        BoxShadow(color: c.withValues(alpha: 0.22), blurRadius: 24, spreadRadius: -4),
      ];
}
