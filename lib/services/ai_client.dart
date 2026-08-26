import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:googleai_dart/googleai_dart.dart';
import 'package:firebase_ai/firebase_ai.dart' as vertex;
import 'package:crypto/crypto.dart';
import 'ai_cache.dart';
import 'dart:async';
import 'image_preprocessor.dart';

class AiException implements Exception {
  final String message;
  AiException(this.message);
  @override
  String toString() => message;
}

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
    'gemini-2.0-flash',
    'gemini-1.5-flash',
    'gemini-1.5-pro',
  ];

  GoogleAIClient? _cachedClient;
  String? _cachedApiKey;

  AiClient({this.cache});

  void dispose() {
    _cachedClient?.close();
    _cachedClient = null;
    _cachedApiKey = null;
  }

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
      throw AiException('Our AI is taking a quick breather to handle traffic. Please try again in a few minutes.');
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
          
          if (errorString.contains('API_KEY_INVALID') || errorString.contains('API key not valid') || errorString.contains('disabled') || errorString.contains('has not been used in project')) {
            throw AiException('Your API Key is invalid or not authorized. Please check your AI Settings.');
          } else if (errorString.contains('403') || errorString.contains('forbidden') || errorString.contains('404') || errorString.contains('not found')) {
            lastError = 'Model $modelName unavailable (403/404). Trying next...';
            break; // Break retries, try next model
          } else if (errorString.contains('SocketException') || errorString.contains('Failed host lookup')) {
            throw AiException('You seem to be offline. Please check your internet connection.');
          }
          
          if (errorString.contains('429') || errorString.contains('quota')) {
            if (attempt < maxRetries) {
              final delaySeconds = 1 << attempt; // 1s, 2s
              debugPrint('Rate limited. Waiting ${delaySeconds}s before retry...');
              await Future.delayed(Duration(seconds: delaySeconds));
              continue; // Retry
            } else {
              _circuitBreaker.recordFailure();
              throw AiException('We\'re experiencing heavy traffic. Please try again in a moment.');
            }
          } else if (errorString.contains('TimeoutException') || errorString.contains('Timeout')) {
            if (attempt < maxRetries) {
              continue; // Retry
            } else {
              lastError = 'Connection timed out';
              break;
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
    throw AiException('Failed to generate response. Please try again later.');
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

      final response = await model.generateContent(contents).timeout(const Duration(seconds: 20));
      return response.text;
    } else {
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('API Key is required if not using Firebase.');
      }
      
      if (_cachedApiKey != apiKey || _cachedClient == null) {
        _cachedClient?.close();
        _cachedClient = GoogleAIClient(
          config: GoogleAIConfig.googleAI(
            authProvider: ApiKeyProvider(apiKey),
          ),
        );
        _cachedApiKey = apiKey;
      }

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

      final response = await _cachedClient!.models.generateContent(
        model: modelName,
        request: request,
      ).timeout(const Duration(seconds: 20));
      return response.text;
    }
  }

  Stream<String> generateTextStream({
    required String prompt,
    required String systemInstruction,
    required bool useFirebase,
    String? apiKey,
  }) async* {
    if (_circuitBreaker.isOpen) {
      throw AiException('Our AI is taking a quick breather to handle traffic. Please try again in a few minutes.');
    }

    String lastError = '';

    for (final modelName in modelsToTry) {
      try {
        debugPrint('AiClient: Trying Gemini stream model: $modelName (Firebase: $useFirebase)...');
        final stream = _callModelStream(
          modelName: modelName,
          prompt: prompt,
          systemInstruction: systemInstruction,
          useFirebase: useFirebase,
          apiKey: apiKey,
        );
        
        await for (final chunk in stream) {
           if (chunk != null && chunk.isNotEmpty) {
               yield chunk;
           }
        }
        _circuitBreaker.recordSuccess();
        return; // Success, exit the loop
      } catch (e) {
        debugPrint('AiClient: Stream failed with $modelName: $e');
        final errorString = e.toString();
        
        if (errorString.contains('API_KEY_INVALID') || errorString.contains('API key not valid')) {
          throw AiException('Your API Key is invalid or not authorized. Please check your AI Settings.');
        } else if (errorString.contains('403') || errorString.contains('404')) {
          lastError = 'Model $modelName unavailable (403/404)';
          continue; // Try next model
        } else if (errorString.contains('SocketException')) {
          throw AiException('You seem to be offline. Please check your internet connection.');
        } else if (errorString.contains('429') || errorString.contains('quota')) {
          _circuitBreaker.recordFailure();
          throw AiException('We\'re experiencing heavy traffic. Please try again in a moment.');
        }
        
        lastError = errorString;
        continue;
      }
    }

    _circuitBreaker.recordFailure();
    throw AiException('Failed to generate response. Please try again later.');
  }

  Stream<String?> _callModelStream({
    required String modelName,
    required String prompt,
    required String systemInstruction,
    required bool useFirebase,
    String? apiKey,
  }) {
    if (useFirebase) {
      final model = vertex.FirebaseAI.vertexAI().generativeModel(
        model: modelName,
        systemInstruction: vertex.Content.system(systemInstruction),
        generationConfig: vertex.GenerationConfig(
          temperature: 0.1,
          responseMimeType: 'text/plain',
        ),
      );

      return model.generateContentStream([vertex.Content.text(prompt)])
          .map((res) => res.text)
          .timeout(const Duration(seconds: 20));
    } else {
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('API Key is required if not using Firebase.');
      }
      
      if (_cachedApiKey != apiKey || _cachedClient == null) {
        _cachedClient?.close();
        _cachedClient = GoogleAIClient(
          config: GoogleAIConfig.googleAI(
            authProvider: ApiKeyProvider(apiKey),
          ),
        );
        _cachedApiKey = apiKey;
      }

      final request = GenerateContentRequest(
        systemInstruction: Content.text(systemInstruction),
        generationConfig: const GenerationConfig(
          temperature: 0.1,
          responseMimeType: 'text/plain',
        ),
        contents: [Content.text(prompt)],
      );

      return _cachedClient!.models.generateContentStream(
        model: modelName,
        request: request,
      ).map((res) => res.text).timeout(const Duration(seconds: 20));
    }
  }

  Map<String, dynamic> _parseJson(String text) {
    try {
      final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      throw AiException('Something went wrong parsing the response. Please try again.');
    }
  }
}
