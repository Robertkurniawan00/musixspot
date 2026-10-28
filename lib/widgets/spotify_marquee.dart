import 'package:flutter/material.dart';

class SpotifyMarquee extends StatefulWidget {
  final String text;
  final TextStyle style;
  final double velocity; // Pixels per second
  final Duration pauseDuration;

  const SpotifyMarquee({
    super.key,
    required this.text,
    required this.style,
    this.velocity = 32.0,
    this.pauseDuration = const Duration(milliseconds: 1800),
  });

  @override
  State<SpotifyMarquee> createState() => _SpotifyMarqueeState();
}

class _SpotifyMarqueeState extends State<SpotifyMarquee>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  AnimationController? _animController;
  bool _isOverflowing = false;
  double _overflowAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void didUpdateWidget(covariant SpotifyMarquee oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _stopAnimation();
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
    }
  }

  void _checkOverflow() {
    if (!mounted) return;

    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    final availableWidth = context.size?.width ?? 0;
    final textWidth = textPainter.width;

    if (textWidth > availableWidth && availableWidth > 0) {
      _overflowAmount = textWidth - availableWidth + 32; // Extra padding
      _isOverflowing = true;
      _startAnimation();
    } else {
      _isOverflowing = false;
      _stopAnimation();
    }
    if (mounted) setState(() {});
  }

  void _startAnimation() {
    _animController?.dispose();

    final scrollDuration = Duration(
      milliseconds: ((_overflowAmount / widget.velocity) * 1000).toInt(),
    );

    _animController = AnimationController(
      vsync: this,
      duration: scrollDuration,
    );

    _animController!.addListener(() {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_animController!.value * _overflowAmount);
      }
    });

    _loopSequence(scrollDuration);
  }

  Future<void> _loopSequence(Duration scrollDuration) async {
    while (mounted && _isOverflowing && _animController != null) {
      // 1. Pause at origin
      await Future.delayed(widget.pauseDuration);
      if (!mounted || !_isOverflowing || _animController == null) break;

      // 2. Smoothly scroll to end
      await _animController!.forward(from: 0.0);
      if (!mounted || !_isOverflowing || _animController == null) break;

      // 3. Pause at end
      await Future.delayed(widget.pauseDuration);
      if (!mounted || !_isOverflowing || _animController == null) break;

      // 4. Reset to origin
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      _animController!.reset();
    }
  }

  void _stopAnimation() {
    _animController?.stop();
    _animController?.dispose();
    _animController = null;
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }
  }

  @override
  void dispose() {
    _stopAnimation();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOverflowing) {
      return Text(
        widget.text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: widget.style,
      );
    }

    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white,
            Colors.white,
            Colors.transparent,
          ],
          stops: [0.0, 0.92, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: SingleChildScrollView(
        controller: _scrollController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.only(right: 32.0),
          child: Text(
            widget.text,
            maxLines: 1,
            style: widget.style,
          ),
        ),
      ),
    );
  }
}
