import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool enabled;

  const SwipeToReply({
    super.key,
    required this.child,
    required this.onReply,
    this.enabled = true,
  });

  @override
  State<SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<SwipeToReply> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _translationAnimation;
  double _dragOffset = 0.0;
  static const double _maxDragDistance = 80.0;
  static const double _triggerThreshold = 50.0;
  bool _triggered = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _translationAnimation = _controller.drive(
      Tween<Offset>(
        begin: Offset.zero,
        end: const Offset(0.12, 0.0),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    
    // Only allow swiping to the right (positive values)
    if (details.primaryDelta! > 0 || _dragOffset > 0) {
      setState(() {
        _dragOffset = (_dragOffset + details.primaryDelta!).clamp(0.0, _maxDragDistance);
        _controller.value = _dragOffset / _maxDragDistance;
      });

      if (_dragOffset >= _triggerThreshold && !_triggered) {
        HapticFeedback.lightImpact();
        _triggered = true;
      }
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;

    if (_triggered) {
      widget.onReply();
    }

    setState(() {
      _dragOffset = 0.0;
      _triggered = false;
    });

    _controller.animateTo(0.0, curve: Curves.easeOutBack);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          // Dynamic sliding reply icon background
          Positioned(
            left: 12,
            child: AnimatedOpacity(
              opacity: _dragOffset > 10 ? 1.0 : 0.0,
              duration: Duration.zero,
              child: AnimatedScale(
                scale: _triggered ? 1.2 : 1.0,
                duration: const Duration(milliseconds: 150),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(_triggered ? 0.25 : 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.reply,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
          ),
          // Swiped content
          SlideTransition(
            position: _translationAnimation,
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
