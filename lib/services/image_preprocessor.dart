import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'ai_profiler.dart';

class ImagePreprocessor {
  /// Downscales an image so the longest side is 1280px and encodes as JPEG.
  /// Uses a background isolate. Returns (bytes, mimeType, hash).
  static Future<(Uint8List, String, String)> processImage(
    Uint8List bytes,
    String fallbackMimeType,
  ) async {
    try {
      final result = await Isolate.run(() {
        final image = img.decodeImage(bytes);
        if (image == null) throw Exception('Cannot decode image');

        int width = image.width;
        int height = image.height;

        if (width > 1280 || height > 1280) {
          if (width > height) {
            height = (height * 1280 ~/ width);
            width = 1280;
          } else {
            width = (width * 1280 ~/ height);
            height = 1280;
          }
          final resized = img.copyResize(image, width: width, height: height);
          final encoded = img.encodeJpg(resized, quality: 85);
          final processedBytes = Uint8List.fromList(encoded);
          final hash = sha256.convert(processedBytes).toString();
          return (processedBytes, 'image/jpeg', hash);
        } else {
          final encoded = img.encodeJpg(image, quality: 85);
          final processedBytes = Uint8List.fromList(encoded);
          final hash = sha256.convert(processedBytes).toString();
          return (processedBytes, 'image/jpeg', hash);
        }
      });
      return result;
    } catch (e) {
      debugPrint('Image processing failed, returning original bytes: $e');
      AiProfiler().startPhase('hashMs');
      final fallbackHash = sha256.convert(bytes).toString();
      AiProfiler().endPhase('hashMs');
      return (bytes, fallbackMimeType, fallbackHash);
    }
  }
}
