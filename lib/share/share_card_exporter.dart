import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ShareCardExporter {
  /// Captures a [RenderRepaintBoundary] identified by [boundaryKey], saves it to disk, and shares it.
  static Future<void> shareBoundary({
    required GlobalKey boundaryKey,
    required String fileName,
    required String text,
    double pixelRatio = 3.0,
  }) async {
    try {
      final defaultBoundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (defaultBoundary == null) return;

      final image = await defaultBoundary.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      if (pngBytes == null) return;

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/$fileName.png').create();
      await file.writeAsBytes(pngBytes);

      final xFile = XFile(file.path, mimeType: 'image/png');
      
      // ignore: deprecated_member_use
      await Share.shareXFiles([xFile], text: text);
    } catch (e) {
      debugPrint('Error sharing boundary: $e');
    }
  }
}
