import 'dart:isolate';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'ai_profiler.dart';

class ImagePreprocessor {
  /// Downscales an image so the longest side is 1024px and encodes as JPEG.
  /// Uses a background isolate. Returns (bytes, mimeType, hash).
  static Future<(Uint8List, String, String)> processImage(
    Uint8List bytes,
    String fallbackMimeType,
  ) async {
    try {
      // Cheap guard: If it's under 1MB and already within target dimensions,
      // pass it through without expensive pixel decoding.
      if (bytes.length < 1024 * 1024) {
        try {
          final info = img.JpegDecoder().decodeInfo(bytes);
          if (info != null && info.width <= 1024 && info.height <= 1024) {
            AiProfiler().startPhase('hashMs');
            final hash = sha256.convert(bytes).toString();
            AiProfiler().endPhase('hashMs');
            return (bytes, 'image/jpeg', hash);
          }
        } catch (_) {
          // Not a JPEG or invalid header, proceed to full isolate decode
        }
      }
      final result = await Isolate.run(() {
        final image = img.decodeImage(bytes);
        if (image == null) throw Exception('Cannot decode image');

        int width = image.width;
        int height = image.height;

        if (width > 1024 || height > 1024) {
          if (width > height) {
            height = (height * 1024 ~/ width);
            width = 1024;
          } else {
            width = (width * 1024 ~/ height);
            height = 1024;
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
      }).timeout(const Duration(seconds: 10));
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
