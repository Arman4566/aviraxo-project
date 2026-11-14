import 'package:flutter/material.dart';

/// One place that decides how the layout adapts, so phones, tablets, foldables and PCs all follow the same rules.
///
///  - compact  : phones in portrait (under 600 dp wide)   -> bottom bar, single column
///  - medium   : large phones in landscape, small tablets  -> side rail, content centred
///  - expanded : tablets in landscape, laptops, desktops   -> wide side rail with labels, content centred
enum ScreenSize { compact, medium, expanded }

class Responsive {
  Responsive._();

  /// Content never stretches wider than this: lines of numbers stay readable on a big monitor.
  static const double maxContentWidth = 1200;

  /// Forms, sheets and dialogs stay this narrow even on a big screen.
  static const double maxSheetWidth = 640;

  static ScreenSize sizeOf(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    if (w < 600) return ScreenSize.compact;
    if (w < 1000) return ScreenSize.medium;
    return ScreenSize.expanded;
  }

  /// True when a left-hand navigation rail fits better than a bottom bar: wide screens, or a phone turned sideways
  /// (where a bottom bar would eat a big part of the little height that is left).
  static bool useRail(BuildContext context) {
    final s = MediaQuery.sizeOf(context);
    return s.width >= 720 || (s.width > s.height && s.height < 520);
  }

  static bool isLandscape(BuildContext context) => MediaQuery.orientationOf(context) == Orientation.landscape;

  /// Horizontal page padding that grows a little on bigger screens.
  static double gutter(BuildContext context) {
    switch (sizeOf(context)) {
      case ScreenSize.compact:
        return 16;
      case ScreenSize.medium:
        return 24;
      case ScreenSize.expanded:
        return 32;
    }
  }
}

/// Keeps the app's content in a centred column on very wide screens. On phones it does nothing.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = Responsive.maxContentWidth});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}

/// A page body that fills the screen when there is room (so `Spacer` and bottom-pinned buttons still work) and scrolls when
/// there is not, for example a phone turned sideways or a small screen with a big font. Use instead of `Padding(child: Column(...))`.
class ScrollFill extends StatelessWidget {
  const ScrollFill({super.key, required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: (box.maxHeight - padding.vertical).clamp(0.0, double.infinity)),
            child: IntrinsicHeight(child: child),
          ),
        ),
      );
}
