import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../theme/app_colors.dart';
import 'widgets/daily_share_card.dart';

class SharePreviewSheet extends ConsumerStatefulWidget {
  const SharePreviewSheet({super.key});

  @override
  ConsumerState<SharePreviewSheet> createState() => _SharePreviewSheetState();
}

class _SharePreviewSheetState extends ConsumerState<SharePreviewSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareImage() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);
    try {
      // 1. Capture the image from RepaintBoundary
      final boundary = _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final pngBytes = byteData?.buffer.asUint8List();
      
      if (pngBytes == null) return;

      // 2. Save it to a temporary file
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/sthira_daily_status.png').create();
      await file.writeAsBytes(pngBytes);

      // 3. Share the file via OS Share Sheet
      final xFile = XFile(file.path, mimeType: 'image/png');
      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [xFile],
        text: 'Just finished my daily goals on Sthira! 💪',
      );
    } catch (e) {
      debugPrint('Error sharing image: $e');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: true,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        decoration: BoxDecoration(
          color: context.colors.scaffoldBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Share Your Progress',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: context.colors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Inspire your friends by sharing today's stats!",
            style: TextStyle(
              fontSize: 14,
              color: context.colors.textMedium,
            ),
          ),
          const SizedBox(height: 32),
          
          // The actual card we are capturing
          Center(
            child: RepaintBoundary(
              key: _cardKey,
              child: const DailyShareCard(),
            ),
          ),
          
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: context.colors.primary,
                foregroundColor: context.colors.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                elevation: 4,
                shadowColor: context.colors.primary.withValues(alpha: 0.4),
              ),
              onPressed: _isSharing ? null : _shareImage,
              icon: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.ios_share_rounded),
              label: Text(
                _isSharing ? 'Preparing...' : 'Share to Story',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
