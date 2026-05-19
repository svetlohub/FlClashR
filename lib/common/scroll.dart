import 'dart:math';
import 'dart:ui';

import 'package:flclashx/common/common.dart';
import 'package:flclashx/widgets/scroll.dart';
import 'package:flutter/material.dart';

/// Accepts touch, stylus, trackpad, and mouse (desktop only) as drag devices.
class BaseScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.invertedStylus,
        PointerDeviceKind.trackpad,
        if (system.isDesktop) PointerDeviceKind.mouse,
        PointerDeviceKind.unknown,
      };
}

/// No scrollbar — used for tab bodies and inner lists.
class HiddenBarScrollBehavior extends BaseScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) => child;
}

/// Auto-hiding scrollbar.
class ShowBarScrollBehavior extends BaseScrollBehavior {
  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) =>
      CommonAutoHiddenScrollBar(controller: details.controller, child: child);
}

/// Clamping physics with a spring snap when out-of-range instead of an
/// abrupt stop. Feels closer to native Android on desktop.
class NextClampingScrollPhysics extends ClampingScrollPhysics {
  const NextClampingScrollPhysics({super.parent});

  @override
  NextClampingScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      NextClampingScrollPhysics(parent: buildParent(ancestor));

  @override
  Simulation? createBallisticSimulation(ScrollMetrics pos, double velocity) {
    final tol = toleranceFor(pos);
    if (pos.outOfRange) {
      final end = pos.pixels > pos.maxScrollExtent
          ? pos.maxScrollExtent
          : pos.minScrollExtent;
      return ScrollSpringSimulation(spring, end, end, min(0.0, velocity),
          tolerance: tol);
    }
    if (velocity.abs() < tol.velocity) return null;
    if (velocity > 0.0 && pos.pixels >= pos.maxScrollExtent) return null;
    if (velocity < 0.0 && pos.pixels <= pos.minScrollExtent) return null;
    return ClampingScrollSimulation(
        position: pos.pixels, velocity: velocity, tolerance: tol);
  }
}

/// A scroll controller that initialises at the bottom of the list.
class ReverseScrollController extends ScrollController {
  ReverseScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  @override
  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) =>
      _ReverseScrollPosition(
        physics: physics,
        context: context,
        initialPixels: initialScrollOffset,
        keepScrollOffset: keepScrollOffset,
        oldPosition: oldPosition,
        debugLabel: debugLabel,
      );
}

class _ReverseScrollPosition extends ScrollPositionWithSingleContext {
  _ReverseScrollPosition({
    required super.physics,
    required super.context,
    super.initialPixels = 0.0,
    super.keepScrollOffset,
    super.oldPosition,
    super.debugLabel,
  });

  bool _initialised = false;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    if (!_initialised) {
      correctPixels(maxScrollExtent);
      _initialised = true;
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}
