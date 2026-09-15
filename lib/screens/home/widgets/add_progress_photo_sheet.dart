import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/primary_button.dart';
import '../../../providers/app_providers.dart';
import '../../../utils/format_units.dart';
import '../photo_viewer_screen.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';

class AddProgressPhotoSheet extends ConsumerStatefulWidget {
  const AddProgressPhotoSheet({super.key});

  @override
  ConsumerState<AddProgressPhotoSheet> createState() =>
      _AddProgressPhotoSheetState();
}

class _AddProgressPhotoSheetState extends ConsumerState<AddProgressPhotoSheet> {
  final _picker = ImagePicker();
  String? _selectedPose;
  late TextEditingController _weightController;
  late TextEditingController _noteController;
  XFile? _pickedImage;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController();
    _noteController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedDate = ref.read(selectedDateProvider);
      final date = DateFormat('yyyy-MM-dd').format(selectedDate);
      final currentWeight = ref.read(dailyLogRepoProvider).getLog(date)?.weight;
      if (currentWeight != null && currentWeight > 0) {
        final profile = ref.read(profileProvider);
        final displayWeight = convertFromKg(profile, currentWeight);
        _weightController.text = displayWeight.toStringAsFixed(1);
      }
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_selectedPose == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a pose first.')),
      );
      return;
    }
    final image = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      imageQuality: 85,
    );
    if (image != null && mounted) {
      setState(() {
        _pickedImage = image;
      });
    }
  }

  Future<void> _savePhoto() async {
    if (_pickedImage == null || _selectedPose == null) return;
    setState(() => _isSaving = true);
    
    final selectedDate = ref.read(selectedDateProvider);
    final date = DateFormat('yyyy-MM-dd').format(selectedDate);
    
    double? weight = double.tryParse(_weightController.text);
    if (weight != null) {
      final profile = ref.read(profileProvider);
      weight = convertToKg(profile, weight);
    }
    
    final note = _noteController.text;
    try {
      final imageBytes = await _pickedImage!.readAsBytes();
      await ref.read(mediaRepoProvider).saveProgressPhoto(
        date,
        imageBytes,
        poseTag: _selectedPose!,
        weight: weight,
        note: note,
      );

      // Check if there is a habit for progress pictures and mark it
      final habits = ref.read(habitsProvider);
      final photoHabit = habits.where((h) => h.name.toLowerCase().contains('photo') || h.name.toLowerCase().contains('picture')).firstOrNull;
      if (photoHabit != null) {
        ref.read(habitCompletionsProvider.notifier).setOverrideForDate(date, photoHabit.id, 'done');
      }

      if (mounted) {
        Navigator.pop(context, true); // true indicates successful save
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save photo: $e')),
        );
      }
    }
  }

  void _openReferenceViewer(String photoPath, String date) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PhotoViewerScreen(
          photos: [PhotoItem(path: photoPath, date: date, poseTag: _selectedPose!)],
          initialIndex: 0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    PhotoItem? referencePhoto;
    if (_selectedPose != null) {
      // Find the most recent photo for this pose
      final allPhotos = ref.read(mediaRepoProvider).getAllProgressPhotosDetailed();
      final previousPosePhotos = allPhotos.where((p) => p.pose == _selectedPose).toList();
      if (previousPosePhotos.isNotEmpty) {
        final recent = previousPosePhotos.first;
        referencePhoto = PhotoItem(path: recent.path, date: recent.date, poseTag: recent.pose);
      }
    }

    final selectedDate = ref.watch(selectedDateProvider);

    return AppSheet(
      title: 'Add Progress Photo',
      subtitle: 'For ${DateFormat('MMM d, yyyy').format(selectedDate)}',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'POSE (REQUIRED)',
              style: context.text.caption.copyWith(color: context.colors.primary),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _PoseSelectorOption(
                    icon: Icons.accessibility_new_rounded,
                    label: 'Front',
                    isSelected: _selectedPose == 'front',
                    onTap: () => setState(() => _selectedPose = 'front'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PoseSelectorOption(
                    icon: Icons.sync_alt_rounded,
                    label: 'Side',
                    isSelected: _selectedPose == 'side',
                    onTap: () => setState(() => _selectedPose = 'side'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _PoseSelectorOption(
                    icon: Icons.turn_left_rounded,
                    label: 'Back',
                    isSelected: _selectedPose == 'back',
                    onTap: () => setState(() => _selectedPose = 'back'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            if (_pickedImage == null) ...[
              Text(
                'SOURCE',
                style: context.text.caption.copyWith(color: context.colors.primary),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _SourceTile(
                      icon: Icons.camera_alt_rounded,
                      label: 'Camera',
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SourceTile(
                      icon: Icons.photo_library_rounded,
                      label: 'Gallery',
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                  ),
                  if (referencePhoto != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => _openReferenceViewer(referencePhoto!.path, referencePhoto.date),
                        child: Column(
                          children: [
                            Container(
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.colors.primary.withValues(alpha: 0.5), width: 2),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: kIsWeb 
                                  ? Image.network(referencePhoto.path, fit: BoxFit.cover)
                                  : Image.file(File(ref.read(mediaRepoProvider).getAbsolutePath(referencePhoto.path)), fit: BoxFit.cover, cacheWidth: 200),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Match Angle',
                              style: context.text.micro.copyWith(color: context.colors.primary),
                            ),
                            Text(
                              _formatDate(referencePhoto.date),
                              style: context.text.micro.copyWith(color: context.colors.textLight),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ] else ...[
              // Confirm Row
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.insetSurface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: kIsWeb 
                        ? Image.network(_pickedImage!.path, width: 60, height: 60, fit: BoxFit.cover)
                        : Image.file(File(_pickedImage!.path), width: 60, height: 60, fit: BoxFit.cover, cacheWidth: 200),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Looks good?',
                            style: context.text.body.copyWith(color: context.colors.textDark),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _pickedImage = null),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              alignment: Alignment.centerLeft,
                            ),
                            child: Text(
                              'Retake',
                              style: context.text.caption.copyWith(color: context.colors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 24),
            TextField(
              controller: _weightController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: AppTheme.numeric(context.text.body.copyWith(color: context.colors.textDark)),
              decoration: InputDecoration(
                labelText: 'Weight (Optional)',
                prefixIcon: Icon(Icons.monitor_weight_outlined, color: context.colors.textLight),
                fillColor: context.colors.card,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.colors.primary, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              style: context.text.body.copyWith(color: context.colors.textDark),
              decoration: InputDecoration(
                labelText: 'Note (Optional)',
                prefixIcon: Icon(Icons.notes_rounded, color: context.colors.textLight),
                hintText: 'e.g. Post-workout pump',
                fillColor: context.colors.card,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.colors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: context.colors.primary, width: 2),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            PrimaryButton(
              onPressed: (_pickedImage != null && !_isSaving) ? _savePhoto : null,
              label: _isSaving ? 'Saving...' : 'Save Progress Photo',
            ),
          ],
        ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM dd').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

class _PoseSelectorOption extends StatelessWidget {
  const _PoseSelectorOption({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? context.colors.primary : context.colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? context.colors.primary : context.colors.border,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? context.colors.onPrimary : context.colors.primary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: context.text.micro.copyWith(color: isSelected ? context.colors.onPrimary : context.colors.textDark),
            ),
          ],
        ),
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  const _SourceTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          color: context.colors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: context.colors.border,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: context.colors.primary, size: 28),
            const SizedBox(height: 6),
            Text(
              label,
              style: context.text.micro.copyWith(color: context.colors.primary),
            ),
          ],
        ),
      ),
    );
  }
}

