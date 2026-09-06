import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/surface_card.dart';
import '../../../widgets/setup_sheets.dart';
import '../../../providers/app_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConnectPage extends ConsumerStatefulWidget {
  const ConnectPage({super.key});

  @override
  ConsumerState<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends ConsumerState<ConnectPage> with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;
  bool _healthConnected = false;
  bool _cloudConnected = false;

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _staggerController.forward();
  }

  @override
  void dispose() {
    _staggerController.dispose();
    super.dispose();
  }

  Widget _buildAnimEntrance(int index, Widget child) {
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

  @override
  Widget build(BuildContext context) {
    // Current statuses
    final profile = ref.watch(profileProvider);
    final hasGemini = (profile.geminiApiKey ?? '').isNotEmpty;
    // Health Connect status could ideally be streamed, but we assume false unless connected during this session
    // For simplicity, we just use local state in sheets and return true if successfully saved.
    
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
                  style: TextStyle(
                    fontFamily: 'Cabinet Grotesk',
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Optional — you can do any of this later in Settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'General Sans',
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: context.colors.textMedium,
                  ),
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
              subtitle: 'Sync workouts & weight natively.',
              statusText: _healthConnected ? 'Connected' : 'Optional',
              statusActive: _healthConnected,
              onTap: () async {
                final result = await showAppBottomSheet<bool>(
                  context: context,
                  builder: (_) => const HealthConnectSheet(),
                );
                if (result == true) {
                  setState(() => _healthConnected = true);
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
              statusText: hasGemini ? 'Connected' : 'Missing Key',
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
              statusText: _cloudConnected ? 'Syncing...' : 'Local-only',
              statusActive: _cloudConnected,
              onTap: () async {
                final result = await showAppBottomSheet<String>(
                  context: context,
                  builder: (_) => const CloudSyncSheet(),
                );
                if (result == 'trigger_sync') {
                  setState(() => _cloudConnected = true);
                }
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.primary.withOpacity(0.15),
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
                    style: TextStyle(
                      fontFamily: 'General Sans',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: 'General Sans',
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              switchInCurve: Curves.easeOutBack,
              switchOutCurve: Curves.easeIn,
              transitionBuilder: (child, animation) {
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
                      color: statusActive ? context.colors.primary.withOpacity(0.15) : context.colors.inputFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontFamily: 'General Sans',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusActive ? context.colors.primary : context.colors.textMedium,
                      ),
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
                          style: TextStyle(
                            fontFamily: 'General Sans',
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: context.colors.primary,
                          ),
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
