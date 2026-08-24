import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provides the absolute X coordinate of Mitra in the global overlay.
// MitraIdleEngine modifies this during the 'pass' phase of a walk cycle,
// ensuring that the character only translates horizontally when the foot is lifted.
final mitraGlobalXProvider = StateProvider<double>((ref) => 16.0);

// Provides the absolute Y height above the ground plane (0.0 is on the ground).
final mitraGlobalYProvider = StateProvider<double>((ref) => 0.0);
