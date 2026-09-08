import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'ai_logger.dart';
import 'package:googleai_dart/googleai_dart.dart';
import 'package:crypto/crypto.dart';
import 'ai_cache.dart';
import 'dart:async';
import 'dart:io';
import 'image_preprocessor.dart';

enum AiErrorCause { invalidKey, offline, notFound, rateLimited, overloaded, parse, timeout, unknown }

class AiException implements Exception {
  final String message;
  final AiErrorCause? cause;
  AiException(this.message, {this.cause});
  @override
  String toString() => message;
}

AiErrorCause _classifyError(String errorString) {
  if (errorString.contains('API_KEY_INVALID') || errorString.contains('API key not valid') || errorString.contains('disabled') || errorString.contains('has not been used in project') || errorString.contains('deactivated') || errorString.contains('SERVICE_DISABLED') || errorString.contains('PERMISSION_DENIED')) {
    return AiErrorCause.invalidKey;
  } else if (errorString.contains('SocketException') || errorString.contains('Failed host lookup')) {
    return AiErrorCause.offline;
  } else if (errorString.contains('403') || errorString.contains('forbidden') || errorString.contains('404') || errorString.contains('not found')) {
    return AiErrorCause.notFound;
  } else if (errorString.contains('429') || errorString.contains('quota') || errorString.contains('RESOURCE_EXHAUSTED')) {
    return AiErrorCause.rateLimited;
  } else if (errorString.contains('503') || errorString.contains('UNAVAILABLE') || errorString.contains('overloaded')) {
    return AiErrorCause.overloaded;
  } else if (errorString.contains('FormatException') || errorString.contains('json') || errorString.contains('parse')) {
    return AiErrorCause.parse;
  } else if (errorString.contains('TimeoutException') || errorString.contains('Timeout')) {
    return AiErrorCause.timeout;
  }
  return AiErrorCause.unknown;
}

class AiClientCircuitBreaker {
  int consecutiveFailures = 0;
  DateTime? lastFailureTime;
  static const int maxFailures = 3;
  static const Duration resetTimeout = Duration(seconds: 90);

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
  final AiClientCircuitBreaker _visionCircuitBreaker = AiClientCircuitBreaker();
  final AiClientCircuitBreaker _textCircuitBreaker = AiClientCircuitBreaker();
  
  static const visionModelsToTry = [
    'gemini-3.7-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
  ];

  static const textModelsToTry = [
    'gemini-3.7-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash-lite',
    'gemini-3.1-flash-lite',
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
    List<Uint8List>? imageBytesList,
    String? mimeType,
    required String apiKey,
    bool skipCache = false,
    Map<String, dynamic>? responseSchema,
  }) async {
    if (apiKey == null || apiKey.isEmpty) {
      throw AiException('API Key is required. Add it in Profile -> AI Settings.', cause: AiErrorCause.invalidKey);
    }

    final fullOpSw = Stopwatch()..start();
    int? preprocessMs;

    String? imageContext;
    final List<Uint8List> processedImages = [];
    String? actualMimeType = mimeType;
    if (imageBytesList != null && imageBytesList.isNotEmpty) {
      final prepSw = Stopwatch()..start();
      final b = BytesBuilder();
      for (var imageBytes in imageBytesList) {
        final processed = await ImagePreprocessor.processImage(imageBytes, mimeType ?? 'image/jpeg');
        processedImages.add(processed.$1);
        actualMimeType = processed.$2;
        b.add(processed.$1);
      }
      imageContext = sha256.convert(b.toBytes()).toString();
      prepSw.stop();
      preprocessMs = prepSw.elapsedMilliseconds;
    }

    if (cache != null && !skipCache) {
      final cachedResult = cache!.get(prompt, systemInstruction, imageContext);
      if (cachedResult != null) return cachedResult;
    }

    final isVision = imageBytesList != null && imageBytesList.isNotEmpty;
    final breaker = isVision ? _visionCircuitBreaker : _textCircuitBreaker;
    
    if (breaker.isOpen) {
      throw AiException('Our AI is taking a quick breather to handle traffic. Give it about a minute.', cause: AiErrorCause.rateLimited);
    }

    final modelsToUse = isVision ? visionModelsToTry : textModelsToTry;
    final overallDeadline = DateTime.now().add(Duration(seconds: isVision ? 75 : 40));
    final perAttemptTimeout = Duration(seconds: isVision ? 40 : 20);
    
    AiErrorCause? lastCause;
    String lastErrorMsg = '';

    for (int i = 0; i < modelsToUse.length; i++) {
        if (DateTime.now().isAfter(overallDeadline)) break;
      final modelName = modelsToUse[i];
      int maxRetries = 2; // only used for rateLimited
      int attempt = 0;
      
      while (attempt <= maxRetries) {
        if (DateTime.now().isAfter(overallDeadline)) break;
        final remaining = overallDeadline.difference(DateTime.now());
        final attemptTimeout = remaining < perAttemptTimeout ? remaining : perAttemptTimeout;

        final sw = Stopwatch()..start();
        try {
          debugPrint('AiClient: Trying model: $modelName (attempt ${attempt + 1})...');
          final response = await _callModel(
            modelName: modelName,
            prompt: prompt,
            systemInstruction: systemInstruction,
            apiKey: apiKey,
            imageBytesList: processedImages.isNotEmpty ? processedImages : null,
            mimeType: actualMimeType,
            timeout: attemptTimeout,
            responseSchema: responseSchema,
          );
          sw.stop();
          
          if (response == null || response.isEmpty) throw AiException("Empty response", cause: AiErrorCause.unknown);
          
          final json = _parseJson(response);
          if (i > 0) json['modelUsed'] = modelName;
          
          AiLogger.log(
            purpose: isVision ? 'scan plate (vision)' : 'scan description', 
            model: modelName, 
            durationMs: sw.elapsedMilliseconds, 
            preprocessMs: preprocessMs,
            outcome: 'success'
          );
          
          breaker.recordSuccess();
          if (cache != null) await cache!.set(prompt, systemInstruction, json, imageContext);
          return json;
          
        } catch (e) {
          sw.stop();
          final errStr = e.toString();
          final cause = (e is AiException && e.cause != null) ? e.cause! : _classifyError(errStr);
          lastCause = cause;
          lastErrorMsg = errStr;
          
          AiLogger.log(
            purpose: 'AI error fallback', 
            model: modelName, 
            durationMs: sw.elapsedMilliseconds, 
            preprocessMs: preprocessMs,
            outcome: cause.toString()
          );
          
          if (cause == AiErrorCause.invalidKey) {
            throw AiException('This API key\'s project has the Gemini API disabled — check Google AI Studio.', cause: cause);
          } else if (cause == AiErrorCause.offline) {
            throw AiException('You seem to be offline. Please check your internet connection.', cause: cause);
          } else if (cause == AiErrorCause.notFound) {
            break; // Next model
          } else if (cause == AiErrorCause.rateLimited) {
            if (attempt < maxRetries) {
              final delay = attempt == 0 ? 1 : 2;
              await Future.delayed(Duration(seconds: delay));
              attempt++;
              continue;
            } else {
              break; // Next model
            }
          } else if (cause == AiErrorCause.overloaded) {
            if (attempt == 0) {
              await Future.delayed(const Duration(seconds: 2));
              attempt++;
              continue;
            } else {
              break; // Next model
            }
          } else if (cause == AiErrorCause.parse) {
            break; // Next model
          } else if (cause == AiErrorCause.timeout) {
            break; // Next model immediately
          }
          break; // Unknown error -> next model
        }
      }
    }

    if (DateTime.now().isAfter(overallDeadline)) {
      throw AiException('The AI is taking too long right now. Please try again.', cause: AiErrorCause.timeout);
    }
    
    if (lastCause == AiErrorCause.rateLimited || lastCause == AiErrorCause.overloaded) {
      breaker.recordFailure();
    }
    
    String reason = 'unknown error';
    if (lastCause == AiErrorCause.rateLimited) reason = 'rate limited';
    if (lastCause == AiErrorCause.overloaded) reason = 'model overloaded';
    if (lastCause == AiErrorCause.timeout) reason = 'timed out';
    if (lastCause == AiErrorCause.parse) reason = 'parsing failed';
    
    throw AiException('Couldn\'t analyze right now ($reason). Try again in a minute.', cause: lastCause);
  }

  Future<String?> _callModel({
    required String modelName,
    required String prompt,
    String? systemInstruction,
    String? apiKey,
    List<Uint8List>? imageBytesList,
    String? mimeType,
    Duration timeout = const Duration(seconds: 30),
    Map<String, dynamic>? responseSchema,
  }) async {
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('API Key is required.');
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
        systemInstruction: systemInstruction != null ? Content.text(systemInstruction) : null,
        generationConfig: GenerationConfig(
          responseMimeType: 'application/json',
          responseSchema: responseSchema,
          temperature: 0.1,
        ),
        contents: [
          if (imageBytesList != null && imageBytesList.isNotEmpty)
            Content.user([
              TextPart(prompt),
              for (var imageBytes in imageBytesList)
                Part.bytes(imageBytes, mimeType ?? 'image/jpeg'),
            ])
          else
            Content.text(prompt)
        ],
      );

      final response = await _cachedClient!.models.generateContent(
        model: modelName,
        request: request,
      ).timeout(timeout);
      return response.text;
  }

    Stream<String> generateTextStream({
    required String prompt,
    required String systemInstruction,
    String? apiKey,
    Duration overallTimeout = const Duration(seconds: 40),
  }) async* {
    if (_textCircuitBreaker.isOpen) {
      throw AiException('Our AI is taking a quick breather to handle traffic. Give it about a minute.', cause: AiErrorCause.rateLimited);
    }

    AiErrorCause? lastCause;
    final overallDeadline = DateTime.now().add(overallTimeout);

    for (final modelName in textModelsToTry) {
      if (DateTime.now().isAfter(overallDeadline)) break;
      final sw = Stopwatch()..start();
      int? firstTokenMs;
      bool yieldedAny = false;

      try {
        final stream = _callModelStream(
          modelName: modelName,
          prompt: prompt,
          systemInstruction: systemInstruction,
          apiKey: apiKey,
        );
        
        await for (final chunk in stream) {
           if (chunk != null && chunk.isNotEmpty) {
             if (firstTokenMs == null) {
               firstTokenMs = sw.elapsedMilliseconds;
             }
             yieldedAny = true;
             yield chunk;
           }
         }
         
         if (!yieldedAny) {
           throw AiException("Empty response from stream", cause: AiErrorCause.unknown);
         }

         sw.stop();
         AiLogger.log(
           purpose: 'text stream',
           model: modelName,
           durationMs: sw.elapsedMilliseconds,
           firstTokenMs: firstTokenMs,
           outcome: 'success'
         );
         _textCircuitBreaker.recordSuccess();
         return;
       } catch (e) {
        sw.stop();
        final errStr = e.toString();
        final cause = (e is AiException && e.cause != null) ? e.cause! : _classifyError(errStr);
        lastCause = cause;

        AiLogger.log(
          purpose: 'text stream fallback',
          model: modelName,
          durationMs: sw.elapsedMilliseconds,
          firstTokenMs: firstTokenMs,
          outcome: cause.toString()
        );

        if (yieldedAny) {
          // If we already started streaming text to the user, we cannot seamlessly fallback
          // to another model because it will just append the new start to the old partial text.
          // We must throw here.
          throw AiException('Stream failed midway. Please try again.', cause: cause);
        }
        
        if (cause == AiErrorCause.invalidKey) {
          throw AiException('This API key\'s project has the Gemini API disabled — check Google AI Studio.', cause: cause);
        } else if (cause == AiErrorCause.offline) {
          throw AiException('You seem to be offline. Please check your internet connection.', cause: cause);
        } else if (cause == AiErrorCause.notFound) {
          continue;
        } else if (cause == AiErrorCause.rateLimited) {
          continue;
        } else if (cause == AiErrorCause.overloaded || cause == AiErrorCause.timeout) {
          continue;
        }
        continue;
      }
    }
    
    if (DateTime.now().isAfter(overallDeadline)) {
      lastCause = AiErrorCause.timeout;
    }

    if (lastCause == AiErrorCause.rateLimited || lastCause == AiErrorCause.overloaded) {
      _textCircuitBreaker.recordFailure();
    }
    
    String reason = 'unknown error';
    if (lastCause == AiErrorCause.rateLimited) reason = 'rate limited';
    if (lastCause == AiErrorCause.overloaded) reason = 'model overloaded';
    if (lastCause == AiErrorCause.timeout) reason = 'timed out';
    
    throw AiException('Failed to generate response ($reason). Please try again later.', cause: lastCause);
  }

  Stream<String?> _callModelStream({
    required String modelName,
    required String prompt,
    required String systemInstruction,
    String? apiKey,
  }) async* {
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('API Key is required.');
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
          responseMimeType: 'text/plain',
        ),
        contents: [Content.text(prompt)],
      );

      final responseStream = _cachedClient!.models.streamGenerateContent(
        model: modelName,
        request: request,
      );
      
      await for (final response in responseStream) {
        if (response.text != null && response.text!.isNotEmpty) {
          yield response.text;
        }
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
