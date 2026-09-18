import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_motion.dart';
import '../../../providers/app_providers.dart';
import '../../../services/haptics.dart';
import '../../../widgets/app_text_field.dart';

class DayFeelingCard extends ConsumerStatefulWidget {
  final String dateStr;
  final String? initialFeeling;
  final String? initialNote;

  const DayFeelingCard({
    super.key,
    required this.dateStr,
    this.initialFeeling,
    this.initialNote,
  });

  @override
  ConsumerState<DayFeelingCard> createState() => _DayFeelingCardState();
}

class _DayFeelingCardState extends ConsumerState<DayFeelingCard> {
  static const _storedValues = ['veryLow', 'low', 'okay', 'good', 'great'];
  static const _labels = ['Struggled', 'Tired', 'Okay', 'Steady', 'Thriving'];

  late final TextEditingController _noteCtrl;
  Timer? _debounce;
  bool _showNote = false;

  @override
  void initState() {
    super.initState();
    _noteCtrl = TextEditingController(text: widget.initialNote);
  }

  @override
  void didUpdateWidget(covariant DayFeelingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialNote != oldWidget.initialNote &&
        widget.initialNote != _noteCtrl.text) {
      _noteCtrl.text = widget.initialNote ?? '';
    }
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _update(String? feeling, String? note) async {
    if (feeling == null) {
      await ref.read(dailyLogRepoProvider).removeCheckIn(widget.dateStr);
    } else {
      await ref.read(dailyLogRepoProvider).updateCheckIn(widget.dateStr, feeling, note);
    }
  }

  void _onNoteChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), () {
      _update(widget.initialFeeling, text);
    });
  }

  @override
  Widget build(BuildContext context) {
    final feeling = widget.initialFeeling;
    final hasFeeling = feeling != null && feeling.isNotEmpty;
    final selectedIndex = hasFeeling ? _storedValues.indexOf(feeling) : -1;
    final hasNote = _noteCtrl.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.self_improvement_rounded,
              size: IconSize.inline,
              color: context.colors.textMedium,
            ),
            const SizedBox(width: Spacing.inline),
            Text(
              'How did today feel?',
              style: context.text.caption.copyWith(color: context.colors.textMedium),
            ),
            if (hasFeeling) ...[
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Haptics.tap();
                  setState(() => _showNote = !_showNote);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    hasNote ? Icons.edit_note_rounded : Icons.edit_note_outlined,
                    size: IconSize.inline,
                    color: _showNote ? context.colors.primary : context.colors.textMedium,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: Spacing.stack),
        Row(
          children: List.generate(5, (index) {
            final isFilled = hasFeeling && index <= selectedIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  Haptics.tap();
                  if (selectedIndex == index) {
                    _update(null, null); // Clear feeling and note
                    setState(() {
                      _showNote = false;
                      _noteCtrl.clear();
                    });
                  } else {
                    _update(_storedValues[index], _noteCtrl.text);
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  height: 44, // 44dp hit area
                  alignment: Alignment.center,
                  child: AnimatedContainer(
                    duration: Motion.instant,
                    height: 6,
                    margin: EdgeInsets.only(
                      left: index == 0 ? 0 : Spacing.x4,
                      right: index == 4 ? 0 : Spacing.x4,
                    ),
                    decoration: BoxDecoration(
                      color: isFilled ? context.colors.primary : context.colors.insetSurface,
                      borderRadius: BorderRadius.circular(Radii.micro),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        if (hasFeeling && selectedIndex >= 0)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.stack),
            child: Text(
              _labels[selectedIndex],
              textAlign: TextAlign.center,
              style: context.text.caption.copyWith(color: context.colors.primary),
            ),
          ),
        AnimatedSize(
          duration: Motion.standard,
          curve: Motion.enter,
          alignment: Alignment.topCenter,
          child: (!hasFeeling || !_showNote)
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(top: Spacing.stack),
                  child: Focus(
                    onFocusChange: (hasFocus) {
                      if (!hasFocus) _update(feeling, _noteCtrl.text);
                    },
                    child: AppTextField(
                      controller: _noteCtrl,
                      labelText: '',
                      hintText: 'A quick note about today...',
                      minLines: 1,
                      maxLines: 3,
                      onChanged: _onNoteChanged,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
