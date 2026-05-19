import 'package:flutter/material.dart';

/// Measures text sizes using the current theme and text scaler.
/// Results are cached per style key to avoid redundant layout passes.
class Measure {
  Measure.of(this.context, double textScaleFactor)
      : _scaler = TextScaler.linear(textScaleFactor);

  final BuildContext context;
  final TextScaler _scaler;
  final _cache = <String, double>{};

  /// Returns the line height for the given [style], caching by [key].
  double _lineHeight(String key, TextStyle? style) =>
      _cache.putIfAbsent(key, () => _measure('X', style).height);

  Size _measure(String text, TextStyle? style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textScaler: _scaler,
      textDirection: TextDirection.ltr,
    )..layout();
    return painter.size;
  }

  // ─── Convenience getters ──────────────────────────────────────────────────

  double get bodyMediumHeight  => _lineHeight('bodyMedium',  context.textTheme.bodyMedium);
  double get bodyLargeHeight   => _lineHeight('bodyLarge',   context.textTheme.bodyLarge);
  double get bodySmallHeight   => _lineHeight('bodySmall',   context.textTheme.bodySmall);
  double get labelSmallHeight  => _lineHeight('labelSmall',  context.textTheme.labelSmall);
  double get labelMediumHeight => _lineHeight('labelMedium', context.textTheme.labelMedium);
  double get titleLargeHeight  => _lineHeight('titleLarge',  context.textTheme.titleLarge);
  double get titleMediumHeight => _lineHeight('titleMedium', context.textTheme.titleMedium);

  /// Measures arbitrary text with an explicit style.
  Size computeTextSize(Text widget, {double maxWidth = double.infinity}) {
    final painter = TextPainter(
      text: TextSpan(text: widget.data, style: widget.style),
      maxLines: widget.maxLines,
      textScaler: _scaler,
      textDirection: widget.textDirection ?? TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    return painter.size;
  }
}
