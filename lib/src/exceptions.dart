/// Base class for all errors thrown by `haptic_kit`.
sealed class VibrationException implements Exception {
  /// Creates an exception carrying a human-readable [message].
  const VibrationException(this.message);

  /// Human-readable description of what went wrong.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when the requested capability is not supported by the device
/// (e.g. Core Haptics on a device without the Taptic Engine, or amplitude
/// control on an older Android phone).
class UnsupportedHapticException extends VibrationException {
  /// Creates an exception describing the unsupported capability.
  const UnsupportedHapticException(super.message);
}

/// Thrown when a parameter passed to the public API is out of range or
/// otherwise invalid.
class InvalidVibrationArgumentException extends VibrationException {
  /// Creates an exception describing the rejected argument.
  const InvalidVibrationArgumentException(super.message);
}

/// Thrown when the underlying platform call fails (native exception, missing
/// plugin, channel error).
class PlatformVibrationException extends VibrationException {
  /// Creates an exception for a failed platform call, with the native
  /// error [code] when one is available.
  const PlatformVibrationException(super.message, {this.code});

  /// Native error code (for example `native_error` or `missing_plugin`), or
  /// null when the platform did not provide one.
  final String? code;
}
