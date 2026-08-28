import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

class ImagePreprocessor {
  /// Downscales an image to a maximum width (maintaining aspect ratio).
  /// Uses Flutter's native codec for fast, memory-efficient decoding.
  static Future<Uint8List> downscale(Uint8List bytes, {int maxWidth = 512}) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: maxWidth);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } catch (e) {
      debugPrint('Image downsampling failed, returning original bytes: $e');
      return bytes;
    }
  }
}
