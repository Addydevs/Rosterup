import 'package:flutter/material.dart';

/// Convenience extensions on [BuildContext] for theme-aware colors that work
/// correctly in both light and dark mode.
extension ThemeColors on BuildContext {
  ColorScheme get _cs => Theme.of(this).colorScheme;

  /// Card / elevated surface background.
  /// Light: white, Dark: dark surface container.
  Color get cardColor => _cs.surfaceContainerLow;

  /// Subtle tinted background for info banners, schedules, etc.
  /// Light: grey.shade50, Dark: slightly elevated surface.
  Color get subtleFill => _cs.surfaceContainerHighest;

  /// Standard border/divider color for cards and containers.
  /// Light: grey.shade200, Dark: outlineVariant.
  Color get borderColor => _cs.outlineVariant;

  /// Drag-handle / pill color for bottom sheets.
  /// Light: grey.shade300, Dark: slightly lighter outline.
  Color get handleColor => _cs.outline;

  /// Unselected / deselected chip/button background.
  /// Light: grey.shade100, Dark: surfaceContainerHigh.
  Color get chipBackground => _cs.surfaceContainerHigh;
}
