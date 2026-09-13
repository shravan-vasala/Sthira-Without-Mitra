import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'ai_logger.dart';
import 'package:googleai_dart/googleai_dart.dart';
import 'package:crypto/crypto.dart';
import 'ai_cache.dart';
import 'dart:async';
import 'dart:io';
import 'image_preprocessor.dart';

class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

enum AiErrorCause { invalidKey, offline, notFound, rateLimited, overloaded, parse, timeout, cancelled, unknown }

class AiException implements Exception {
  final String message;
  final AiErrorCause? cause;
  AiException(this.message, {this.cause});
  @override
  String toString() => message;
}

AiErrorCause _classifyError(String errorString) {
  if (errorString.contains('API_KEY_INVALID') || errorString.contains('API key not valid') || errorString.contains('disabled') || errorString.contains('has not been used in project') || errorString.contains('deactivated') || errorString.contains('SERVICE_DISABLED') || errorString.contains('PERMISSION_DENIED') || errorString.contains('403') || errorString.contains('forbidden')) {
    return AiErrorCause.invalidKey;
  } else if (errorString.contains('SocketException') || errorString.contains('Failed host lookup')) {
    return AiErrorCause.offline;
  } else if (errorString.contains('404') || errorString.contains('not found')) {
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

  @visibleForTesting
  Future<String?> Function({
    required String modelName,
    required String prompt,
    String? systemInstruction,
    String? apiKey,
    List<Uint8List>? imageBytesList,
    String? mimeType,
    Duration timeout,
    Map<String, dynamic>? responseSchema,
  })? mockCallModel;

  @visibleForTesting
  Stream<String?> Function({
    required String modelName,
    required String prompt,
    required String systemInstruction,
    String? apiKey,
  })? mockCallModelStream;

  AiClient({this.cache, this.mockCallModel, this.mockCallModelStream});

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
    CancellationToken? cancellationToken,
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
      final cachedResult = cache!.get(prompt, systemInstruction, imageContext, responseSchema?.toString());
      if (cachedResult != null) return cachedResult;
    }

    final isVision = imageBytesList != null && imageBytesList.isNotEmpty;
    final breaker = isVision ? _visionCircuitBreaker : _textCircuitBreaker;
    
    if (breaker.isOpen) {
      throw AiException('Our AI is taking a quick breather to handle traffic. Give it about a minute.', cause: AiErrorCause.rateLimited);
    }
    
    if (cancellationToken?.isCancelled ?? false) {
      throw AiException('Operation was cancelled.', cause: AiErrorCause.cancelled);
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
        if (cancellationToken?.isCancelled ?? false) {
          throw AiException('Operation was cancelled.', cause: AiErrorCause.cancelled);
        }
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
          if (cache != null) await cache!.set(prompt, systemInstruction, json, imageContext, responseSchema?.toString());
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
            throw AiException('This API key is invalid, disabled, or restricted. Please check Google AI Studio and ensure no IP or app restrictions are applied.', cause: cause);
          } else if (cause == AiErrorCause.offline) {
            throw AiException('You seem to be offline. Please check your internet connection.', cause: cause);
          } else if (cause == AiErrorCause.parse) {
            throw AiException('AI returned an invalid format. Please try again.\nDetails: $errStr', cause: cause);
          } else if (cause == AiErrorCause.notFound) {
            break; // Next model
          } else if (cause == AiErrorCause.rateLimited) {
            if (attempt < maxRetries) {
              final delay = attempt == 0 ? 1 : 2;
              if (DateTime.now().add(Duration(seconds: delay)).isAfter(overallDeadline)) break;
              if (cancellationToken?.isCancelled ?? false) break;
              await Future.delayed(Duration(seconds: delay));
              if (cancellationToken?.isCancelled ?? false) break;
              attempt++;
              continue;
            } else {
              break; // Next model
            }
          } else if (cause == AiErrorCause.overloaded) {
            if (attempt == 0) {
              if (DateTime.now().add(const Duration(seconds: 2)).isAfter(overallDeadline)) break;
              if (cancellationToken?.isCancelled ?? false) break;
              await Future.delayed(const Duration(seconds: 2));
              if (cancellationToken?.isCancelled ?? false) break;
              attempt++;
              continue;
            } else {
              break; // Next model
            }
          } else if (cause == AiErrorCause.timeout) {
            break; // Next model immediately
          }
          break; // Unknown error -> next model
        }
      }
    }

    if (cancellationToken?.isCancelled ?? false) {
      throw AiException('Operation was cancelled.', cause: AiErrorCause.cancelled);
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
    
    throw AiException('Couldn\'t analyze right now. Try again in a minute.', cause: lastCause);
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
      if (mockCallModel != null) {
        return mockCallModel!(
          modelName: modelName,
          prompt: prompt,
          systemInstruction: systemInstruction,
          apiKey: apiKey,
          imageBytesList: imageBytesList,
          mimeType: mimeType,
          timeout: timeout,
          responseSchema: responseSchema,
        );
      }
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
    Duration inactivityTimeout = const Duration(seconds: 15),
    CancellationToken? cancellationToken,
  }) {
    if (_textCircuitBreaker.isOpen) {
      throw AiException('Our AI is taking a quick breather to handle traffic. Give it about a minute.', cause: AiErrorCause.rateLimited);
    }

    late StreamController<String> controller;
    StreamSubscription<String?>? currentSub;
    Timer? inactivityTimer;
    Timer? overallTimer;
    bool isCancelled = false;
    bool yieldedAny = false;
    int modelIndex = 0;
    AiErrorCause lastCause = AiErrorCause.unknown;
    final sw = Stopwatch();
    int? firstTokenMs;

    void cleanup() {
      inactivityTimer?.cancel();
      overallTimer?.cancel();
      currentSub?.cancel();
    }

    void tryNextModel() {
      currentSub?.cancel();
      if (isCancelled || controller.isClosed || (cancellationToken?.isCancelled ?? false)) return;

      if (modelIndex >= textModelsToTry.length) {
        if (lastCause == AiErrorCause.rateLimited || lastCause == AiErrorCause.overloaded) {
          _textCircuitBreaker.recordFailure();
        }
        controller.addError(AiException('Failed to generate response. Please try again later.', cause: lastCause));
        controller.close();
        return;
      }

      final currentAttemptIndex = modelIndex;
      final modelName = textModelsToTry[modelIndex++];
      sw.reset();
      sw.start();
      firstTokenMs = null;

      void resetInactivityTimer() {
        inactivityTimer?.cancel();
        if (isCancelled || controller.isClosed || currentAttemptIndex != (modelIndex - 1)) return;
        inactivityTimer = Timer(inactivityTimeout, () {
          if (isCancelled || controller.isClosed || currentAttemptIndex != (modelIndex - 1)) return;
          currentSub?.cancel();
          if (yieldedAny) {
            cleanup();
            controller.addError(AiException('Stream failed midway. Please try again.', cause: AiErrorCause.timeout));
            controller.close();
          } else {
            lastCause = AiErrorCause.timeout;
            tryNextModel();
          }
        });
      }

      resetInactivityTimer();

      try {
        final stream = _callModelStream(
          modelName: modelName,
          prompt: prompt,
          systemInstruction: systemInstruction,
          apiKey: apiKey,
        );

        currentSub = stream.listen(
          (chunk) {
            if (isCancelled || controller.isClosed || currentAttemptIndex != (modelIndex - 1)) return;
            if (chunk != null && chunk.isNotEmpty) {
              if (firstTokenMs == null) {
                firstTokenMs = sw.elapsedMilliseconds;
              }
              yieldedAny = true;
              resetInactivityTimer();
              controller.add(chunk);
            }
          },
          onError: (e) {
            if (isCancelled || controller.isClosed || currentAttemptIndex != (modelIndex - 1)) return;
            sw.stop();
            final errStr = e.toString();
            final cause = (e is AiException && e.cause != null) ? e.cause! : _classifyError(errStr);
            lastCause = cause;

            AiLogger.log(
              purpose: 'text stream fallback',
              model: modelName,
              durationMs: sw.elapsedMilliseconds,
              firstTokenMs: firstTokenMs,
              outcome: cause.toString(),
            );

            if (yieldedAny) {
              cleanup();
              controller.addError(AiException('Stream failed midway. Please try again.', cause: cause));
              controller.close();
            } else if (cause == AiErrorCause.parse) {
              cleanup();
              controller.addError(AiException('AI returned an invalid format. Please try again.\nDetails: $errStr', cause: cause));
              controller.close();
            } else if (cause == AiErrorCause.invalidKey) {
              cleanup();
              controller.addError(AiException('This API key is invalid, disabled, or restricted. Please check Google AI Studio and ensure no IP or app restrictions are applied.', cause: cause));
              controller.close();
            } else if (cause == AiErrorCause.offline) {
              cleanup();
              controller.addError(AiException('You seem to be offline. Please check your internet connection.', cause: cause));
              controller.close();
            } else if (cause == AiErrorCause.timeout) {
              cleanup();
              controller.addError(AiException('AI stream timed out.', cause: AiErrorCause.timeout));
              controller.close();
            } else {
              tryNextModel();
            }
          },
          onDone: () {
            if (isCancelled || controller.isClosed || currentAttemptIndex != (modelIndex - 1)) return;
            if (!yieldedAny) {
              tryNextModel();
              return;
            }
            cleanup();
            sw.stop();
            AiLogger.log(
              purpose: 'text stream',
              model: modelName,
              durationMs: sw.elapsedMilliseconds,
              firstTokenMs: firstTokenMs,
              outcome: 'success',
            );
            _textCircuitBreaker.recordSuccess();
            controller.close();
          },
        );
      } catch (e) {
        if (isCancelled || controller.isClosed || currentAttemptIndex != (modelIndex - 1)) return;
        final cause = (e is AiException && e.cause != null) ? e.cause! : _classifyError(e.toString());
        lastCause = cause;
        tryNextModel();
      }
    }

    controller = StreamController<String>(
      onListen: () {
        overallTimer = Timer(overallTimeout, () {
          if (isCancelled || controller.isClosed) return;
          cleanup();
          controller.addError(AiException('Operation deadline exceeded.', cause: AiErrorCause.timeout));
          controller.close();
        });
        tryNextModel();
      },
      onCancel: () {
        isCancelled = true;
        cleanup();
      },
    );

    return controller.stream;
  }

  Stream<String?> _callModelStream({
    required String modelName,
    required String prompt,
    required String systemInstruction,
    String? apiKey,
  }) {
      if (mockCallModelStream != null) {
        return mockCallModelStream!(
          modelName: modelName,
          prompt: prompt,
          systemInstruction: systemInstruction,
          apiKey: apiKey,
        );
      }
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
      
      return responseStream
          .map((response) => response.text)
          .where((text) => text != null && text.isNotEmpty);
  }

  Map<String, dynamic> _parseJson(String text) {
    try {
      final cleaned = text.replaceAll('```json', '').replaceAll('```', '').trim();
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      throw AiException('Something went wrong parsing the response. Please try again.', cause: AiErrorCause.parse);
    }
  }
}

