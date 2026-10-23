import 'dart:ui' show ImageFilter;

import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../theme/gp_colors.dart';

/// Soft gradient with a few colour glows. Everything translucent in the app sits on top of this, which is what
/// makes the "frosted glass" cards look like glass. Light and dark have their own versions.
class GlassBackdrop extends StatelessWidget {
  const GlassBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    final d = GPColors.dark;
    final base = d
        ? const [Color(0xFF070B18), Color(0xFF0E1530), Color(0xFF0A1224)]
        : const [Color(0xFFE9EEFF), Color(0xFFF6F1FF), Color(0xFFE4F6F3)];
    Widget glow(Alignment at, Color c, double radius) => DecoratedBox(
          decoration: BoxDecoration(gradient: RadialGradient(center: at, radius: radius, colors: [c, c.withValues(alpha: 0)])),
          child: const SizedBox.expand(),
        );
    return Stack(fit: StackFit.expand, children: [
      DecoratedBox(
        decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: base)),
        child: const SizedBox.expand(),
      ),
      glow(const Alignment(0.9, -0.85), d ? const Color(0x664F46E5) : const Color(0x554F46E5), 0.9),
      glow(const Alignment(-1.0, 0.75), d ? const Color(0x4014B8A6) : const Color(0x4414B8A6), 0.85),
      glow(const Alignment(0.8, 1.0), d ? const Color(0x40A855F7) : const Color(0x33EC4899), 0.7),
    ]);
  }
}

/// iPhone-style page slide. Every page carries its own copy of the backdrop, so see-through screens never show the
/// previous page behind them while sliding.
class GlassPageTransitions extends PageTransitionsBuilder {
  const GlassPageTransitions();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondary, Widget child) {
    return const CupertinoPageTransitionsBuilder().buildTransitions<T>(
      route, context, animation, secondary,
      Stack(fit: StackFit.expand, children: [const GlassBackdrop(), child]),
    );
  }
}

/// A panel of frosted glass: blurs whatever is behind it, tints it, and draws a bright rim.
/// Use for things that float above content (sheets, the drawer, bars). Normal cards just use GPColors.surface.
class GlassBox extends StatelessWidget {
  const GlassBox({super.key, required this.child, this.radius = 24, this.blur = 24, this.padding, this.opacityBoost = 0});
  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final double opacityBoost;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: GPColors.surface.withValues(alpha: (GPColors.surface.a + opacityBoost).clamp(0.0, 1.0)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: GPColors.glassEdge),
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        ),
      ),
    );
  }
}

/// showModalBottomSheet with a frosted-glass sheet. Same arguments as the normal one that this app uses.
Future<T?> showGlassSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool showDragHandle = true,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: useSafeArea,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    backgroundColor: Colors.transparent,
    elevation: 0,
    barrierColor: Colors.black.withValues(alpha: GPColors.dark ? 0.55 : 0.28),
    builder: (ctx) => ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: GPColors.glassSolid.withValues(alpha: GPColors.dark ? 0.78 : 0.82),
            border: Border(top: BorderSide(color: GPColors.glassEdge, width: 1.2)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (showDragHandle)
              Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 38,
                height: 5,
                decoration: BoxDecoration(color: GPColors.ink2.withValues(alpha: 0.45), borderRadius: BorderRadius.circular(3)),
              ),
            Flexible(child: builder(ctx)),
          ]),
        ),
      ),
    ),
  );
}
