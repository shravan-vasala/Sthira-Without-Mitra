import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/surface_card.dart';
import '../../../widgets/setup_sheets.dart';
import '../../../providers/app_providers.dart';
import '../../../providers/credential_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';

class ConnectPage extends ConsumerStatefulWidget {
  const ConnectPage({super.key});

  @override
  ConsumerState<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends ConsumerState<ConnectPage> with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;
  bool _healthConnected = false;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _staggerController.forward();
    _checkHealthStatus();
  }

  Future<void> _checkHealthStatus() async {
    final hcService = ref.read(healthConnectServiceProvider);
    final isAuthorized = await hcService.isAuthorized();
    if (mounted) {
      setState(() {
        _healthConnected = isAuthorized;
      });
    }
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Widget _buildAnimEntrance(int index, Widget child) {
    return Builder(
      builder: (context) {
        if (MediaQuery.disableAnimationsOf(context)) {
          return child;
        }
        final start = index * 0.1;
        final end = (start + 0.5).clamp(0.0, 1.0);
        return AnimatedBuilder(
          animation: _staggerController,
          builder: (context, animChild) {
            final slide = CurvedAnimation(
              parent: _staggerController,
              curve: Interval(start, end, curve: Curves.easeOutCubic),
            ).value;
            final fade = CurvedAnimation(
              parent: _staggerController,
              curve: Interval(start, end - 0.2, curve: Curves.easeIn),
            ).value;
            return Opacity(
              opacity: fade,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - slide)),
                child: animChild,
              ),
            );
          },
          child: child,
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    // Current statuses
    final cred = ref.watch(credentialProvider);
    final hasGemini = cred.status == CredentialStatus.present && (cred.key ?? '').isNotEmpty;
    
    final cloudConnected = ref.watch(isSignedInProvider);
    final syncState = ref.watch(cloudSyncControllerProvider);
    
    String cloudStatusText = 'Local-only';
    if (cloudConnected) {
      if (syncState == CloudSyncState.syncing) {
        cloudStatusText = 'Sync pending';
      } else if (syncState == CloudSyncState.error) {
        cloudStatusText = 'Retry';
      } else {
        cloudStatusText = 'Connected';
      }
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 64),
          _buildAnimEntrance(
            0,
            Column(
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 48,
                  color: context.colors.primary,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Connect',
                  textAlign: TextAlign.center,
                  style: context.text.metric.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 12),
                Text(
                  'Optional — you can do any of this later in Settings.',
                  textAlign: TextAlign.center,
                  style: context.text.body.copyWith(color: context.colors.textMedium),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),

          _buildAnimEntrance(
            1,
            _IntegrationRow(
              icon: Icons.favorite_rounded,
              title: 'Health Connect',
              subtitle: 'Sync steps & sleep natively.',
              statusText: _healthConnected ? 'Connected' : 'Optional',
              statusActive: _healthConnected,
              onTap: () async {
                await showAppBottomSheet<bool>(
                  context: context,
                  builder: (_) => const HealthConnectSheet(),
                );
                if (mounted) {
                  await _checkHealthStatus();
                }
              },
            ),
          ),

          _buildAnimEntrance(
            2,
            _IntegrationRow(
              icon: Icons.camera_alt_rounded,
              title: 'AI Food Scanning',
              subtitle: 'Scan meals using Gemini AI.',
              statusText: hasGemini ? 'Key saved' : 'Missing Key',
              statusActive: hasGemini,
              onTap: () {
                showAppBottomSheet(
                  context: context,
                  builder: (_) => const AiSetupSheet(),
                );
              },
            ),
          ),

          _buildAnimEntrance(
            3,
            _IntegrationRow(
              icon: Icons.cloud_sync_rounded,
              title: 'Cloud Backup',
              subtitle: 'Securely sync your progress.',
              statusText: cloudStatusText,
              statusActive: cloudConnected,
              onTap: () async {
                await showAppBottomSheet<bool>(
                  context: context,
                  builder: (_) => const CloudSyncSheet(),
                );
              },
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _IntegrationRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String statusText;
  final bool statusActive;
  final VoidCallback onTap;

  const _IntegrationRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.statusText,
    required this.statusActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final disableAnim = MediaQuery.disableAnimationsOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: context.colors.primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: context.text.bodyStrong.copyWith(color: context.colors.textDark),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: context.text.caption.copyWith(color: context.colors.textMedium),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: disableAnim ? Duration.zero : const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
                if (disableAnim) return child;
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.4),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: Column(
                key: ValueKey(statusActive),
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusActive ? context.colors.primary.withValues(alpha: 0.15) : context.colors.inputFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: context.text.micro.copyWith(color: statusActive ? context.colors.primary : context.colors.textMedium),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onTap,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (statusActive) ...[
                          Icon(
                            Icons.check_circle_rounded,
                            size: 14,
                            color: context.colors.primary,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          statusActive ? 'Edit' : 'Set up',
                          style: context.text.body.copyWith(color: context.colors.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
