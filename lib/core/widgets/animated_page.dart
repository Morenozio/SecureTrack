import 'package:flutter/material.dart';

/// A wrapper widget that provides a smooth fade + slide-up entry animation.
/// Wrap any screen's body content with this for consistent UX.
///
/// Usage:
/// ```dart
/// body: AnimatedPage(
///   child: ListView(...),
/// ),
/// ```
class AnimatedPage extends StatefulWidget {
  const AnimatedPage({super.key, required this.child});
  final Widget child;

  @override
  State<AnimatedPage> createState() => _AnimatedPageState();
}

class _AnimatedPageState extends State<AnimatedPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(curved);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.02),
      end: Offset.zero,
    ).animate(curved);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(position: _slideAnim, child: widget.child),
    );
  }
}
