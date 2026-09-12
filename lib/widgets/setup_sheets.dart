import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_colors.dart';
import '../providers/app_providers.dart';
import 'app_bottom_sheet.dart';
import 'app_text_field.dart';
import 'primary_button.dart';
import 'surface_card.dart';

class AiSetupSheet extends ConsumerStatefulWidget {
  const AiSetupSheet({super.key});

  @override
  ConsumerState<AiSetupSheet> createState() => _AiSetupSheetState();
}

class _AiSetupSheetState extends ConsumerState<AiSetupSheet> {
  late TextEditingController _geminiController;
  late TextEditingController _coachController;
  bool _isVerifying = false;
  bool _isSuccess = false;
  String _errorMessage = '';
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    _geminiController = TextEditingController(text: profile.geminiApiKey ?? '');
    _coachController = TextEditingController(text: profile.coachName ?? '');
  }

  @override
  void dispose() {
    _geminiController.dispose();
    _coachController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final key = _geminiController.text.trim();
    final coach = _coachController.text.trim();

    if (key.isNotEmpty) {
      setState(() {
        _isVerifying = true;
        _errorMessage = '';
      });
      try {
        await ref.read(geminiFoodServiceProvider).verifyApiKey(key);
        await ref.read(profileProvider.notifier).updateGeminiKey(key);
      } catch (e) {
        if (mounted) {
          setState(() {
            _isVerifying = false;
            _errorMessage = e.toString().replaceAll('Exception: ', '');
          });
        }
        return;
      }
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    } else {
      // Allow clearing the key if it was removed by the user
      try {
        await ref.read(profileProvider.notifier).updateGeminiKey('');
      } catch (e) {
        if (mounted) {
          setState(() {
            _isVerifying = false;
            _errorMessage = e.toString().replaceAll('Exception: ', '');
          });
        }
        return;
      }
    }
    
    final current = ref.read(profileProvider);
    await ref.read(profileProvider.notifier).updateProfile(
      current.copyWith(coachName: coach),
    );

    if (mounted) {
      setState(() => _isSuccess = true);
      final disableAnimations = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
      if (!disableAnimations) {
        await Future.delayed(const Duration(milliseconds: 600)); // Shorter delay
      }
      if (mounted) Navigator.pop(context, true);
    }
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'AI & Coach Settings',
      scrollable: true,
      subtitle: 'Set your coach\'s name. Food scanning and coach features use your Gemini API key.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _coachController,
            labelText: 'Coach name',
            hintText: 'Eg. Shravan',
            capitalization: TextCapitalization.words,
            prefixIcon: Icons.sports_rounded,
          ),
          const SizedBox(height: 24),
          AppTextField(
            controller: _geminiController,
            labelText: 'Gemini API Key',
            hintText: 'AI Studio Key...',
            obscureText: _obscureKey,
            prefixIcon: Icons.key_rounded,
            suffixIcon: IconButton(
              icon: Icon(
                _obscureKey ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: context.colors.textMedium,
              ),
              onPressed: () => setState(() => _obscureKey = !_obscureKey),
            ),
          ),
          if (_errorMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: context.colors.red, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: TextStyle(color: context.colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _launchUrl('https://aistudio.google.com/app/apikey'),
              icon: Icon(Icons.open_in_new_rounded, size: 16, color: context.colors.primary),
              label: Text(
                'Get Gemini API Key',
                style: TextStyle(color: context.colors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            onPressed: _isSuccess ? () {} : (_isVerifying ? null : _save),
            label: _isSuccess ? 'Saved!' : (_isVerifying ? 'Verifying...' : 'Save Changes'),
            isLoading: _isVerifying,
            icon: _isSuccess ? Icons.check_circle_rounded : Icons.check_rounded,
            iconColor: _isSuccess ? const Color(0xFF4CAF50) : null,
          ).animate(target: _isSuccess ? 1 : 0)
           .scaleXY(end: 1.05, duration: 200.ms, curve: Curves.easeOutBack)
           .then(delay: 200.ms).scaleXY(end: 1.0, duration: 150.ms),
        ],
      ),
    );
  }
}

class HealthConnectSheet extends ConsumerStatefulWidget {
  const HealthConnectSheet({super.key});

  @override
  ConsumerState<HealthConnectSheet> createState() => _HealthConnectSheetState();
}

class _HealthConnectSheetState extends ConsumerState<HealthConnectSheet> {
  bool _connecting = false;
  String _status = '';

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _status = '';
    });
    try {
      final hcService = ref.read(healthConnectServiceProvider);
      final granted = await hcService.requestPermission();
      setState(() {
        _status = granted ? 'Connected! Data will sync automatically.' : 'Permission denied.';
      });
      if (granted && mounted) {
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) Navigator.pop(context, true);
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Health Connect not available.';
      });
    } finally {
      setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'Health Connect',
      subtitle: 'Automatically sync steps and sleep data from other apps.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.favorite_rounded,
            size: 64,
            color: context.colors.primary,
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            onPressed: _connecting ? null : _connect,
            label: _connecting ? 'Connecting...' : 'Connect Now',
            isLoading: _connecting,
            icon: Icons.link_rounded,
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _status.contains('Connected') ? context.colors.primary : context.colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class CloudSyncSheet extends ConsumerStatefulWidget {
  const CloudSyncSheet({super.key});

  @override
  ConsumerState<CloudSyncSheet> createState() => _CloudSyncSheetState();
}

class _CloudSyncSheetState extends ConsumerState<CloudSyncSheet> {
  bool _connecting = false;
  String _status = '';

  Future<void> _connect() async {
    setState(() {
      _connecting = true;
      _status = '';
    });
    try {
      final authService = ref.read(authServiceProvider);
      final user = await authService.signInWithGoogle();
      if (user != null) {
        setState(() {
          _status = 'Connected! Your data will be backed up.';
        });
        if (mounted) {
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) Navigator.pop(context, true);
          });
        }
      } else {
        setState(() {
          _status = 'Sign in cancelled.';
        });
      }
    } catch (e) {
      setState(() {
        _status = 'Could not sign in.';
      });
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheet(
      title: 'Cloud Backup',
      subtitle: 'Securely sync your progress across devices and never lose a day.',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.cloud_sync_rounded,
            size: 64,
            color: context.colors.primary,
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            onPressed: _connecting ? null : _connect,
            label: _connecting ? 'Connecting...' : 'Enable Cloud Sync',
            isLoading: _connecting,
            icon: Icons.cloud_upload_rounded,
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              _status,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _status.contains('Connected') ? context.colors.primary : context.colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
