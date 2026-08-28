import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect with Friends'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Code'),
            Tab(text: 'Scan Code'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MyCodeTab(),
          _ScanCodeTab(),
        ],
      ),
    );
  }
}

class _MyCodeTab extends ConsumerWidget {
  const _MyCodeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final uid = authService.uid;

    if (uid == null) {
      return const Center(child: Text('Please sign in to view your code.'));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Scan this code to connect!',
            style: TextStyle(
              fontSize: 20, 
              fontWeight: FontWeight.w800,
              color: context.colors.primary,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: context.colors.primary.withOpacity(0.3),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: context.colors.primary.withOpacity(0.15),
                  blurRadius: 24,
                  spreadRadius: 8,
                ),
              ],
            ),
            child: QrImageView(
              data: uid,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.transparent,
              foregroundColor: context.colors.primary,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Or share this ID:',
            style: TextStyle(
              color: context.colors.textMedium,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.colors.inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SelectableText(
              uid,
              style: TextStyle(
                fontSize: 16,
                fontFamily: 'monospace',
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
                color: context.colors.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScanCodeTab extends ConsumerStatefulWidget {
  const _ScanCodeTab();

  @override
  ConsumerState<_ScanCodeTab> createState() => _ScanCodeTabState();
}

class _ScanCodeTabState extends ConsumerState<_ScanCodeTab> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null) return;

    setState(() {
      _isProcessing = true;
    });

    _scannerController.stop();

    try {
      final friendRepo = ref.read(friendRepoProvider);
      
      // Attempt to fetch profile from Firestore to get their name
      final db = ref.read(socialSyncServiceProvider);
      // Wait, we can't easily do a one-off fetch with the current stream interface
      // So we'll just add them locally and stream their data in the feed
      await friendRepo.addFriend(code, 'Connected Friend');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend connected successfully!')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add friend: $e')),
        );
      }
      _scannerController.start();
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: Stack(
            children: [
              MobileScanner(
                controller: _scannerController,
                onDetect: _onDetect,
              ),
              Center(
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: context.colors.primary.withOpacity(0.8),
                      width: 4,
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Container(
            color: context.colors.scaffoldBg,
            child: Center(
              child: Text(
                'Position the QR code in the frame.',
                style: TextStyle(
                  color: context.colors.textMedium,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
