import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../providers/app_providers.dart';
import '../../theme/app_colors.dart';
import '../../widgets/surface_card.dart';

class ConnectScreen extends ConsumerStatefulWidget {
  const ConnectScreen({super.key});

  @override
  ConsumerState<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends ConsumerState<ConnectScreen>
    with SingleTickerProviderStateMixin {
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
        children: const [_MyCodeTab(), _ScanCodeTab()],
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
          SurfaceCard(
            padding: const EdgeInsets.all(16),
            child: QrImageView(
              data: uid,
              version: QrVersions.auto,
              size: 200.0,
              backgroundColor: Colors.transparent,
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.circle,
                color: context.colors.primary,
              ),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.circle,
                color: context.colors.primary,
              ),
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

    // ignore: unawaited_futures
    _scannerController.stop();

    try {
      final syncService = ref.read(socialSyncServiceProvider);
      final myUid = syncService.currentUid;
      final friendRepo = ref.read(friendRepoProvider);
      final profile = ref.read(profileProvider);

      if (!RegExp(r'^[A-Za-z0-9]{20,40}$').hasMatch(code)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('That code doesn\'t look quite right. Give it another try.'),
              backgroundColor: context.colors.red,
            ),
          );
        }
        // ignore: unawaited_futures
        _scannerController.start();
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

      if (code == myUid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('That\'s your own code!')),
          );
        }
        // ignore: unawaited_futures
        _scannerController.start();
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

      final existingFriend = friendRepo.getFriend(code);
      if (existingFriend != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You are already friends with this person!'),
            ),
          );
        }
        // ignore: unawaited_futures
        _scannerController.start();
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

      final targetProfile = await syncService.fetchProfileOnce(code);
      if (targetProfile == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('We couldn\'t find anyone with that code. Is it correct?'),
              backgroundColor: context.colors.orange,
            ),
          );
        }
        // ignore: unawaited_futures
        _scannerController.start();
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        return;
      }

      final String? safeAvatar =
          (profile.photoPath?.startsWith('assets/') ?? false)
          ? profile.photoPath
          : null;

      await syncService.sendFriendRequest(code, profile.name, safeAvatar);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Friend request sent to ${targetProfile.name} successfully!',
            ),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
             content: const Text('Something went wrong. Let\'s try that again.'),
             backgroundColor: context.colors.red,
             behavior: SnackBarBehavior.floating,
          ),
        );
      }
      // ignore: unawaited_futures
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
                      color: context.colors.primary.withValues(alpha: 0.8),
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
