import 'package:flutter/services.dart';

/// Light haptic feedback that honours the user's setting.
abstract final class Haptics {
  /// Updated by the settings controller.
  static bool enabled = true;

  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }
}
