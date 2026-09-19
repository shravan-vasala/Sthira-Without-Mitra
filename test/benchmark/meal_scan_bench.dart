import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trufit_bodamma/services/ai_client.dart';
import 'package:trufit_bodamma/services/ai_profiler.dart';
import 'package:trufit_bodamma/services/gemini_food_service.dart';
import 'package:trufit_bodamma/services/nutrition_lookup_service.dart';
import 'package:googleai_dart/googleai_dart.dart';

// Helper for F1 Score with 1-to-1 matching
double calculateF1(List<String> trueNames, List<String> predNames) {
  if (trueNames.isEmpty && predNames.isEmpty) return 1.0;
  if (trueNames.isEmpty || predNames.isEmpty) return 0.0;

  int truePositives = 0;
  final Set<int> matchedTrueIdx = {};

  for (var pred in predNames) {
    for (int i = 0; i < trueNames.length; i++) {
      if (!matchedTrueIdx.contains(i)) {
        final t = trueNames[i];
        if (t.toLowerCase().contains(pred.toLowerCase()) || pred.toLowerCase().contains(t.toLowerCase())) {
          truePositives++;
          matchedTrueIdx.add(i);
          break; // move to next pred once matched
        }
      }
    }
  }

  double precision = truePositives / predNames.length;
  double recall = truePositives / trueNames.length;
  
  if (precision + recall == 0) return 0.0;
  return 2 * (precision * recall) / (precision + recall);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Meal Scan AI-01 Benchmark', () async {
    const runBench = bool.fromEnvironment('RUN_BENCH', defaultValue: false);
    if (!runBench) {
      print('Skipping benchmark. Run with --dart-define=RUN_BENCH=true --dart-define=AI_PROFILE=true');
      return;
    }

    // Replace with your real Gemini API key
    const apiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
    if (apiKey.isEmpty) {
      print('Please provide --dart-define=GEMINI_API_KEY=your_key');
      return;
    }

    final modelOverride = const String.fromEnvironment('MODEL', defaultValue: 'gemini-3.8-flash');
    // Note: To truly test 'thinking=low', we need to pass a generation_config containing thinking_level. 
    // In this harness, we only observe baseline. Later prompts will add thinking_level param.
    
    // Load Fixtures
    final fixturesDir = Directory('test/fixtures/meal_scan');
    if (!fixturesDir.existsSync()) {
      print('Fixtures directory not found at ${fixturesDir.path}');
      return;
    }

    final gtFile = File('${fixturesDir.path}/ground_truth.json');
    if (!gtFile.existsSync()) {
      print('ground_truth.json not found!');
      return;
    }

    final gtData = jsonDecode(gtFile.readAsStringSync()) as List<dynamic>;
    
    final aiClient = AiClient();
    final nutritionLookup = NutritionLookupService();
    final service = GeminiFoodService(
      apiKey: apiKey,
      aiClient: aiClient,
      nutritionLookup: nutritionLookup,
    );
    
    await nutritionLookup.load();

    final resultsCsv = File('test/benchmark/baseline_results.csv');
    if (!resultsCsv.existsSync()) resultsCsv.createSync(recursive: true);
    
    final sink = resultsCsv.openWrite(mode: FileMode.writeOnly);
    sink.writeln('id,iteration,totalMs,preprocessMs,networkMs,totalKcalMape,itemF1,schemaFailed,hallucinations,thoughtsTokens');

    final iterations = const int.fromEnvironment('ITERATIONS', defaultValue: 3);

    final List<int> allTotalMs = [];
    final List<int> allNetworkMs = [];
    
    int totalItemsTested = 0;
    double sumKcalMape = 0;
    double sumItemF1 = 0;
    int hallucinations = 0;
    int schemaFailures = 0;

    print('Starting benchmark across ${gtData.length} images for $iterations iterations...');

    for (var gt in gtData) {
      final id = gt['id'];
      final images = List<String>.from(gt['images'] ?? []);
      final gtItems = List<dynamic>.from(gt['items'] ?? []);
      final gtTotalKcal = (gt['total_kcal'] as num).toDouble();
      
      final imageBytesList = <Uint8List>[];
      for (var imgName in images) {
        final f = File('${fixturesDir.path}/images/$imgName');
        if (f.existsSync()) {
          imageBytesList.add(f.readAsBytesSync());
        }
      }

      if (imageBytesList.isEmpty) {
        print('Warning: No images found for $id');
        continue;
      }

      for (int i = 0; i < iterations; i++) {
        final profiler = AiProfileSession();
        profiler.startPhase('totalMs');
        profiler.startPhase('fileReadMs'); // Fake fileReadMs to keep profile complete
        await Future.delayed(const Duration(milliseconds: 10)); // simulated read
        profiler.endPhase('fileReadMs');
        
        Map<String, dynamic>? result;
        try {
          result = await service.analyzeFoodImage(
            imageBytesList,
            'image/jpeg',
            '',
            true, // skip cache
            false,
            null,
            profiler,
          );
          profiler.recordMetadata(terminalOutcome: TerminalOutcome.success);
        } catch (e) {
          print('Schema/API failure on $id iter $i: $e');
          profiler.recordMetadata(terminalOutcome: TerminalOutcome.error, failureReason: e.toString());
          schemaFailures++;
        }
        
        profiler.endPhase('totalMs');
        final session = profiler.toMap();
        
        allTotalMs.add(session['totalMs'] ?? 0);
        allNetworkMs.add(session['networkMs'] ?? 0);

        double kcalMape = 0;
        double itemF1 = 0;
        int iterHallucinations = 0;

        if (result != null) {
          final resItems = List<dynamic>.from(result['items'] ?? []);
          final resTotalKcal = (result['total']?['calories'] as num?)?.toDouble() ?? 0;
          
          if (gtTotalKcal > 0) {
            kcalMape = ((resTotalKcal - gtTotalKcal).abs() / gtTotalKcal) * 100.0;
          }

          final gtNames = gtItems.map((e) => e['name'].toString()).toList();
          final resNames = resItems.map((e) => e['name'].toString()).toList();
          itemF1 = calculateF1(gtNames, resNames);

          for (var rName in resNames) {
            bool found = gtNames.any((g) => g.toLowerCase().contains(rName.toLowerCase()) || rName.toLowerCase().contains(g.toLowerCase()));
            if (!found) iterHallucinations++;
          }
          
          sumKcalMape += kcalMape;
          sumItemF1 += itemF1;
          hallucinations += iterHallucinations;
          totalItemsTested++;
        }

        sink.writeln('$id,$i,${session['totalMs']},${session['preprocessMs']},${session['networkMs']},${kcalMape.toStringAsFixed(2)},${itemF1.toStringAsFixed(2)},${result == null ? 1 : 0},$iterHallucinations,${session['thoughtsTokenCount'] ?? ''}');
      }
    }
    
    await sink.flush();
    await sink.close();

    allTotalMs.sort();
    allNetworkMs.sort();

    int p50(List<int> l) => l.isEmpty ? 0 : l[(l.length * 0.50).floor()];
    int p90(List<int> l) => l.isEmpty ? 0 : l[(l.length * 0.90).floor()];
    int p99(List<int> l) => l.isEmpty ? 0 : l[(l.length * 0.99).floor()];

    print('\\n--- Benchmark Results ---');
    print('Total Latency: p50: ${p50(allTotalMs)}ms, p90: ${p90(allTotalMs)}ms, p99: ${p99(allTotalMs)}ms');
    print('Network Latency: p50: ${p50(allNetworkMs)}ms, p90: ${p90(allNetworkMs)}ms, p99: ${p99(allNetworkMs)}ms');
    
    if (totalItemsTested > 0) {
      print('Mean Kcal Error: ${(sumKcalMape / totalItemsTested).toStringAsFixed(2)}%');
      print('Mean Item F1: ${(sumItemF1 / totalItemsTested).toStringAsFixed(2)}');
      print('Total Hallucinated Items: $hallucinations');
      print('Schema Failures: $schemaFailures');
    }
  });
}
