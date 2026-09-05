import 'package:flutter/material.dart';
import '../../../theme/app_colors.dart';
import '../../../widgets/app_text_field.dart';

class AboutYouPage extends StatefulWidget {
  final TextEditingController nameController;
  final TextEditingController coachController;
  final TextEditingController heightController;
  final TextEditingController weightController;
  final bool useKg;
  final VoidCallback onToggleUnit;

  const AboutYouPage({
    super.key,
    required this.nameController,
    required this.coachController,
    required this.heightController,
    required this.weightController,
    required this.useKg,
    required this.onToggleUnit,
  });

  @override
  State<AboutYouPage> createState() => _AboutYouPageState();
}

class _AboutYouPageState extends State<AboutYouPage> with SingleTickerProviderStateMixin {
  late AnimationController _staggerController;
  String _heightError = '';
  String _weightError = '';

  @override
  void initState() {
    super.initState();
    _staggerController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _staggerController.forward();

    widget.heightController.addListener(_validateInputs);
    widget.weightController.addListener(_validateInputs);
  }

  @override
  void dispose() {
    _staggerController.dispose();
    widget.heightController.removeListener(_validateInputs);
    widget.weightController.removeListener(_validateInputs);
    super.dispose();
  }

  @override
  void didUpdateWidget(AboutYouPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.useKg != widget.useKg) {
      _validateInputs();
    }
  }

  void _validateInputs() {
    String hError = '';
    String wError = '';

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

    if (hError != _heightError || wError != _weightError) {
      setState(() {
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
          const SizedBox(height: 64),
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
                  style: TextStyle(
                    fontFamily: 'Cabinet Grotesk',
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1,
                    letterSpacing: -1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          _buildAnimEntrance(
            1,
            AppTextField(
              controller: widget.nameController,
              labelText: 'Your Name',
              hintText: 'Eg. Bodamma',
              capitalization: TextCapitalization.words,
              prefixIcon: Icons.badge_rounded,
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
                    style: TextStyle(
                      fontFamily: 'General Sans',
                      fontSize: 13,
                      color: context.colors.textMedium,
                      fontWeight: FontWeight.w500,
                    ),
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
                        labelText: 'Height',
                        hintText: '175 cm',
                        keyboardType: TextInputType.number,
                      ),
                      if (_heightError.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 4),
                          child: Text(
                            _heightError,
                            style: TextStyle(color: context.colors.red, fontSize: 13),
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
                        labelText: 'Goal Weight',
                        hintText: widget.useKg ? '70 kg' : '154 lb',
                        keyboardType: TextInputType.number,
                      ),
                      if (_weightError.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 4),
                          child: Text(
                            _weightError,
                            style: TextStyle(color: context.colors.red, fontSize: 13),
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
              child: ActionChip(
                onPressed: widget.onToggleUnit,
                backgroundColor: context.colors.inputFill,
                side: BorderSide(color: context.colors.border.withOpacity(0.5)),
                label: Text(
                  'Switch to ${widget.useKg ? 'Pounds' : 'Kilograms'}',
                  style: TextStyle(
                    fontFamily: 'General Sans',
                    color: context.colors.primary,
                    fontWeight: FontWeight.w600,
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
