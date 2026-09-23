// lib/widgets/ui_kit.dart
//
// The small set of pieces every screen is built from.
//
// Before this, each screen hand-rolled its own card: different padding,
// different radius, different border, different way of showing an icon. The
// inconsistency is most of what made the app feel homemade. These are the
// shapes; screens supply the content.

import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A plain raised surface. No border — depth comes from tint.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(Sp.l),
    this.onTap,
    this.color,
    this.radius,
    this.accent,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  final double? radius;

  /// Tints the card and adds a soft glow. For the one card on a screen that
  /// should pull the eye — never for all of them.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius ?? R.m);
    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? (accent == null ? C.surface : C.surfaceAlt),
        borderRadius: r,
        boxShadow: accent == null ? null : Sh.glow(accent!),
      ),
      child: child,
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: r,
        onTap: onTap,
        splashColor: C.accent.withValues(alpha: 0.06),
        highlightColor: C.accent.withValues(alpha: 0.04),
        child: body,
      ),
    );
  }
}

/// A squared, tinted icon holder. Replaces the emoji that used to sit at the
/// front of every row.
class IconTile extends StatelessWidget {
  const IconTile(this.icon, {super.key, this.color = C.accent, this.size = 46});

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(size * 0.32),
        ),
        child: Icon(icon, color: color, size: size * 0.48),
      );
}

/// The main way into something: icon, title, one line of why, chevron.
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color = C.accent,
    this.trailing,
    this.featured = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;
  final Widget? trailing;

  /// Larger, tinted, glowing. At most one per screen.
  final bool featured;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      accent: featured ? color : null,
      padding: EdgeInsets.all(featured ? Sp.l + 2 : Sp.l),
      child: Row(
        children: [
          IconTile(icon, color: color, size: featured ? 52 : 46),
          const SizedBox(width: Sp.l),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: featured
                        ? T.h1.copyWith(fontSize: 19)
                        : T.h2),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: T.bodySm,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          trailing ??
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: C.textFaint),
        ],
      ),
    );
  }
}

/// Half-width tile for the secondary grid.
class MiniTile extends StatelessWidget {
  const MiniTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.color = C.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(Sp.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon, color: color, size: 40),
          const SizedBox(height: Sp.m),
          Text(title, style: T.h2.copyWith(fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle,
              style: T.bodySm.copyWith(fontSize: 12.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Section heading, optionally with an action on the right.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing, this.color});

  final String text;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Sp.m),
        child: Row(
          children: [
            Expanded(
              child: Text(text.toUpperCase(),
                  style: T.overline.copyWith(color: color)),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

/// Small rounded label. Counts, states, tags.
class Pill extends StatelessWidget {
  const Pill(
    this.text, {
    super.key,
    this.color = C.accent,
    this.icon,
    this.filled = false,
  });

  final String text;
  final Color color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: filled ? 1 : 0.13),
          borderRadius: BorderRadius.circular(R.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: filled ? C.bg : color),
              const SizedBox(width: 5),
            ],
            Text(text,
                style: TextStyle(
                    color: filled ? C.bg : color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

/// A pulsing dot. Used only for something genuinely happening right now.
class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.color = C.hot, this.size = 8});
  final Color color;
  final double size;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: widget.color.withValues(alpha: 0.6), blurRadius: 8),
            ],
          ),
        ),
      );
}

/// Full-width primary button.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = C.accent,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: enabled ? color : C.surfaceAlt,
          foregroundColor: enabled ? C.bg : C.textFaint,
          disabledBackgroundColor: C.surfaceAlt,
          disabledForegroundColor: C.textFaint,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: R.rm),
        ),
        onPressed: enabled ? onPressed : null,
        child: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: C.textFaint))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 19),
                    const SizedBox(width: Sp.s),
                  ],
                  Text(label,
                      style: const TextStyle(
                          fontSize: 15.5, fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
  }
}

/// Empty state. One icon, one line, no apology.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(Sp.huge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 34, color: C.textFaint),
              const SizedBox(height: Sp.m),
              Text(text,
                  textAlign: TextAlign.center,
                  style: T.bodySm.copyWith(height: 1.55)),
            ],
          ),
        ),
      );
}
