import 'package:flutter/material.dart';

/// Full-bleed gradient background shared by every screen. Deliberately a
/// plain gradient rather than image art (unlike some sibling games) — this
/// project has no bespoke background asset and generating one needs tooling
/// this machine doesn't have (see the `user_dev_machine_tooling` memory).
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
          colors: [Color(0xFF123B57), Color(0xFF0B2436)],
        ),
      ),
      child: child,
    );
  }
}
