import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provides environmental lighting for Mitra and the Sunflower
final mitraLightingProvider = Provider<ColorFilter?>((ref) {
  final hour = DateTime.now().hour;
  
  if (hour >= 17 && hour < 19) {
    // Sunset: Warm Golden Hour
    return const ColorFilter.mode(
      Color(0x33FF9800), // 20% Orange
      BlendMode.srcATop,
    );
  } else if (hour >= 19 || hour < 5) {
    // Night: Cool Moonlight Blue
    return const ColorFilter.mode(
      Color(0x442196F3), // 26% Blue
      BlendMode.srcATop,
    );
  }
  
  // Day: No filter
  return null;
});
