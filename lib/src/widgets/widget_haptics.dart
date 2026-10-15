import 'dart:async';

import '../exceptions.dart';

/// Internal: fires a widget's haptic without awaiting it.
///
/// Widget haptics are decorative, so a device or platform that cannot play
/// them (no vibrator, no plugin on web or desktop, a native failure) must not
/// surface as an uncaught async error on every tap. Only the package's own
/// [VibrationException]s are absorbed; anything else is a bug and still
/// propagates.
void playWidgetHaptic(Future<void> haptic) {
  unawaited(
    haptic.catchError(
      (Object _) {},
      test: (Object error) => error is VibrationException,
    ),
  );
}
