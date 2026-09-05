import 'dart:io';
import 'dart:async';
import '../../../../services/ai_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../theme/app_colors.dart';
import '../../../providers/app_providers.dart';
import '../../../models/daily_meal_log.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/async_error_card.dart';
import '../../../widgets/offline_banner.dart';
import '../../../widgets/primary_button.dart';

/// Opens with photo-first capture, or describe-in-text when [isManualEntry] is true.
class PhotoCalorieScannerSheet extends ConsumerStatefulWidget {
  final String slotId;
  final String slotDisplayName;
  final bool isManualEntry;
  final MealSlotLog? appendToLog;

  const PhotoCalorieScannerSheet({
    super.key,
    required this.slotId,
    required this.slotDisplayName,
    this.isManualEntry = false,
    this.appendToLog,
  });

  @override
  ConsumerState<PhotoCalorieScannerSheet> createState() =>
      _PhotoCalorieScannerSheetState();
}

class _PhotoCalorieScannerSheetState
    extends ConsumerState<PhotoCalorieScannerSheet> {
  final _picker = ImagePicker();
  final _descriptionCtrl = TextEditingController();

  List<File> _selectedImages = [];
  bool _isAnalyzing = false;
  bool _analysisComplete = false;
  bool _describeMode = false;
  String? _confidence;
  String? _errorMessage;
  String? _techErrorMsg;
  AiErrorCause? _errorCause;
  bool _isOffline = false;

  int _analysisSessionToken = 0;
  Timer? _statusTimer;
  int _elapsedSeconds = 0;
  Timer? _countdownTimer;
  int _cooldownSeconds = 0;

  void _startStatusTimer() {
    _elapsedSeconds = 0;
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  void _startCooldown(int seconds) {
    _cooldownSeconds = seconds;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) {
          _cooldownSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  void _cancelAnalysis() {
    _analysisSessionToken++;
    _statusTimer?.cancel();
    setState(() {
      _isAnalyzing = false;
    });
  }

  List<MealItemLog> _items = [];
  int _totalCalories = 0;
  double _totalProtein = 0.0;
  double _totalCarbs = 0.0;
  double _totalFat = 0.0;

  @override
  void initState() {
    super.initState();
    _describeMode = widget.isManualEntry;
    if (_describeMode) {
      // Stay on describe form until she estimates or adds items herself.
      _analysisComplete = false;
    }
    _checkConnectivity();
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!mounted) return;
    setState(() {
      _isOffline = connectivityResult.contains(ConnectivityResult.none);
    });
  }

  void _applyResult(Map<String, dynamic> result) {
    if (!mounted) return;

    final itemsData = result['items'] as List?;
    final totalData = result['total'] as Map<String, dynamic>?;

    final newItems = (itemsData ?? []).map((i) {
      final m = i as Map<String, dynamic>;
      return MealItemLog(
        name: m['name']?.toString() ?? 'Unknown',
        portion: m['portion']?.toString() ?? '1 serving',
        calories: (m['calories'] as num?)?.toInt() ?? 0,
        proteinG: (m['protein_g'] as num?)?.toDouble() ?? 0.0,
        carbsG: (m['carbs_g'] as num?)?.toDouble() ?? 0.0,
        fatG: (m['fat_g'] as num?)?.toDouble() ?? 0.0,
      );
    }).toList();

    setState(() {
      if (widget.appendToLog != null) {
        _items = [...widget.appendToLog!.items, ...newItems];
        _totalCalories =
            widget.appendToLog!.totalCalories +
            ((totalData?['calories'] as num?)?.toInt() ?? 0);
        _totalProtein =
            widget.appendToLog!.totalProtein +
            ((totalData?['protein_g'] as num?)?.toDouble() ?? 0.0);
        _totalCarbs =
            widget.appendToLog!.totalCarbs +
            ((totalData?['carbs_g'] as num?)?.toDouble() ?? 0.0);
        _totalFat =
            widget.appendToLog!.totalFat +
            ((totalData?['fat_g'] as num?)?.toDouble() ?? 0.0);
      } else {
        _items = newItems;
        _totalCalories = (totalData?['calories'] as num?)?.toInt() ?? 0;
        _totalProtein = (totalData?['protein_g'] as num?)?.toDouble() ?? 0.0;
        _totalCarbs = (totalData?['carbs_g'] as num?)?.toDouble() ?? 0.0;
        _totalFat = (totalData?['fat_g'] as num?)?.toDouble() ?? 0.0;
      }
      _confidence = result['confidence']?.toString();
      _isAnalyzing = false;
      _analysisComplete = true;
      _errorMessage = null;
    });
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_selectedImages.length >= 3) return;
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (picked == null) return;

    setState(() {
      _selectedImages.add(File(picked.path));
      _describeMode = false;
      _isAnalyzing = false;
      _analysisComplete = false;
      _errorMessage = null;
      // We do not clear _descriptionCtrl so the user's hint is preserved
      // We do not clear _items so they don't lose manually entered items before re-analysis
    });
  }

  Future<void> _analyzeImage({bool skipCache = false}) async {
    if (_selectedImages.isEmpty) return;

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _techErrorMsg = null;
      _errorCause = null;
    });
    final currentToken = ++_analysisSessionToken;
    _startStatusTimer();

    try {
      final List<Uint8List> allBytes = [];
      for (var f in _selectedImages) {
        allBytes.add(await f.readAsBytes());
      }

      String mimeType = 'image/jpeg';
      if (_selectedImages.first.path.toLowerCase().endsWith('.png')) {
        mimeType = 'image/png';
      } else if (_selectedImages.first.path.toLowerCase().endsWith('.webp')) {
        mimeType = 'image/webp';
      }

      final result = await ref
          .read(geminiFoodServiceProvider)
          .analyzeFoodImage(
            allBytes,
            mimeType,
            _descriptionCtrl.text,
            skipCache,
          );

      if (!mounted) return;

      if (currentToken != _analysisSessionToken) return;
      _statusTimer?.cancel();
      if (result != null) {
        _applyResult(result);
      } else {
        _showError('AI could not analyze the image.');
      }
    } catch (e) {
      if (!mounted) return;
      _handleAnalyzeError(e);
    }
  }

  Future<void> _analyzeDescription() async {
    final text = _descriptionCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Type what you ate first — e.g. rice, sambar, curd'),
        ),
      );
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _analysisComplete = false;
      _errorMessage = null;
      _techErrorMsg = null;
      _errorCause = null;
      _items = [];
      _selectedImages = [];
    });
    final currentToken = ++_analysisSessionToken;
    _startStatusTimer();

    try {
      final result = await ref
          .read(geminiFoodServiceProvider)
          .analyzeFoodText(text);

      if (!mounted) return;

      if (currentToken != _analysisSessionToken) return;
      _statusTimer?.cancel();
      if (result != null) {
        _applyResult(result);
      } else {
        _showError('AI could not estimate from that description.');
      }
    } catch (e) {
      if (!mounted) return;
      _handleAnalyzeError(e);
    }
  }

  void _handleAnalyzeError(Object e) {
    _statusTimer?.cancel();
    final msg = e
        .toString()
        .replaceAll('Exception: ', '')
        .replaceAll('AiException: ', '');
    String humanMsg = msg;
    AiErrorCause? cause;

    if (e is AiException) {
      cause = e.cause;
    }

    if (cause == AiErrorCause.rateLimited) {
      _startCooldown(90);
    } else if (cause == AiErrorCause.overloaded) {
      _startCooldown(30);
    }

    if (msg.contains('OFFLINE_FALLBACK') ||
        msg.contains('Service temporarily unavailable')) {
      humanMsg = 'OFFLINE_FALLBACK';
    }

    setState(() {
      _isAnalyzing = false;
      _errorMessage = humanMsg;
      _techErrorMsg = msg;
      _errorCause = cause;
    });
  }

  void _showError(String message) {
    _statusTimer?.cancel();
    setState(() {
      _isAnalyzing = false;
      _errorMessage = message;
    });
  }

  void _switchToDescribe() {
    setState(() {
      _describeMode = true;
      _selectedImages = [];
      _analysisComplete = false;
      _errorMessage = null;
      _isAnalyzing = false;
      _items = [];
    });
  }

  void _switchToPhoto() {
    setState(() {
      _describeMode = false;
      _analysisComplete = false;
      _errorMessage = null;
      _isAnalyzing = false;
      _items = [];
    });
  }

  void _enterManualItems() {
    setState(() {
      _errorMessage = null;
      _isAnalyzing = false;
      _analysisComplete = true;
      if (_items.isEmpty) {
        if (widget.appendToLog != null) {
          _items = List.from(widget.appendToLog!.items);
          _totalCalories = widget.appendToLog!.totalCalories;
          _totalProtein = widget.appendToLog!.totalProtein;
          _totalCarbs = widget.appendToLog!.totalCarbs;
          _totalFat = widget.appendToLog!.totalFat;
        } else {
          _items = [
            MealItemLog(
              name: 'Home cooked meal',
              portion: '1 serving',
              calories: 0,
              proteinG: 0,
              carbsG: 0,
              fatG: 0,
            ),
          ];
        }
      }
    });
    if (_items.length == 1 && _items.first.calories == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _editItem(0));
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
      _recalculateTotals();
    });
  }

  void _editItem(int index) {
    final item = _items[index];
    final nameCtrl = TextEditingController(text: item.name);
    final portionCtrl = TextEditingController(text: item.portion);
    final calsCtrl = TextEditingController(text: item.calories.toString());
    final pCtrl = TextEditingController(text: item.proteinG.toString());
    final cCtrl = TextEditingController(text: item.carbsG.toString());
    final fCtrl = TextEditingController(text: item.fatG.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Edit Item',
          style: TextStyle(
            color: context.colors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: TextStyle(color: context.colors.textMedium),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: context.colors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: portionCtrl,
                decoration: InputDecoration(
                  labelText: 'Portion',
                  labelStyle: TextStyle(color: context.colors.textMedium),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: context.colors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: calsCtrl,
                decoration: InputDecoration(
                  labelText: 'Calories',
                  labelStyle: TextStyle(color: context.colors.textMedium),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: context.colors.primary),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: pCtrl,
                      decoration: InputDecoration(
                        labelText: 'Pro(g)',
                        labelStyle: TextStyle(
                          color: context.colors.textMedium,
                          fontSize: 13,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 8,
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: context.colors.primary),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: cCtrl,
                      decoration: InputDecoration(
                        labelText: 'Carb(g)',
                        labelStyle: TextStyle(
                          color: context.colors.textMedium,
                          fontSize: 13,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 8,
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: context.colors.primary),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: fCtrl,
                      decoration: InputDecoration(
                        labelText: 'Fat(g)',
                        labelStyle: TextStyle(
                          color: context.colors.textMedium,
                          fontSize: 13,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 0,
                          vertical: 8,
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: context.colors.primary),
                        ),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: context.colors.textMedium,
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _items[index] = MealItemLog(
                  name: nameCtrl.text,
                  portion: portionCtrl.text,
                  calories: int.tryParse(calsCtrl.text) ?? 0,
                  proteinG: double.tryParse(pCtrl.text) ?? 0.0,
                  carbsG: double.tryParse(cCtrl.text) ?? 0.0,
                  fatG: double.tryParse(fCtrl.text) ?? 0.0,
                );
                _recalculateTotals();
              });
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: context.colors.primary,
              foregroundColor: context.colors.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _addItem() {
    _items.add(
      MealItemLog(
        name: 'New Item',
        portion: '1 serving',
        calories: 0,
        proteinG: 0,
        carbsG: 0,
        fatG: 0,
      ),
    );
    _editItem(_items.length - 1);
  }

  void _recalculateTotals() {
    int c = 0;
    double p = 0;
    double carbs = 0;
    double f = 0;
    for (final i in _items) {
      c += i.calories ?? 0;
      p += i.proteinG ?? 0.0;
      carbs += i.carbsG ?? 0.0;
      f += i.fatG ?? 0.0;
    }
    _totalCalories = c;
    _totalProtein = p;
    _totalCarbs = carbs;
    _totalFat = f;
  }

  Future<void> _saveMeal() async {
    String? finalPhotoPath;
    if (_selectedImages.isNotEmpty) {
      if (!kIsWeb) {
        final appDir = await getApplicationDocumentsDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = 'meal_photo_$timestamp.jpg';
        final savedImage = await _selectedImages.first.copy(
          '${appDir.path}/$fileName',
        );
        finalPhotoPath = savedImage.path;
      } else {
        finalPhotoPath = _selectedImages.first.path;
      }
    }

    final slotLog = MealSlotLog(
      name: widget.slotDisplayName,
      photoPath: finalPhotoPath ?? widget.appendToLog?.photoPath,
      items: _items,
      totalCalories: _totalCalories,
      totalProtein: _totalProtein,
      totalCarbs: _totalCarbs,
      totalFat: _totalFat,
      confidence: _confidence ?? widget.appendToLog?.confidence,
    );
    await ref
        .read(dailyMealLogProvider.notifier)
        .saveMealSlot(widget.slotId, slotLog);

    if (mounted) {
      // ignore: unawaited_futures
      Haptics.toggle();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Logged $_totalCalories kcal for ${widget.slotDisplayName}!',
          ),
          backgroundColor: context.colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final showChooser =
        !_analysisComplete &&
        !_isAnalyzing &&
        _errorMessage == null &&
        _selectedImages.isEmpty;

    final title = widget.appendToLog != null
        ? 'Add to ${widget.slotDisplayName}'
        : 'Log ${widget.slotDisplayName}';

    return AppSheet(
      scrollable: _analysisComplete,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isOffline && !_analysisComplete)
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: OfflineBanner(),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.colors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colors.border),
                ),
                child: Icon(
                  widget.appendToLog != null
                      ? Icons.add_circle_outline_rounded
                      : _describeMode
                      ? Icons.edit_note_rounded
                      : Icons.camera_alt_rounded,
                  color: context.colors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'CabinetGrotesk',
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: context.colors.textDark,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.appendToLog != null
                          ? 'Add another serving to this meal'
                          : _describeMode
                          ? 'Describe home cooking — AI estimates macros'
                          : 'Photo of your plate works best for home meals',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: context.colors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          if (showChooser && !_describeMode) ...[
            SurfaceCard(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              child: Column(
                children: [
                  Icon(
                    Icons.camera_alt_rounded,
                    size: 40,
                    color: context.colors.textDark,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Snap what you ate',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.colors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Best for home-cooked plates',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: context.colors.textMedium,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickImage(ImageSource.camera),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: context.colors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.colors.primary.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_rounded, size: 18, color: context.colors.primary),
                                const SizedBox(width: 8),
                                Text('Camera', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.colors.primary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickImage(ImageSource.gallery),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: context.colors.scaffoldBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: context.colors.border),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.photo_library_rounded, size: 18, color: context.colors.textDark),
                                const SizedBox(width: 8),
                                Text('Gallery', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.colors.textDark)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Minimalist Tile for secondary action
            InkWell(
              onTap: _switchToDescribe,
              borderRadius: BorderRadius.circular(20),
              child: SurfaceCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.notes_rounded, color: context.colors.textDark, size: 20),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Or describe in text',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textDark,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, color: context.colors.textMedium, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Minimalist Tile for manual macros
            InkWell(
              onTap: _enterManualItems,
              borderRadius: BorderRadius.circular(20),
              child: SurfaceCard(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.edit_note_rounded, color: context.colors.textDark, size: 20),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Enter macros yourself',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.colors.textDark,
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, color: context.colors.textMedium, size: 16),
                  ],
                ),
              ),
            ),
          ] else if (showChooser && _describeMode) ...[
            Text(
              'What did you eat?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: context.colors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionCtrl,
              maxLines: 4,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                hintText: 'e.g. 1 cup rice, chicken curry, beans fry, curd',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 14),
            PrimaryButton(
              label: 'Estimate macros',
              icon: Icons.auto_awesome_rounded,
              onPressed: _isOffline ? null : _analyzeDescription,
              isLoading: _isAnalyzing,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _switchToPhoto,
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Use photo'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    onPressed: _enterManualItems,
                    child: const Text('Enter yourself'),
                  ),
                ),
              ],
            ),
          ] else if (_errorMessage == 'OFFLINE_FALLBACK') ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.cloud_off_rounded,
                    color: Colors.orange,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI Service Offline',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The AI system is temporarily overwhelmed or unavailable. Please log your macros manually for now.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.orange[800]),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _enterManualItems,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Enter manual macros'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.red.withValues(alpha: 0.1),
                border: Border.all(
                  color: context.colors.red.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        color: context.colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: context.colors.textDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_techErrorMsg != null &&
                      _techErrorMsg != _errorMessage) ...[
                    const SizedBox(height: 12),
                    Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Text(
                          'Details',
                          style: TextStyle(
                            fontSize: 13,
                            color: context.colors.red,
                          ),
                        ),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        children: [
                          Text(
                            _techErrorMsg!,
                            style: TextStyle(
                              fontSize: 12,
                              fontFamily: 'monospace',
                              color: context.colors.textMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _cooldownSeconds > 0
                        ? null
                        : () {
                            setState(() => _errorMessage = null);
                            if (_describeMode) {
                              _analyzeDescription();
                            } else if (_selectedImages.isNotEmpty) {
                              _analyzeImage(skipCache: true);
                            } else {
                              _pickImage(ImageSource.gallery);
                            }
                          },
                    icon: _cooldownSeconds > 0
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      _cooldownSeconds > 0
                          ? 'Wait $_cooldownSeconds s...'
                          : 'Try again',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() => _errorMessage = null);
                      _switchToDescribe();
                    },
                    child: const Text('Describe instead'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _enterManualItems,
                    child: const Text('Enter yourself'),
                  ),
                ),
              ],
            ),
          ] else if (_selectedImages.isNotEmpty || _isAnalyzing) ...[
            if (_selectedImages.isNotEmpty)
              Column(
                children: [
                  SizedBox(
                    height: 160,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount:
                          _selectedImages.length +
                          (_selectedImages.length < 3 ? 1 : 0),
                      separatorBuilder: (context, index) =>
                          const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        if (index == _selectedImages.length) {
                          // Add angle button
                          return GestureDetector(
                            onTap: () => _pickImage(ImageSource.camera),
                            child: Container(
                              width: 120,
                              decoration: BoxDecoration(
                                color: context.colors.primary.withValues(
                                  alpha: 0.1,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: context.colors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_a_photo_rounded,
                                    color: context.colors.primary,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add angle\n(Max 3)',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: context.colors.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        final img = _selectedImages[index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Stack(
                            children: [
                              kIsWeb
                                  ? Image.network(
                                      img.path,
                                      width: 160,
                                      height: 160,
                                      fit: BoxFit.cover,
                                    )
                                  : Image.file(
                                      img,
                                      width: 160,
                                      height: 160,
                                      fit: BoxFit.cover,
                                    ),
                              if (!_isAnalyzing)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _selectedImages.removeAt(index);
                                        if (_selectedImages.isEmpty)
                                          _analysisComplete = false;
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: context.colors.onPrimary,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (_isAnalyzing)
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: context.colors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.colors.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: context.colors.primary,
                              strokeWidth: 2.5,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              _elapsedSeconds > 15
                                  ? 'Still working — big plates take a moment...'
                                  : 'AI is analyzing your meal...',
                              style: TextStyle(
                                color: context.colors.textDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.cancel_rounded,
                              color: context.colors.textMedium,
                            ),
                            onPressed: _cancelAnalysis,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            if (_selectedImages.isNotEmpty &&
                !_isAnalyzing &&
                !_analysisComplete) ...[
              const SizedBox(height: 16),
              Text(
                'Optional hint',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textDark,
                ),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _descriptionCtrl,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'e.g. This is chicken biryani, normal portion',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Analyze Photo',
                icon: Icons.auto_awesome_rounded,
                onPressed: _isOffline ? null : _analyzeImage,
                isLoading: _isAnalyzing,
              ),
            ] else if (_isAnalyzing)
              Container(
                margin: const EdgeInsets.symmetric(
                  vertical: 40,
                  horizontal: 20,
                ),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: context.colors.primary.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        color: context.colors.primary,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _elapsedSeconds > 15
                          ? 'Still working — big requests take a moment...'
                          : 'AI is estimating macros...',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: context.colors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This usually takes 2-4 seconds',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _cancelAnalysis,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel Analysis'),
                      style: TextButton.styleFrom(
                        foregroundColor: context.colors.textMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ],

          if (_analysisComplete) ...[
            const SizedBox(height: 16),
            if (_confidence == 'low' || _confidence == 'medium')
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _confidence == 'low'
                      ? context.colors.red.withValues(alpha: 0.1)
                      : context.colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      _confidence == 'low'
                          ? Icons.error_outline_rounded
                          : Icons.warning_amber_rounded,
                      color: _confidence == 'low'
                          ? context.colors.red
                          : context.colors.orange,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _confidence == 'low'
                            ? 'Low confidence estimate — please check portions carefully.'
                            : 'AI is somewhat unsure about this meal — please verify portions.',
                        style: TextStyle(
                          color: _confidence == 'low'
                              ? context.colors.red
                              : context.colors.orange,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView.separated(
                physics: const BouncingScrollPhysics(),
                itemCount: _items.length,
                separatorBuilder: (_, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return Dismissible(
                    key: ValueKey('${item.name}_$index'),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: context.colors.red,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: context.colors.onPrimary,
                      ),
                    ),
                    onDismissed: (_) => _removeItem(index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      color: Colors.transparent,
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name ?? 'Unknown',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16,
                                    color: context.colors.textDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item.portion} • ${item.calories} kcal',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: context.colors.primary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildMacroPill(
                                      context,
                                      'Protein',
                                      '${item.proteinG?.toStringAsFixed(1) ?? '0'}g',
                                      const Color(0xFFE8A163),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildMacroPill(
                                      context,
                                      'Carbs',
                                      '${item.carbsG?.toStringAsFixed(1) ?? '0'}g',
                                      const Color(0xFF8FB896),
                                    ),
                                    const SizedBox(width: 8),
                                    _buildMacroPill(
                                      context,
                                      'Fat',
                                      '${item.fatG?.toStringAsFixed(1) ?? '0'}g',
                                      const Color(0xFFE58B88),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.edit_rounded,
                              size: 20,
                              color: context.colors.textMedium,
                            ),
                            onPressed: () => _editItem(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'TOTAL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: context.colors.primary,
                          ),
                        ),
                        Text(
                          '$_totalCalories kcal',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: context.colors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add Item'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Save Log',
              icon: Icons.check_circle_rounded,
              onPressed: _saveMeal,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMacroPill(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
