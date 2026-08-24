import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleai_dart/googleai_dart.dart';
import 'package:firebase_ai/firebase_ai.dart' as vertex;
import 'package:crypto/crypto.dart';
import 'ai_cache.dart';
import 'image_preprocessor.dart';

class AiClientCircuitBreaker {
  int consecutiveFailures = 0;
  DateTime? lastFailureTime;
  static const int maxFailures = 3;
  static const Duration resetTimeout = Duration(minutes: 5);

  bool get isOpen {
    if (consecutiveFailures >= maxFailures) {
      if (lastFailureTime != null && DateTime.now().difference(lastFailureTime!) > resetTimeout) {
        // Half-open state
        consecutiveFailures = 0;
        return false;
      }
      return true;
    }
    return false;
  }

  void recordFailure() {
    consecutiveFailures++;
    lastFailureTime = DateTime.now();
  }

  void recordSuccess() {
    consecutiveFailures = 0;
    lastFailureTime = null;
  }
}

class AiClient {
  final AiCache? cache;
  final AiClientCircuitBreaker _circuitBreaker = AiClientCircuitBreaker();
  
  static const modelsToTry = [
    'gemini-1.5-pro',
    'gemini-1.5-flash',
    'gemini-1.5-flash-8b',
  ];

  AiClient({this.cache});

  Future<Map<String, dynamic>?> generateJson({
    required String prompt,
    required String systemInstruction,
    Uint8List? imageBytes,
    String? mimeType,
    required bool useFirebase,
    String? apiKey,
    bool skipCache = false,
  }) async {
    if (_circuitBreaker.isOpen) {
      throw Exception('Service temporarily unavailable due to repeated failures. Please try again later.');
    }

    String? imageContext;
    Uint8List? processedImage;
    if (imageBytes != null) {
      processedImage = await ImagePreprocessor.downscale(imageBytes);
      imageContext = sha256.convert(processedImage).toString();
    }

    if (cache != null && !skipCache) {
      final cachedResult = cache!.get(prompt, imageContext);
      if (cachedResult != null) return cachedResult;
    }

    String lastError = '';

    for (final modelName in modelsToTry) {
      int maxRetries = 2;
      bool skipStrategy = false;
      
      for (int attempt = 0; attempt <= maxRetries; attempt++) {
        try {
          debugPrint('AiClient: Trying Gemini model: $modelName (Firebase: $useFirebase, attempt \${attempt + 1})...');
          final response = await _callModel(
            modelName: modelName,
            prompt: prompt,
            systemInstruction: systemInstruction,
            useFirebase: useFirebase,
            apiKey: apiKey,
            imageBytes: processedImage,
            mimeType: mimeType,
          );
          
          if (response == null || response.isEmpty) throw Exception("Empty response");
          
          final json = _parseJson(response);
          _circuitBreaker.recordSuccess();

          if (cache != null && !skipCache) {
            await cache!.set(prompt, json, imageContext);
          }

          return json;
        } catch (e) {
          debugPrint('AiClient: Failed with $modelName: $e');
          final errorString = e.toString();
          
          if (errorString.contains('403') || errorString.contains('API_KEY_INVALID') || errorString.contains('forbidden') || errorString.contains('API key not valid') || errorString.contains('disabled') || errorString.contains('has not been used in project')) {
            if (useFirebase) {
              lastError = 'Firebase API disabled or forbidden: $e';
            } else {
              lastError = 'Your API Key is invalid or expired.';
            }
            skipStrategy = true;
            break; // Break retries
          } 
          
          if (errorString.contains('429') || errorString.contains('quota')) {
            if (attempt < maxRetries) {
              final delaySeconds = 1 << attempt; // 1s, 2s
              debugPrint('Rate limited. Waiting \${delaySeconds}s before retry...');
              await Future.delayed(Duration(seconds: delaySeconds));
              continue; // Retry
            } else {
              lastError = 'Rate limited: $e';
              break; // Break retries
            }
          }
          
          lastError = e.toString();
          break; // For other errors, break retries, try next model immediately
        }
      }
      
      if (skipStrategy) {
        break; // Break models loop
      }
    }

    _circuitBreaker.recordFailure();
    throw Exception('Failed to generate response. Last error: $lastError');
  }

  Future<String?> _callModel({
    required String modelName,
    required String prompt,
    required String systemInstruction,
    required bool useFirebase,
    String? apiKey,
    Uint8List? imageBytes,
    String? mimeType,
  }) async {
    if (useFirebase) {
      final model = vertex.FirebaseAI.vertexAI().generativeModel(
        model: modelName,
        systemInstruction: vertex.Content.system(systemInstruction),
        generationConfig: vertex.GenerationConfig(
          temperature: 0.1,
          responseMimeType: 'application/json',
        ),
      );

      final contents = [
        if (imageBytes != null)
          vertex.Content.multi([
            vertex.TextPart(prompt),
            vertex.InlineDataPart(mimeType ?? 'image/jpeg', imageBytes)
          ])
        else
          vertex.Content.text(prompt)
      ];

      final response = await model.generateContent(contents);
      return response.text;
    } else {
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('API Key is required if not using Firebase.');
      }
      
      final client = GoogleAIClient(
        config: GoogleAIConfig.googleAI(
          authProvider: ApiKeyProvider(apiKey),
        ),
      );

      try {
        final request = GenerateContentRequest(
          systemInstruction: Content.text(systemInstruction),
          generationConfig: const GenerationConfig(
            temperature: 0.1,
            responseMimeType: 'application/json',
          ),
          contents: [
            if (imageBytes != null)
              Content.user([
                TextPart(prompt),
                Part.bytes(imageBytes, mimeType ?? 'image/jpeg'),
              ])
            else
              Content.text(prompt)
          ],
        );

        final response = await client.models.generateContent(
          model: modelName,
          request: request,
        );
        return response.text;
      } finally {
        client.close();
      }
    }
  }

  Map<String, dynamic> _parseJson(String text) {
    try {
      final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Failed to parse AI response as JSON: $e');
    }
  }
}
