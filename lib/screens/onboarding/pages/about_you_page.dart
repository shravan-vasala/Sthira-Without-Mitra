import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_text_field.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';

class AboutYouPage extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController coachController;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final FocusNode? nameFocus;
  final FocusNode? heightFocus;
  final FocusNode? weightFocus;
  final bool useKg;
  final bool showErrors;
  final VoidCallback onToggleUnit;

  const AboutYouPage({
    super.key,
    required this.nameController,
    required this.coachController,
    required this.heightController,
    required this.weightController,
    this.nameFocus,
    this.heightFocus,
    this.weightFocus,
    required this.useKg,
    this.showErrors = false,
    required this.onToggleUnit,
  });

  @override
  State<AboutYouPage> createState() => _AboutYouPageState();
}

class _AboutYouPageState extends State<AboutYouPage> with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;
  String _nameError = '';
  String _heightError = '';
  String _weightError = '';

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _staggerController.forward();

    widget.nameController.addListener(_validateInputs);
    widget.heightController.addListener(_validateInputs);
    widget.weightController.addListener(_validateInputs);
  }

  @override
  void dispose() {
    _staggerController.dispose();
    widget.nameController.removeListener(_validateInputs);
    widget.heightController.removeListener(_validateInputs);
    widget.weightController.removeListener(_validateInputs);
    super.dispose();
  }

  @override
  void didUpdateWidget(AboutYouPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.useKg != widget.useKg || oldWidget.showErrors != widget.showErrors) {
      _validateInputs();
    }
  }

  void _validateInputs() {
    String nError = '';
    String hError = '';
    String wError = '';

    if (widget.showErrors && widget.nameController.text.trim().isEmpty) {
      nError = 'Required';
    }

    final hText = widget.heightController.text;
    if (hText.isNotEmpty) {
      final h = double.tryParse(hText);
      if (h == null) {
        hError = 'Invalid number';
      } else if (h < 100 || h > 230) {
        hError = 'Must be 100-230 cm';
      }
    }

    final wText = widget.weightController.text;
    if (wText.isNotEmpty) {
      final w = double.tryParse(wText);
      if (w == null) {
        wError = 'Invalid number';
      } else {
        final double wKg = widget.useKg ? w : w / 2.20462;
        if (wKg < 30 || wKg > 200) {
          wError = widget.useKg ? 'Must be 30-200 kg' : 'Must be 66-440 lb';
        }
      }
    }

    if (nError != _nameError || hError != _heightError || wError != _weightError) {
      setState(() {
        _nameError = nError;
        _heightError = hError;
        _weightError = wError;
      });
    }
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          _buildAnimEntrance(
            0,
            Column(
              children: [
                Icon(
                  Icons.person_outline_rounded,
                  size: 48,
                  color: context.colors.primary,
                ),
                const SizedBox(height: 24),
                const Text(
                  'About You',
                  textAlign: TextAlign.center,
                  style: context.text.metric.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildAnimEntrance(
            1,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: widget.nameController,
                  focusNode: widget.nameFocus,
                  labelText: 'Your Name',
                  hintText: 'Eg. Bodamma',
                  capitalization: TextCapitalization.words,
                  prefixIcon: Icons.badge_rounded,
                ),
                if (_nameError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0, left: 4),
                    child: Text(
                      _nameError,
                      style: context.text.caption.copyWith(color: context.colors.red),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildAnimEntrance(
            2,
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: widget.coachController,
                  labelText: 'Coach Name (Optional)',
                  hintText: 'Eg. Shravan',
                  capitalization: TextCapitalization.words,
                  prefixIcon: Icons.sports_rounded,
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0, left: 4),
                  child: Text(
                    'What should your AI coach call itself?',
                    style: context.text.caption.copyWith(color: context.colors.textMedium),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildAnimEntrance(
            3,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        controller: widget.heightController,
                        focusNode: widget.heightFocus,
                        labelText: 'Height (Optional)',
                        hintText: '153 cm',
                        keyboardType: TextInputType.number,
                      ),
                      if (_heightError.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 4),
                          child: Text(
                            _heightError,
                            style: context.text.caption.copyWith(color: context.colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppTextField(
                        controller: widget.weightController,
                        focusNode: widget.weightFocus,
                        labelText: 'Weight (Optional)',
                        hintText: widget.useKg ? '66 kg' : '145 lb',
                        keyboardType: TextInputType.number,
                      ),
                      if (_weightError.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 4),
                          child: Text(
                            _weightError,
                            style: context.text.caption.copyWith(color: context.colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildAnimEntrance(
            4,
            Center(
              child: GestureDetector(
                onTap: widget.onToggleUnit,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: context.colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.swap_horiz_rounded, color: context.colors.primary, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Switch to ${widget.useKg ? 'Pounds' : 'Kilograms'}',
                        style: context.text.caption.copyWith(color: context.colors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}
