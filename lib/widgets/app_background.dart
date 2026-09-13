import 'package:flutter/material.dart';

/// Full-bleed gradient background shared by every screen. Deliberately a
/// plain gradient rather than image art (unlike some sibling games) — this
/// project has no bespoke background asset and generating one needs tooling
/// this machine doesn't have (see the `user_dev_machine_tooling` memory).
///
/// Colors sampled directly from `assets/title/title.png`'s own soft radial
/// glow (bright sky blue behind the logo, fading to a deeper blue at the
/// art's edges — confirmed via a PowerShell/System.Drawing pixel probe: the
/// image's own alpha channel already fades toward its corners, so it's
/// designed to sit on a matching blue field rather than a hard-edged
/// rectangle) — chosen so the home screen's title image blends into the
/// page instead of reading as a pasted-on banner. Mostly the deeper blue
/// (stop 0.35 onward) rather than the bright cyan throughout, so the white
/// text used everywhere below the title (word list, HUD, buttons) keeps
/// enough contrast — only a bright accent near the very top, same "bright
/// center fading to a darker edge" shape the title art itself uses.
class AppBackground extends StatelessWidget {
  final Widget child;
  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF3FB6F0), Color(0xFF0B4E96), Color(0xFF063867)],
          stops: [0.0, 0.35, 1.0],
        ),
      ),
      child: child,
    );
  }
}
