import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

enum ShareFormat { post, story }

class ShareCardExporter {
  /// Captures a given [widget], renders it offstage at a fixed size and scale,
  /// and exports it to a high-quality PNG.
  /// Post: 1080x1350 (logical 360x450 at 3x)
  /// Story: 1080x1920 (logical 360x640 at 3x)
  static Future<bool> exportAndShareWidget({
    required BuildContext context,
    required Widget widget,
    required String fileName,
    required String text,
    ShareFormat format = ShareFormat.post,
  }) async {
    final logicalWidth = 360.0;
    final logicalHeight = format == ShareFormat.post ? 450.0 : 640.0;

    final boundaryKey = GlobalKey();

    // The widget we want to capture wrapped in a fixed media query so it ignores device scaling.
    final captureWidget = MediaQuery(
      data: const MediaQueryData(
        size: Size(360, 900), // Max potential size
        devicePixelRatio: 1.0,
        textScaler: TextScaler.noScaling,
        padding: EdgeInsets.zero,
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          // Inherit the current theme (e.g., Sthira specific themes)
          data: Theme.of(context),
          child: RepaintBoundary(
            key: boundaryKey,
            child: SizedBox(
              width: logicalWidth,
              height: logicalHeight,
              child: widget,
            ),
          ),
        ),
      ),
    );

    // Mount it into the overlay
    final overlayState = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: -9999, // Safely off-screen
        top: -9999,
        width: logicalWidth,
        height: logicalHeight,
        child: Material(
          type: MaterialType.transparency,
          child: captureWidget,
        ),
      ),
    );

    overlayState.insert(overlayEntry);

    try {
      RenderRepaintBoundary? boundary;
      
      // Poll until the boundary is fully painted or timeout (max 2 seconds)
      for (int i = 0; i < 40; i++) {
        await Future.delayed(const Duration(milliseconds: 50));
        boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
        if (boundary != null && !boundary.debugNeedsPaint) {
          break;
        }
      }

      if (boundary == null || boundary.debugNeedsPaint) {
        throw Exception("Failed to render boundary in time.");
      }

      // Render it at 3x to get 1080 width exactly natively.
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();

      image.dispose(); // Explicit RAM sweep post capturing bytes

      if (pngBytes == null) throw Exception("Failed to encode bytes");

      final tempDir = await getTemporaryDirectory();
      // Ensure unique filename
      final file = await File('${tempDir.path}/${fileName}_${DateTime.now().millisecondsSinceEpoch}.png').create();
      await file.writeAsBytes(pngBytes);

      final xFile = XFile(file.path, mimeType: 'image/png');
      
      // ignore: deprecated_member_use
      final result = await Share.shareXFiles([xFile], text: text);
      return result.status == ShareResultStatus.success;
    } catch (e) {
      debugPrint('Error via ShareCardExporter: $e');
      return false;
    } finally {
      overlayEntry.remove();
    }
  }

  /// Legacy method for capturing directly from an active onscreen key.
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
