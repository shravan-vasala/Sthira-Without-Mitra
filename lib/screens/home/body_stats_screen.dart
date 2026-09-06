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

  @override
  void initState() {
    super.initState();
    for (final f in _fields) {
      _controllers[f] = TextEditingController();
    }
    _loadData();
  }

  void _loadData() {
    final stats = ref.read(bodyStatsRepoProvider).getLatestStats();
    if (stats != null) {
      final m = stats.allMeasurements;
      for (final f in _fields) {
        if (m[f] != null) {
          _controllers[f]!.text = m[f]!.toStringAsFixed(1);
        }
      }
    }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (_isEditing) {
                _save();
              }
              setState(() => _isEditing = !_isEditing);
            },
            child: Text(
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
            child: Text(
              'ALL MEASUREMENTS',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: context.colors.primary,
                letterSpacing: 1.5,
              ),
            ),
          ),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              mainAxisExtent: 96,
            ),
            itemCount: _fields.length,
            itemBuilder: (ctx, i) => _buildField(_fields[i]),
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
        border: Border.all(color: context.colors.border),
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
                      child: SizedBox(
                        height: 32,
                        child: TextField(
                          controller: _controllers[field],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(
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
                          ),
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

  void _save() {
    final date = DateFormat('yyyy-MM-dd').format(DateTime.now());
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
    ref.read(bodyStatsRepoProvider).saveStats(stats);
  }
}
