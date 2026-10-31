import 'package:flutter/material.dart';

/// Same entrance as charity_trust `fadeSlideInFromBottom`:
/// fade in while rising 50px, 300ms, easeOut.
class PageLoadAnimation extends StatefulWidget {
  const PageLoadAnimation({super.key, required this.child});

  final Widget child;

  @override
  State<PageLoadAnimation> createState() => _PageLoadAnimationState();
}

class _PageLoadAnimationState extends State<PageLoadAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      child: widget.child,
      builder: (context, child) {
        final t = _animation.value;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * 50),
            child: child,
          ),
        );
      },
    );
  }
}
