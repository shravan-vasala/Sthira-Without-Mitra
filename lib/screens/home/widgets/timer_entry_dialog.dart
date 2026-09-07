import 'dart:async';
import 'package:flutter/material.dart';
import '../../../services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/app_colors.dart';
import '../../../models/habit.dart';
import '../../../providers/app_providers.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/primary_button.dart';

class TimerEntryDialog extends ConsumerStatefulWidget {
  final Habit habit;

  const TimerEntryDialog({super.key, required this.habit});

  @override
  ConsumerState<TimerEntryDialog> createState() => _TimerEntryDialogState();
}

class _TimerEntryDialogState extends ConsumerState<TimerEntryDialog>
    with SingleTickerProviderStateMixin {
  late int _totalSeconds;
  late int _remainingSeconds;
  Timer? _timer;
  bool _isRunning = false;

  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    // target is in minutes
    _totalSeconds = (widget.habit.target * 60).toInt();
    _remainingSeconds = _totalSeconds;

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _totalSeconds),
    );
    // Initialize animation value to 1.0 (full)
    _animationController.value = 1.0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _startTimer() {
    if (_remainingSeconds <= 0) return;

    setState(() {
      _isRunning = true;
    });

    _animationController.reverse(from: _remainingSeconds / _totalSeconds);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_remainingSeconds > 0) {
          _remainingSeconds--;
        } else {
          _completeTimer();
        }
      });
    });
  }

  void _pauseTimer() {
    setState(() {
      _isRunning = false;
    });
    _timer?.cancel();
    _animationController.stop();
  }

  void _completeTimer() {
    _timer?.cancel();
    _animationController.stop();
    setState(() {
      _isRunning = false;
      _remainingSeconds = 0;
    });

    final profile = ref.read(profileProvider);
    if (profile.restTimerVibration) {
      Haptics.success();
    }
    // We're skipping playing a sound here to avoid adding a new audio dependency just for this,
    // but the framework is in place (restTimerSound).

    // Mark habit as completed
    ref.read(habitCompletionsProvider.notifier).toggle(widget.habit.id);

    // Close the dialog automatically after a brief delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final progress = _remainingSeconds / _totalSeconds;

    return AppSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.habit.name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: context.colors.textDark,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Stay focused',
            style: TextStyle(fontSize: 14, color: context.colors.textMedium),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          Center(
            child: SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return CircularProgressIndicator(
                        value: _animationController.value,
                        strokeWidth: 12,
                        backgroundColor: context.colors.border,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          context.colors.primary,
                        ),
                        strokeCap: StrokeCap.round,
                      );
                    },
                  ),
                  Center(
                    child: Text(
                      _formatTime(_remainingSeconds),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w800,
                        color: context.colors.textDark,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          Row(
            children: [
              if (_remainingSeconds < _totalSeconds &&
                  !_isRunning &&
                  _remainingSeconds > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _remainingSeconds = _totalSeconds;
                        _animationController.value = 1.0;
                      });
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: context.colors.red,
                      side: BorderSide(
                        color: context.colors.red.withValues(alpha: 0.5),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Reset',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              if (_remainingSeconds < _totalSeconds &&
                  !_isRunning &&
                  _remainingSeconds > 0)
                const SizedBox(width: 16),

              Expanded(
                flex: 2,
                child: PrimaryButton(
                  label: _remainingSeconds == 0
                      ? 'Done'
                      : (_isRunning
                            ? 'Pause'
                            : (_remainingSeconds == _totalSeconds
                                  ? 'Start'
                                  : 'Resume')),
                  onPressed: _remainingSeconds == 0
                      ? () => Navigator.of(context).pop()
                      : (_isRunning ? _pauseTimer : _startTimer),
                  icon: _remainingSeconds == 0
                      ? Icons.check_circle_rounded
                      : (_isRunning
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}
