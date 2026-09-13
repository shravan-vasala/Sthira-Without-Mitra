import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../models/body_stats.dart';

class BodyStatsScreen extends ConsumerStatefulWidget {
  const BodyStatsScreen({super.key});

  @override
  ConsumerState<BodyStatsScreen> createState() => _BodyStatsScreenState();
}

class _BodyStatsScreenState extends ConsumerState<BodyStatsScreen> {
  final _controllers = <String, TextEditingController>{};
  bool _isEditing = false;
  bool _isSaving = false;

  final _fields = [
    'Waist',
    'Hips',
    'Chest',
    'Left Arm',
    'Right Arm',
    'Left Thigh',
    'Right Thigh',
    'Neck',
  ];

  bool _isPrefilled = false;
  String? _prefillDate;
  late final String _pinnedDateStr;

  @override
  void initState() {
    super.initState();
    _pinnedDateStr = ref.read(dateStringProvider);
    for (final f in _fields) {
      _controllers[f] = TextEditingController();
    }
    _loadData();
  }

  void _loadData() {
    final stats = ref.read(bodyStatsRepoProvider).getStats(_pinnedDateStr);
    if (stats != null) {
      _isPrefilled = false;
      _prefillDate = null;
      _fillControllers(stats);
      return;
    }
    
    final latest = ref.read(bodyStatsRepoProvider).getLatestStats();
    if (latest != null) {
      _isPrefilled = true;
      _prefillDate = latest.date;
      _fillControllers(latest);
    } else {
      _isPrefilled = false;
      _prefillDate = null;
      for (final f in _fields) {
        _controllers[f]!.clear();
      }
    }
  }

  void _fillControllers(BodyStats stats) {
    final m = stats.allMeasurements;
    for (final f in _fields) {
      if (m[f] != null) {
        _controllers[f]!.text = m[f]!.toStringAsFixed(1);
      } else {
        _controllers[f]!.clear();
      }
    }
  }

  bool _hasMutatedFields(BodyStats? original) {
    if (original == null) return true;
    final m = original.allMeasurements;
    for (final f in _fields) {
      final prefillVal = (m[f] != null) ? m[f]!.toStringAsFixed(1) : '';
      final currentVal = _controllers[f]!.text.trim();
      // If any field has been changed by the user, return true.
      if (prefillVal != currentVal && (prefillVal != '' || currentVal != '')) {
         return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.scaffoldBg,
      appBar: AppBar(
        title: const Text('Body Stats'),
        leading: _isEditing
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _isEditing = false;
                    _loadData();
                  });
                },
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
        actions: [
          TextButton(
            onPressed: _isSaving
                ? null
                : () async {
                    if (_isEditing) {
                      await _save();
                    } else {
                      setState(() => _isEditing = true);
                    }
                  },
            child: _isSaving
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.colors.primary,
                    ),
                  )
                : Text(
                    _isEditing ? 'Save' : 'Edit',
                    style: TextStyle(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ALL MEASUREMENTS FOR ${DateFormat('MMM d, yyyy').format(DateTime.parse(_pinnedDateStr)).toUpperCase()}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.colors.primary,
                    letterSpacing: 1.5,
                  ),
                ),
                if (_isPrefilled && _prefillDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Prefilled from ${DateFormat('MMM d').format(DateTime.parse(_prefillDate!))} measurement',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.colors.textMedium,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final itemWidth = (width - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: _fields.map((f) => SizedBox(
                  width: itemWidth,
                  child: _buildField(f),
                )).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildField(String field) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            field,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.colors.textMedium,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          _isEditing
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controllers[field],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(
                          fontFamily: 'Cabinet Grotesk',
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: context.colors.primary,
                          height: 1.0,
                        ),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.zero,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        'cm',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textMedium,
                        ),
                      ),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _controllers[field]!.text.isEmpty ? '--' : _controllers[field]!.text,
                      style: TextStyle(
                        fontFamily: 'Cabinet Grotesk',
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: _controllers[field]!.text.isEmpty ? context.colors.textLight : context.colors.textDark,
                        height: 1.0,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        'cm',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: context.colors.textMedium,
                        ),
                      ),
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final date = _pinnedDateStr;
      
      // Prevent silent duplication of prefill logic
      if (_isPrefilled && _prefillDate != date) {
         final latest = ref.read(bodyStatsRepoProvider).getLatestStats();
         if (!_hasMutatedFields(latest)) {
            // Nothing was mutated, cancel save
            if (mounted) {
              setState(() {
                _isEditing = false;
                _isSaving = false;
              });
            }
            return;
         }
      }
      
      final stats = BodyStats(
        date: date,
        waist: double.tryParse(_controllers['Waist']!.text),
        hips: double.tryParse(_controllers['Hips']!.text),
        chest: double.tryParse(_controllers['Chest']!.text),
        leftArm: double.tryParse(_controllers['Left Arm']!.text),
        rightArm: double.tryParse(_controllers['Right Arm']!.text),
        leftThigh: double.tryParse(_controllers['Left Thigh']!.text),
        rightThigh: double.tryParse(_controllers['Right Thigh']!.text),
        neck: double.tryParse(_controllers['Neck']!.text),
      );
      await ref.read(bodyStatsRepoProvider).saveStats(stats);
      if (mounted) {
        setState(() {
          _isEditing = false;
          _isSaving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save body stats.')),
        );
      }
    }
  }
}
