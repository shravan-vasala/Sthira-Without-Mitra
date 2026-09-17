import 'dart:io';
import 'dart:async';
import '../../../services/ai_client.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../services/haptics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../../theme/app_colors.dart';
import '../../../providers/app_providers.dart';
import '../../../models/daily_meal_log.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:isar/isar.dart';
import '../../../models/user_food_log.dart';
import '../../../widgets/app_bottom_sheet.dart';
import '../../../widgets/surface_card.dart';
import '../../../models/food_nutrition.dart';
import '../../../widgets/offline_banner.dart';
import '../../../widgets/primary_button.dart';
import 'package:trufit_bodamma/theme/app_typography.dart';

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
  bool _isSavingMeal = false;

  int _analysisSessionToken = 0;
  Timer? _statusTimer;
  int _elapsedSeconds = 0;
  Timer? _countdownTimer;
  int _cooldownSeconds = 0;
  CancellationToken? _cancellationToken;

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
    _cancellationToken?.cancel();
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
  int _unresolvedCount = 0;

  final Map<int, MealItemLog> _baseItems = {};
  final Map<int, double> _itemScales = {};

  late String _initialDate;
  late String _initialUid;

  @override
  void initState() {
    super.initState();
    _initialDate = ref.read(dateStringProvider);
    _initialUid = ref.read(authServiceProvider).uid ?? '';

    _describeMode = widget.isManualEntry;
    if (_describeMode) {
      // Stay on describe form until she estimates or adds items herself.
      _analysisComplete = false;
    }
    _checkConnectivity();
  }

  @override
  void dispose() {
    _cancellationToken?.cancel();
    _statusTimer?.cancel();
    _countdownTimer?.cancel();
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
        computedNutrition: FoodNutrition(
          kcal: (m['calories'] as num?)?.toDouble() ?? 0,
          proteinG: (m['protein_g'] as num?)?.toDouble() ?? 0.0,
          carbsG: (m['carbs_g'] as num?)?.toDouble() ?? 0.0,
          fatG: (m['fat_g'] as num?)?.toDouble() ?? 0.0,
        ),
        baseNutrition: m['baseNutrition'] != null
            ? FoodNutrition.fromJson(m['baseNutrition'])
            : null,
        isPer100g: m['is_per_100g'] as bool? ?? false,
        servingGrams: (m['serving_grams'] as num?)?.toDouble(),
        consumedGrams: (m['estimated_grams'] as num?)?.toDouble(),
        provenance: m['provenance'] as String?,
        resolved: m['resolved'] as bool? ?? true,
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
      _unresolvedCount = (totalData?['unresolved_count'] as num?)?.toInt() ?? 0;
      _confidence = result['confidence']?.toString();
      _isAnalyzing = false;
      _analysisComplete = true;
      _errorMessage = null;

      _baseItems.clear();
      _itemScales.clear();
      for (int i = 0; i < _items.length; i++) {
        _baseItems[i] = _cloneItem(_items[i]);
        _itemScales[i] = 1.0;
      }
    });
  }

  MealItemLog _cloneItem(MealItemLog src) {
    return MealItemLog(
      name: src.name,
      portion: src.portion,
      computedNutrition: src.computedNutrition != null
          ? FoodNutrition(
              kcal: src.computedNutrition!.kcal,
              proteinG: src.computedNutrition!.proteinG,
              carbsG: src.computedNutrition!.carbsG,
              fatG: src.computedNutrition!.fatG,
            )
          : null,
      baseNutrition: src.baseNutrition != null
          ? FoodNutrition(
              kcal: src.baseNutrition!.kcal,
              proteinG: src.baseNutrition!.proteinG,
              carbsG: src.baseNutrition!.carbsG,
              fatG: src.baseNutrition!.fatG,
            )
          : null,
      resolved: src.resolved,
      provenance: src.provenance,
      isPer100g: src.isPer100g,
      servingGrams: src.servingGrams,
      consumedGrams: src.consumedGrams,
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_selectedImages.length >= 3) return;
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 90,
    );
    if (picked == null) return;

    _analysisSessionToken++;
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
    _cancellationToken?.cancel();
    _cancellationToken = CancellationToken();

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
            _cancellationToken,
          );

      if (!mounted) return;

      if (currentToken != _analysisSessionToken) return;
      _statusTimer?.cancel();
      if (result != null) {
        _applyResult(result);
      } else {
        _showError('AI could not analyze the image.', currentToken);
      }
    } catch (e) {
      if (!mounted) return;
      _handleAnalyzeError(e, currentToken);
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
    _cancellationToken?.cancel();
    _cancellationToken = CancellationToken();
    _startStatusTimer();

    try {
      final result = await ref
          .read(geminiFoodServiceProvider)
          .analyzeFoodText(text, _cancellationToken);

      if (!mounted) return;

      if (currentToken != _analysisSessionToken) return;
      _statusTimer?.cancel();
      if (result != null) {
        _applyResult(result);
      } else {
        _showError(
          'AI could not estimate from that description.',
          currentToken,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _handleAnalyzeError(e, currentToken);
    }
  }

  void _handleAnalyzeError(Object e, int token) {
    if (token != _analysisSessionToken) return;
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

  void _showError(String message, int token) {
    if (token != _analysisSessionToken) return;
    _statusTimer?.cancel();
    setState(() {
      _isAnalyzing = false;
      _errorMessage = message;
    });
  }

  void _switchToDescribe() {
    _analysisSessionToken++;
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
    _analysisSessionToken++;
    setState(() {
      _describeMode = false;
      _analysisComplete = false;
      _errorMessage = null;
      _isAnalyzing = false;
      _items = [];
    });
  }

  void _enterManualItems() {
    _analysisSessionToken++;
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
              name: 'Unknown Dish',
              portion: '1 serving',
              computedNutrition: FoodNutrition(
                kcal: 0,
                proteinG: 0,
                carbsG: 0,
                fatG: 0,
              ),
            ),
          ];
        }
      }
      for (int i = 0; i < _items.length; i++) {
        _baseItems[i] = _cloneItem(_items[i]);
        _itemScales[i] = 1.0;
      }
    });
    if (_items.length == 1 &&
        (_items.first.computedNutrition?.kcal ?? 0) == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _editItem(0));
    }
  }

  void _removeItem(int index) {
    final removedItem = _items[index];
    final removedBase = _baseItems[index];
    final removedScale = _itemScales[index];

    setState(() {
      _items.removeAt(index);

      for (int i = index; i < _items.length; i++) {
        _baseItems[i] = _baseItems[i + 1]!;
        _itemScales[i] = _itemScales[i + 1]!;
      }
      _baseItems.remove(_items.length);
      _itemScales.remove(_items.length);

      _recalculateTotals();
    });

    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${removedItem.name} removed'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Undo',
          textColor: context.colors.primary,
          onPressed: () {
            setState(() {
              _items.insert(index, removedItem);

              for (int i = _items.length - 1; i > index; i--) {
                _baseItems[i] = _baseItems[i - 1]!;
                _itemScales[i] = _itemScales[i - 1]!;
              }
              if (removedBase != null) _baseItems[index] = removedBase;
              if (removedScale != null) _itemScales[index] = removedScale;

              _recalculateTotals();
            });
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _editItem(int? index) {
    final item = index != null
        ? _items[index]
        : MealItemLog(
            name: 'New Item',
            portion: '1 serving',
            computedNutrition: FoodNutrition(
              kcal: 0,
              proteinG: 0,
              carbsG: 0,
              fatG: 0,
            ),
          );
    final nameCtrl = TextEditingController(text: item.name);
    final portionCtrl = TextEditingController(text: item.portion);
    final calsCtrl = TextEditingController(
      text: item.computedNutrition?.kcal.round().toString() ?? '0',
    );
    final pCtrl = TextEditingController(
      text: item.computedNutrition?.proteinG.toString() ?? '0.0',
    );
    final cCtrl = TextEditingController(
      text: item.computedNutrition?.carbsG.toString() ?? '0.0',
    );
    final fCtrl = TextEditingController(
      text: item.computedNutrition?.fatG.toString() ?? '0.0',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit Item',
          style: context.text.body.copyWith(color: context.colors.textDark),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Name',
                  labelStyle: context.text.body.copyWith(
                    color: context.colors.textMedium,
                  ),
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
                  labelStyle: context.text.body.copyWith(
                    color: context.colors.textMedium,
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: context.colors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: calsCtrl,
                style: context.text.body,
                decoration: InputDecoration(
                  labelText: 'Calories',
                  labelStyle: context.text.body.copyWith(
                    color: context.colors.textMedium,
                  ),
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
                      style: context.text.body,
                      decoration: InputDecoration(
                        labelText: 'Pro(g)',
                        labelStyle: context.text.caption.copyWith(
                          color: context.colors.textMedium,
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
                      style: context.text.body,
                      decoration: InputDecoration(
                        labelText: 'Carb(g)',
                        labelStyle: context.text.caption.copyWith(
                          color: context.colors.textMedium,
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
                      style: context.text.body,
                      decoration: InputDecoration(
                        labelText: 'Fat(g)',
                        labelStyle: context.text.caption.copyWith(
                          color: context.colors.textMedium,
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
                final cVal = (int.tryParse(calsCtrl.text) ?? 0).clamp(0, 9999);
                final pVal = (double.tryParse(pCtrl.text) ?? 0.0).clamp(
                  0.0,
                  999.9,
                );
                final carbsVal = (double.tryParse(cCtrl.text) ?? 0.0).clamp(
                  0.0,
                  999.9,
                );
                final fVal = (double.tryParse(fCtrl.text) ?? 0.0).clamp(
                  0.0,
                  999.9,
                );

                final newItem = MealItemLog(
                  name: nameCtrl.text,
                  portion: portionCtrl.text,
                  computedNutrition: FoodNutrition(
                    kcal: cVal.toDouble(),
                    proteinG: pVal,
                    carbsG: carbsVal,
                    fatG: fVal,
                  ),
                  baseNutrition: item.baseNutrition,
                  isPer100g: item.isPer100g,
                  servingGrams: item.servingGrams,
                  consumedGrams: item.consumedGrams,
                  resolved: true,
                );
                newItem.provenance = 'yours';

                if (index != null) {
                  _items[index] = newItem;
                  _baseItems[index] = _cloneItem(newItem);
                  _itemScales[index] = 1.0;
                } else {
                  _items.add(newItem);
                  _baseItems[_items.length - 1] = _cloneItem(newItem);
                  _itemScales[_items.length - 1] = 1.0;
                }

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
    _editItem(null);
  }

  void _setPortionScale(int index, double scale) {
    if (_baseItems[index] == null) return;
    Haptics.tap();
    setState(() {
      _itemScales[index] = scale;
      final base = _baseItems[index]!;
      FoodNutrition? newComputed;
      bool newResolved = base.resolved;
      final newConsumedGrams = base.consumedGrams != null
          ? (base.consumedGrams! * scale)
          : null;

      if (base.baseNutrition != null && newConsumedGrams != null) {
        try {
          newComputed = FoodNutrition.compute(
            consumedGrams: newConsumedGrams,
            baseNutrition: base.baseNutrition!,
            isPer100g: base.isPer100g,
            servingGrams: base.servingGrams,
          );
          newResolved = true;
        } on FormatException catch (_) {
          newResolved = false;
        }
      } else {
        newComputed = FoodNutrition(
          kcal: ((base.computedNutrition?.kcal ?? 0) * scale).roundToDouble(),
          proteinG: double.parse(
            ((base.computedNutrition?.proteinG ?? 0.0) * scale).toStringAsFixed(
              1,
            ),
          ),
          carbsG: double.parse(
            ((base.computedNutrition?.carbsG ?? 0.0) * scale).toStringAsFixed(
              1,
            ),
          ),
          fatG: double.parse(
            ((base.computedNutrition?.fatG ?? 0.0) * scale).toStringAsFixed(1),
          ),
        );
      }

      _items[index] = MealItemLog(
        name: base.name,
        portion: base.portion,
        computedNutrition: newComputed,
        baseNutrition: base.baseNutrition,
        isPer100g: base.isPer100g,
        servingGrams: base.servingGrams,
        consumedGrams: newConsumedGrams,
        provenance: base.provenance,
        resolved: newResolved,
      );
      _recalculateTotals();
    });
  }

  void _recalculateTotals() {
    int c = 0;
    double p = 0;
    double carbs = 0;
    double f = 0;
    int unresolved = 0;
    for (final i in _items) {
      c += i.computedNutrition?.kcal.round() ?? 0;
      p += i.computedNutrition?.proteinG ?? 0.0;
      carbs += i.computedNutrition?.carbsG ?? 0.0;
      f += i.computedNutrition?.fatG ?? 0.0;
      if (i.resolved == false) unresolved++;
    }
    _totalCalories = c;
    _totalProtein = p;
    _totalCarbs = carbs;
    _totalFat = f;
    _unresolvedCount = unresolved;
  }

  Future<void> _saveMeal() async {
    if (_isSavingMeal) return;
    setState(() => _isSavingMeal = true);

    try {
      List<String> finalPhotoPaths = [];
      String? fallbackPhotoPath;

      if (_selectedImages.isNotEmpty) {
        if (!kIsWeb) {
          final mediaRepo = ref.read(mediaRepoProvider);
          for (int i = 0; i < _selectedImages.length; i++) {
            final relPath = await mediaRepo.saveMediaFile(
              _selectedImages[i].path,
              'meal_photos',
            );
            finalPhotoPaths.add(relPath);
          }
          fallbackPhotoPath = finalPhotoPaths.first;
        } else {
          finalPhotoPaths = _selectedImages.map((f) => f.path).toList();
          fallbackPhotoPath = finalPhotoPaths.first;
        }
      }

      final slotLog = MealSlotLog(
        name: widget.slotDisplayName,
        photoPath: fallbackPhotoPath ?? widget.appendToLog?.photoPath,
        photoPaths: [
          ...(widget.appendToLog?.photoPaths ?? []),
          ...finalPhotoPaths,
        ],
        items: _items,
        totalCalories: _totalCalories,
        totalProtein: _totalProtein,
        totalCarbs: _totalCarbs,
        totalFat: _totalFat,
        confidence: _confidence ?? widget.appendToLog?.confidence,
      );

      // Personal Portion Memory: Ensure 'yours' and 'ai_estimate' modifications are written back to the local brain
      try {
        final isar = Isar.instanceNames.isNotEmpty
            ? Isar.getInstance(Isar.instanceNames.first)
            : null;
        if (isar != null) {
          for (var i in _items) {
            if ((i.provenance == 'yours' || i.provenance == 'ai_estimate') &&
                (i.computedNutrition?.kcal ?? 0) > 0) {
              final normalized = i.name?.toLowerCase().trim();
              if (normalized != null && normalized.isNotEmpty) {
                await isar.writeTxn(() async {
                  if (i.provenance == 'yours') {
                    // If it already exists, overwrite it so prioritizing her latest manual portion
                    await isar.userFoodLogs
                        .filter()
                        .normalizedNameEqualTo(normalized)
                        .deleteAll();
                  } else if (i.provenance == 'ai_estimate') {
                    // AI estimates only save if missing.
                    final count = await isar.userFoodLogs
                        .filter()
                        .normalizedNameEqualTo(normalized)
                        .count();
                    if (count > 0) return;
                  }
                  await isar.userFoodLogs.put(
                    UserFoodLog(
                      normalizedName: normalized,
                      originalName: i.name!,
                      baseNutrition: i.computedNutrition ?? FoodNutrition(),
                      isPer100g: false,
                      servingGrams: i.consumedGrams,
                      provenance: i.provenance,
                      addedAt: DateTime.now(),
                    ),
                  );
                });
              }
            }
          }
        }
      } catch (_) {
        // silently fail portion memory if db throws
      }

      final currentDate = ref.read(dateStringProvider);
      final currentUid = ref.read(authServiceProvider).uid ?? '';

      if (currentDate != _initialDate || currentUid != _initialUid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Date or account changed. Cannot save into stale log.',
              ),
            ),
          );
        }
        setState(() => _isSavingMeal = false);
        return;
      }

      await ref
          .read(dailyMealLogProvider.notifier)
          .saveMealSlot(widget.slotId, slotLog, targetDate: _initialDate);

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to save meal. Please try again.'),
            backgroundColor: context.colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingMeal = false);
      }
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
      title: title,
      subtitle: widget.appendToLog != null
          ? 'Add another serving to this meal'
          : _describeMode
          ? 'Describe home cooking — AI estimates macros'
          : 'Photo of your plate works best for home meals',
      scrollable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isOffline && !_analysisComplete)
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: OfflineBanner(),
            ),

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
                    style: context.text.cardTitle.copyWith(
                      color: context.colors.textDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Best for home-cooked plates',
                    style: context.text.caption.copyWith(
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_rounded,
                                  size: 18,
                                  color: context.colors.primary,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Camera',
                                  style: context.text.bodyStrong.copyWith(
                                    color: context.colors.primary,
                                  ),
                                ),
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
                                Icon(
                                  Icons.photo_library_rounded,
                                  size: 18,
                                  color: context.colors.textDark,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Gallery',
                                  style: context.text.bodyStrong.copyWith(
                                    color: context.colors.textDark,
                                  ),
                                ),
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
                    Icon(
                      Icons.notes_rounded,
                      color: context.colors.textDark,
                      size: 20,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Or describe in text',
                        style: context.text.bodyStrong.copyWith(
                          color: context.colors.textDark,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.colors.textMedium,
                      size: 16,
                    ),
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
                    Icon(
                      Icons.edit_note_rounded,
                      color: context.colors.textDark,
                      size: 20,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Enter macros yourself',
                        style: context.text.bodyStrong.copyWith(
                          color: context.colors.textDark,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.colors.textMedium,
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ] else if (showChooser && _describeMode) ...[
            Text(
              'What did you eat?',
              style: context.text.body.copyWith(color: context.colors.textDark),
            ),
            const SizedBox(height: 8),
            _MyFoodsScroller(
              onFoodTap: (food) {
                // Instantly inject validated personal food
                if (!mounted) return;
                setState(() {
                  _describeMode = false;
                  _isAnalyzing = false;
                  _analysisComplete = true;
                  _errorMessage = null;
                  final item = MealItemLog(
                    name: food.originalName,
                    portion: '1 serving',
                    computedNutrition: FoodNutrition(
                      kcal: food.baseNutrition.kcal,
                      proteinG: food.baseNutrition.proteinG,
                      carbsG: food.baseNutrition.carbsG,
                      fatG: food.baseNutrition.fatG,
                    ),
                    resolved: true,
                  );
                  item.provenance = 'verified'; // It's from Personal memory

                  if (_items.isEmpty) {
                    if (widget.appendToLog != null) {
                      _items = List.from(widget.appendToLog!.items);
                    }
                  }
                  _items.add(item);
                  final newIndex = _items.length - 1;
                  _baseItems[newIndex] = _cloneItem(item);
                  _itemScales[newIndex] = 1.0;
                  _recalculateTotals();
                });
              },
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
                color: context.colors.orange.withValues(alpha: 0.1),
                border: Border.all(
                  color: context.colors.orange.withValues(alpha: 0.3),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    color: context.colors.orange,
                    size: 36,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'AI Service Offline',
                    style: context.text.bodyStrong.copyWith(
                      color: context.colors.orange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'The AI system is temporarily overwhelmed or unavailable. Please log your macros manually for now.',
                    textAlign: TextAlign.center,
                    style: context.text.caption.copyWith(
                      color: context.colors.orange,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _enterManualItems,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Enter manual macros'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.colors.orange,
                        foregroundColor: context.colors.onPrimary,
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
                          style: context.text.body.copyWith(
                            color: context.colors.textDark,
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
                          style: context.text.caption.copyWith(
                            color: context.colors.red,
                          ),
                        ),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        children: [
                          Text(
                            _techErrorMsg!,
                            style: context.text.micro.copyWith(
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
                      foregroundColor: context.colors.onPrimary,
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
                                    style: context.text.micro.copyWith(
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
                                        if (_selectedImages.isEmpty) {
                                          _analysisComplete = false;
                                        }
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: context.colors.textDark
                                            .withValues(alpha: 0.54),
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
                              _elapsedSeconds < 2
                                  ? 'Preparing image...'
                                  : _elapsedSeconds < 6
                                  ? 'AI is analyzing your meal...'
                                  : _elapsedSeconds < 12
                                  ? 'Looking up nutrition details...'
                                  : 'Still working — big plates take a moment...',
                              style: context.text.caption.copyWith(
                                color: context.colors.textDark,
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
                style: context.text.body.copyWith(
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
            ],
          ],

          if (_analysisComplete) ...[
            const SizedBox(height: 16),
            if (_confidence != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _confidence == 'low'
                            ? context.colors.red.withValues(alpha: 0.1)
                            : _confidence == 'medium'
                            ? context.colors.orange.withValues(alpha: 0.1)
                            : context.colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _confidence == 'low'
                                  ? context.colors.red
                                  : _confidence == 'medium'
                                  ? context.colors.orange
                                  : context.colors.green,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${_confidence![0].toUpperCase()}${_confidence!.substring(1)} confidence',
                            style: context.text.micro.copyWith(
                              color: _confidence == 'low'
                                  ? context.colors.red
                                  : _confidence == 'medium'
                                  ? context.colors.orange
                                  : context.colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final item = _items[index];
                final isResolved = item.resolved;
                final scale = _itemScales[index] ?? 1.0;

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
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: isResolved
                          ? Colors.transparent
                          : context.colors.orange.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: isResolved
                          ? null
                          : Border.all(
                              color: context.colors.orange.withValues(
                                alpha: 0.4,
                              ),
                              width: 1,
                              style: BorderStyle
                                  .solid, // Should ideally be dashed, but sticking to standard border
                            ),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        children: [
                          if (isResolved) ...[
                            Container(
                              width: 4,
                              margin: const EdgeInsets.only(right: 12),
                              decoration: BoxDecoration(
                                color: _getDominantMacroColor(item, context),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name ?? 'Unknown',
                                  style: context.text.bodyStrong.copyWith(
                                    color: isResolved
                                        ? context.colors.textDark
                                        : context.colors.orange,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (isResolved) ...[
                                  Text(
                                    '${item.portion} • ${item.computedNutrition?.kcal.round() ?? 0} kcal',
                                    style: context.text.caption.copyWith(
                                      color: context.colors.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      _buildMacroPill(
                                        context,
                                        'Protein',
                                        '${item.computedNutrition?.proteinG.toStringAsFixed(1) ?? '0'}g',
                                        const Color(0xFFE8A163),
                                      ),
                                      _buildMacroPill(
                                        context,
                                        'Carbs',
                                        '${item.computedNutrition?.carbsG.toStringAsFixed(1) ?? '0'}g',
                                        const Color(0xFF8FB896),
                                      ),
                                      _buildMacroPill(
                                        context,
                                        'Fat',
                                        '${item.computedNutrition?.fatG.toStringAsFixed(1) ?? '0'}g',
                                        const Color(0xFFE58B88),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _buildPortionChip(
                                        context,
                                        index,
                                        0.5,
                                        '½',
                                        scale,
                                      ),
                                      const SizedBox(width: 6),
                                      _buildPortionChip(
                                        context,
                                        index,
                                        1.0,
                                        '1×',
                                        scale,
                                      ),
                                      const SizedBox(width: 6),
                                      _buildPortionChip(
                                        context,
                                        index,
                                        1.5,
                                        '1½',
                                        scale,
                                      ),
                                    ],
                                  ),
                                ] else ...[
                                  Text(
                                    'Couldn\'t estimate — tap edit to fix',
                                    style: context.text.caption.copyWith(
                                      color: context.colors.textMedium,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.edit_rounded,
                              size: 20,
                              color: isResolved
                                  ? context.colors.textMedium
                                  : context.colors.orange,
                            ),
                            onPressed: () => _editItem(index),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (!_describeMode && _selectedImages.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImages.first,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _unresolvedCount > 0
                          ? context.colors.orange.withValues(alpha: 0.1)
                          : context.colors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'TOTAL',
                              style: context.text.micro.copyWith(
                                color: _unresolvedCount > 0
                                    ? context.colors.orange
                                    : context.colors.primary,
                              ),
                            ),
                            if (_unresolvedCount > 0) ...[
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: context.colors.orange,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '+$_unresolvedCount to review',
                                  style: context.text.micro.copyWith(
                                    color: context.colors.onPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$_totalCalories kcal',
                          style: context.text.cardTitle.copyWith(
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
                  icon: const Icon(Icons.add_rounded),
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
        style: context.text.micro.copyWith(color: color),
      ),
    );
  }

  Widget _buildPortionChip(
    BuildContext context,
    int itemIndex,
    double scaleValue,
    String label,
    double currentScale,
  ) {
    final isSelected = currentScale == scaleValue;
    return GestureDetector(
      onTap: () => _setPortionScale(itemIndex, scaleValue),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? context.colors.primary.withValues(alpha: 0.15)
              : context.colors.inputFill,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected
                ? context.colors.primary.withValues(alpha: 0.5)
                : context.colors.border.withValues(alpha: 0.5),
          ),
        ),
        child: Text(
          label,
          style: context.text.micro.copyWith(
            color: isSelected
                ? context.colors.primary
                : context.colors.textMedium,
          ),
        ),
      ),
    );
  }

  Color _getDominantMacroColor(MealItemLog item, BuildContext context) {
    final pCal = (item.computedNutrition?.proteinG ?? 0) * 4;
    final cCal = (item.computedNutrition?.carbsG ?? 0) * 4;
    final fCal = (item.computedNutrition?.fatG ?? 0) * 9;

    if (pCal >= cCal && pCal >= fCal) return context.colors.green;
    if (cCal >= pCal && cCal >= fCal) return context.colors.orange;
    return context.colors.primary;
  }
}

class _MyFoodsScroller extends StatefulWidget {
  final Function(UserFoodLog) onFoodTap;

  const _MyFoodsScroller({required this.onFoodTap});

  @override
  State<_MyFoodsScroller> createState() => _MyFoodsScrollerState();
}

class _MyFoodsScrollerState extends State<_MyFoodsScroller> {
  List<UserFoodLog> _myFoods = [];
  StreamSubscription<void>? _subscription;

  @override
  void initState() {
    super.initState();
    _loadMyFoods();
    _setupSubscription();
  }

  void _setupSubscription() {
    final isar = Isar.instanceNames.isNotEmpty
        ? Isar.getInstance(Isar.instanceNames.first)
        : null;
    if (isar != null) {
      _subscription = isar.userFoodLogs.watchLazy().listen((_) {
        _loadMyFoods();
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _loadMyFoods() async {
    final isar = Isar.instanceNames.isNotEmpty
        ? Isar.getInstance(Isar.instanceNames.first)
        : null;
    if (isar == null) return;

    // Sort by most recently added/edited for "Recent" effect
    final foods = await isar.userFoodLogs
        .where()
        .sortByAddedAtDesc()
        .limit(10)
        .findAll();
    if (mounted) {
      setState(() {
        _myFoods = foods;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_myFoods.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _myFoods.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final food = _myFoods[index];
              return GestureDetector(
                onTap: () {
                  Haptics.tap();
                  widget.onFoodTap(food);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: context.colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 14,
                          color: context.colors.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          food.originalName,
                          style: context.text.caption.copyWith(
                            color: context.colors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
