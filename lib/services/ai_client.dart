import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'ai_logger.dart';
import 'package:googleai_dart/googleai_dart.dart';
import 'package:crypto/crypto.dart';
import 'ai_cache.dart';
import 'dart:async';
import 'dart:io';
import 'image_preprocessor.dart';
import 'ai_profiler.dart';

class CancellationToken {
  bool _isCancelled = false;
  bool get isCancelled => _isCancelled;
  final _completer = Completer<void>();
  Future<void> get onCancelled => _completer.future;

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _completer.complete();
  }
}

enum AiErrorCause {
  invalidKey,
  offline,
  notFound,
  rateLimited,
  overloaded,
  parse,
  timeout,
  cancelled,
  unknown,
}

class AiException implements Exception {
  final String message;
  final AiErrorCause? cause;
  AiException(this.message, {this.cause});
  @override
  String toString() => message;
}

AiErrorCause classifyAiError(String errorString) {
  if (errorString.contains('API_KEY_INVALID') ||
      errorString.contains('API key not valid') ||
      errorString.contains('disabled') ||
      errorString.contains('has not been used in project') ||
      errorString.contains('deactivated') ||
      errorString.contains('SERVICE_DISABLED')) {
    return AiErrorCause.invalidKey;
  } else if (errorString.contains('PERMISSION_DENIED') ||
      errorString.contains('403') ||
      errorString.contains('forbidden')) {
    // 403 could be restricted key. It's an invalid key effectively.
    return AiErrorCause.invalidKey;
  } else if (errorString.contains('SocketException') ||
      errorString.contains('Failed host lookup')) {
    return AiErrorCause.offline;
  } else if (errorString.contains('429') ||
      errorString.contains('quota') ||
      errorString.contains('RESOURCE_EXHAUSTED')) {
    // Treat quota exhaust as rate limited, though technically it might be a daily quota.
    return AiErrorCause.rateLimited;
  } else if (errorString.contains('404') || errorString.contains('not found')) {
    return AiErrorCause.notFound;
  } else if (errorString.contains('503') ||
      errorString.contains('UNAVAILABLE') ||
      errorString.contains('overloaded')) {
    return AiErrorCause.overloaded;
  } else if (errorString.contains('FormatException') ||
      errorString.contains('json') ||
      errorString.contains('parse')) {
    return AiErrorCause.parse;
  } else if (errorString.contains('TimeoutException') ||
      errorString.contains('Timeout')) {
    return AiErrorCause.timeout;
  } else if (errorString.contains('cancelled')) {
    return AiErrorCause.cancelled;
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
      if (lastFailureTime != null &&
          DateTime.now().difference(lastFailureTime!) > resetTimeout) {
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

  // Verified Sept 2026: https://ai.google.dev/gemini-api/docs/models
  // Ordered by lowest p90 latency while preserving 0.0% hallucination rate on thali plates.
  // We exclude flash-lite models from vision due to degraded accuracy on complex plates.
  static const visionModelsToTry = [
    'gemini-3.8-flash',
    'gemini-3.7-flash',
  ];

  static const textModelsToTry = [
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
  })?
  mockCallModel;

  @visibleForTesting
  Stream<String?> Function({
    required String modelName,
    required String prompt,
    required String systemInstruction,
    String? apiKey,
  })?
  mockCallModelStream;

  AiClient({this.cache, this.mockCallModel, this.mockCallModelStream});

  void dispose() {
    _cachedClient?.close();
    _cachedClient = null;
    _cachedApiKey = null;
  }

  Future<Map<String, dynamic>?> generateJson({
    AiProfileSession? profiler,
    required String prompt,
    required String systemInstruction,
    List<Uint8List>? imageBytesList,
    String? mimeType,
    required String apiKey,
    bool skipCache = false,
    bool isAlreadyProcessed = false,
    Map<String, dynamic>? responseSchema,
    CancellationToken? cancellationToken,
    DateTime? overallDeadline,
  }) async {
    if (apiKey.isEmpty) {
      throw AiException(
        'API Key is required. Add it in Profile -> AI Settings.',
        cause: AiErrorCause.invalidKey,
      );
    }

    final fullOpSw = Stopwatch()..start();
    int? preprocessMs;

    String? imageContext;
    final List<Uint8List> processedImages = [];
    String? actualMimeType = mimeType;
    if (imageBytesList != null && imageBytesList.isNotEmpty) {
      final prepSw = Stopwatch()..start();
      
      if (isAlreadyProcessed) {
        for (var bytes in imageBytesList) {
          processedImages.add(bytes);
        }
        
        // Fast hash for cache key since we don't have ImagePreprocessor hashes
        final b = BytesBuilder();
        for (var bytes in imageBytesList) b.add(bytes);
        profiler?.startPhase('hashMs');
        imageContext = sha256.convert(b.toBytes()).toString();
        profiler?.endPhase('hashMs');
      } else {
        final processFutures = imageBytesList.map((bytes) => 
          ImagePreprocessor.processImage(bytes, mimeType ?? 'image/jpeg')
        );
        
        final processedResults = await Future.wait(processFutures).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw AiException('Image processing took too long', cause: AiErrorCause.cancelled),
        );
        
        final hashes = <String>[];
        for (var processed in processedResults) {
          processedImages.add(processed.$1);
          actualMimeType = processed.$2;
          hashes.add(processed.$3);
        }
        
        imageContext = hashes.join('_');
      }
      
      prepSw.stop();
      preprocessMs = prepSw.elapsedMilliseconds;
    }

    if (cache != null && !skipCache) {
      profiler?.startPhase('cacheLookupMs');
      final cachedResult = cache!.get(
        prompt,
        systemInstruction,
        imageContext,
        responseSchema?.toString(),
      );
      profiler?.endPhase('cacheLookupMs');
      if (cachedResult != null) return cachedResult;
    }

    final isVision = imageBytesList != null && imageBytesList.isNotEmpty;
    final breaker = isVision ? _visionCircuitBreaker : _textCircuitBreaker;

    if (breaker.isOpen) {
      throw AiException(
        'Our AI is taking a quick breather to handle traffic. Give it about a minute.',
        cause: AiErrorCause.rateLimited,
      );
    }

    if (cancellationToken?.isCancelled ?? false) {
      throw AiException(
        'Operation was cancelled.',
        cause: AiErrorCause.cancelled,
      );
    }

    final modelsToUse = isVision ? visionModelsToTry : textModelsToTry;
    final perAttemptTimeout = Duration(seconds: isVision ? 20 : 15);

    AiErrorCause? lastCause;
    String lastErrorMsg = '';

    // Deadline starts right before we actually hit the network.
    final computedDeadline = overallDeadline ??
        DateTime.now().add(Duration(seconds: isVision ? 30 : 20));

    for (int i = 0; i < modelsToUse.length; i++) {
      if (DateTime.now().isAfter(computedDeadline)) break;
      final modelName = modelsToUse[i];
      final int maxRetries =
          1; // max 2 attempts total per model for transient errors
      int attempt = 0;

      while (attempt <= maxRetries) {
        if (cancellationToken?.isCancelled ?? false) {
          throw AiException(
            'Operation was cancelled.',
            cause: AiErrorCause.cancelled,
          );
        }
        if (DateTime.now().isAfter(computedDeadline)) break;
        final remaining = computedDeadline.difference(DateTime.now());
        final attemptTimeout = remaining < perAttemptTimeout
            ? remaining
            : perAttemptTimeout;

        final sw = Stopwatch()..start();
        try {
          debugPrint(
            'AiClient: Trying model: $modelName (attempt ${attempt + 1})...',
          );

          final waitFuture = _callModel(
          profiler: profiler,
            modelName: modelName,
            prompt: prompt,
            systemInstruction: systemInstruction,
            apiKey: apiKey,
            imageBytesList: processedImages.isNotEmpty ? processedImages : null,
            mimeType: actualMimeType,
            timeout: attemptTimeout,
            responseSchema: responseSchema,
          );

          // Listen to cancellation without leaking timers
          String? response;
          if (cancellationToken != null) {
            response = await Future.any([
              waitFuture,
              cancellationToken.onCancelled.then<String?>((_) => 
                throw AiException('Operation was cancelled.', cause: AiErrorCause.cancelled)
              ),
            ]);
          } else {
            response = await waitFuture;
          }
          
          sw.stop();

          if (response == null || response.isEmpty)
            throw AiException("Empty response", cause: AiErrorCause.unknown);

          profiler?.startPhase('parseMs');
          final json = _parseJson(response);
          profiler?.endPhase('parseMs');

          AiLogger.log(
            purpose: isVision ? 'scan plate (vision)' : 'scan description',
            model: modelName,
            durationMs: sw.elapsedMilliseconds,
            preprocessMs: preprocessMs,
            outcome: 'success',
          );

          breaker.recordSuccess();
          if (cache != null) {
            unawaited(Future(() async {
              try {
                profiler?.startPhase('cacheWriteMs');
                await cache!.set(
                  prompt,
                  systemInstruction,
                  json,
                  imageContext,
                  responseSchema?.toString(),
                );
              } catch (e) {
                debugPrint('Cache write failed: $e');
              } finally {
                profiler?.endPhase('cacheWriteMs');
              }
            }));
          }
          return json;
        } catch (e) {
          sw.stop();
          final errStr = e.toString();
          final cause = (e is AiException && e.cause != null)
              ? e.cause!
              : classifyAiError(errStr);
          lastCause = cause;
          lastErrorMsg = errStr;

          AiLogger.log(
            purpose: 'AI error fallback',
            model: modelName,
            durationMs: sw.elapsedMilliseconds,
            preprocessMs: preprocessMs,
            outcome: cause.toString(),
          );

          if (cause == AiErrorCause.invalidKey) {
            throw AiException(
              'This API key is invalid, disabled, or restricted. Please check Google AI Studio and ensure no IP or app restrictions are applied.',
              cause: cause,
            );
          } else if (cause == AiErrorCause.offline) {
            throw AiException(
              'You seem to be offline. Please check your internet connection.',
              cause: cause,
            );
          } else if (cause == AiErrorCause.parse) {
            throw AiException(
              'AI returned an invalid format. Please try again.\nDetails: $errStr',
              cause: cause,
            );
          } else if (cause == AiErrorCause.notFound) {
            assert(false, 'Dead model ID used in fallback chain: $modelName. Check docs and update lists.');
            break; // Next model
          } else if (cause == AiErrorCause.rateLimited ||
              cause == AiErrorCause.overloaded) {
            if (attempt < maxRetries) {
              final delay = attempt + 1; // 1 second delay
              if (DateTime.now()
                  .add(Duration(seconds: delay))
                  .isAfter(computedDeadline)) {
                break;
              }
              if (cancellationToken?.isCancelled ?? false) break;
              await Future.delayed(Duration(seconds: delay));
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
      throw AiException(
        'Operation was cancelled.',
        cause: AiErrorCause.cancelled,
      );
    }

    if (DateTime.now().isAfter(computedDeadline)) {
      throw AiException(
        'The AI is taking too long right now. Please try again.',
        cause: AiErrorCause.timeout,
      );
    }

    if (lastCause == AiErrorCause.rateLimited ||
        lastCause == AiErrorCause.overloaded) {
      breaker.recordFailure();
    }

    String reason = 'unknown error';
    if (lastCause == AiErrorCause.rateLimited) reason = 'rate limited';
    if (lastCause == AiErrorCause.overloaded) reason = 'model overloaded';
    if (lastCause == AiErrorCause.timeout) reason = 'timed out';
    if (lastCause == AiErrorCause.parse) reason = 'parsing failed';

    throw AiException(
      'Couldn\'t analyze right now. Try again in a minute.',
      cause: lastCause,
    );
  }

  Future<String?> _callModel({
    AiProfileSession? profiler,
    required String modelName,
    required String prompt,
    String? systemInstruction,
    String? apiKey,
    List<Uint8List>? imageBytesList,
    String? mimeType,
    Map<String, dynamic>? responseSchema,
    Duration timeout = const Duration(seconds: 30),
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

    final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$modelName:generateContent?key=$apiKey');

    final payload = {
      if (systemInstruction != null)
        "system_instruction": {
          "parts": [
            {"text": systemInstruction}
          ]
        },
      "generation_config": {
        "response_mime_type": "application/json",
        if (responseSchema != null) "response_schema": responseSchema,
        "temperature": 0.1,
        "top_k": 1,
        "top_p": 0.1,
        "candidate_count": 1,
        // AI-05: Thinking level sweep result: 'low' provides identical portion accuracy 
        // while saving ~500 tokens (7s latency). 
        "thinking_level": "low"
      },
      "contents": [
        {
          "role": "user",
          "parts": [
            {"text": prompt},
            if (imageBytesList != null)
              for (var bytes in imageBytesList)
                {
                  "inline_data": {
                    "mime_type": mimeType ?? 'image/jpeg',
                    "data": base64Encode(bytes)
                  }
                }
          ]
        }
      ]
    };

    profiler?.startPhase('networkMs');
    final client = HttpClient();
    try {
      final req = await client.postUrl(url).timeout(timeout);
      req.headers.contentType = ContentType.json;
      req.write(jsonEncode(payload));
      final res = await req.close().timeout(timeout);
      final resStr = await res.transform(utf8.decoder).join();
      profiler?.endPhase('networkMs');

      final resJson = jsonDecode(resStr);
      if (res.statusCode != 200) {
        throw Exception('API Error: ${resJson['error']?['message'] ?? resStr}');
      }

      final text = resJson['candidates'][0]['content']['parts'][0]['text'];
      final usage = resJson['usageMetadata'];
      
      int? thoughtsTokens;
      if (usage != null && usage['thoughtsTokenCount'] != null) {
        thoughtsTokens = usage['thoughtsTokenCount'] as int?;
      }

      profiler?.recordMetadata(
        modelUsed: modelName,
        promptTokenCount: usage?['promptTokenCount'],
        candidatesTokenCount: usage?['candidatesTokenCount'],
        thoughtsTokenCount: thoughtsTokens,
        cachedContentTokenCount: usage?['cachedContentTokenCount'],
      );

      return text as String;
    } finally {
      client.close();
    }
  }

  Stream<String> generateTextStream({
    required String prompt,
    required String systemInstruction,
    String? apiKey,
    Duration inactivityTimeout = const Duration(seconds: 15),
    CancellationToken? cancellationToken,
    DateTime? overallDeadline,
  }) {
    if (_textCircuitBreaker.isOpen) {
      throw AiException(
        'Our AI is taking a quick breather to handle traffic. Give it about a minute.',
        cause: AiErrorCause.rateLimited,
      );
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

    Future<void> tryNextModel() async {
      await currentSub?.cancel();
      currentSub = null;
      if (isCancelled ||
          controller.isClosed ||
          (cancellationToken?.isCancelled ?? false))
        return;

      if (modelIndex >= textModelsToTry.length) {
        if (lastCause == AiErrorCause.rateLimited ||
            lastCause == AiErrorCause.overloaded) {
          _textCircuitBreaker.recordFailure();
        }
        if (!controller.isClosed) {
          controller.addError(
            AiException(
              'Failed to generate response. Please try again later.',
              cause: lastCause,
            ),
          );
          controller.close();
        }
        return;
      }

      final currentAttemptIndex = modelIndex;
      final modelName = textModelsToTry[modelIndex++];
      sw.reset();
      sw.start();
      firstTokenMs = null;

      void resetInactivityTimer() {
        inactivityTimer?.cancel();
        if (isCancelled ||
            controller.isClosed ||
            currentAttemptIndex != (modelIndex - 1))
          return;
        inactivityTimer = Timer(inactivityTimeout, () {
          if (isCancelled ||
              controller.isClosed ||
              currentAttemptIndex != (modelIndex - 1))
            return;
          if (yieldedAny) {
            cleanup();
            if (!controller.isClosed) {
              controller.addError(
                AiException(
                  'Stream failed midway. Please try again.',
                  cause: AiErrorCause.timeout,
                ),
              );
              controller.close();
            }
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

        final thisAttemptSub = stream.listen(null);
        currentSub = thisAttemptSub;

        thisAttemptSub.onData((chunk) {
          if (isCancelled ||
              controller.isClosed ||
              currentAttemptIndex != (modelIndex - 1))
            return;
          if (cancellationToken?.isCancelled ?? false) {
            cleanup();
            if (!controller.isClosed) controller.close();
            return;
          }
          if (chunk != null && chunk.isNotEmpty) {
            firstTokenMs ??= sw.elapsedMilliseconds;
            yieldedAny = true;
            resetInactivityTimer();
            controller.add(chunk);
          }
        });

        thisAttemptSub.onError((e) {
          if (isCancelled ||
              controller.isClosed ||
              currentAttemptIndex != (modelIndex - 1))
            return;
          sw.stop();
          final errStr = e.toString();
          final cause = (e is AiException && e.cause != null)
              ? e.cause!
              : classifyAiError(errStr);
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
            if (!controller.isClosed) {
              controller.addError(
                AiException(
                  'Stream failed midway. Please try again.',
                  cause: cause,
                ),
              );
              controller.close();
            }
          } else if (cause == AiErrorCause.parse) {
            cleanup();
            if (!controller.isClosed) {
              controller.addError(
                AiException(
                  'AI returned an invalid format. Please try again.\nDetails: $errStr',
                  cause: cause,
                ),
              );
              controller.close();
            }
          } else if (cause == AiErrorCause.invalidKey) {
            cleanup();
            if (!controller.isClosed) {
              controller.addError(
                AiException(
                  'This API key is invalid, disabled, or restricted. Please check Google AI Studio and ensure no IP or app restrictions are applied.',
                  cause: cause,
                ),
              );
              controller.close();
            }
          } else if (cause == AiErrorCause.offline) {
            cleanup();
            if (!controller.isClosed) {
              controller.addError(
                AiException(
                  'You seem to be offline. Please check your internet connection.',
                  cause: cause,
                ),
              );
              controller.close();
            }
          } else if (cause == AiErrorCause.timeout) {
            cleanup();
            if (!controller.isClosed) {
              controller.addError(
                AiException(
                  'AI stream timed out.',
                  cause: AiErrorCause.timeout,
                ),
              );
              controller.close();
            }
          } else {
            tryNextModel();
          }
        });

        thisAttemptSub.onDone(() {
          if (isCancelled ||
              controller.isClosed ||
              currentAttemptIndex != (modelIndex - 1))
            return;
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
          if (!controller.isClosed) controller.close();
        });
      } catch (e) {
        if (isCancelled ||
            controller.isClosed ||
            currentAttemptIndex != (modelIndex - 1))
          return;
        final cause = (e is AiException && e.cause != null)
            ? e.cause!
            : classifyAiError(e.toString());
        lastCause = cause;
        tryNextModel();
      }
    }

    controller = StreamController<String>(
      onListen: () {
        if (overallDeadline != null) {
          final remaining = overallDeadline.difference(DateTime.now());
          if (remaining.isNegative) {
            controller.addError(
              AiException(
                'Operation deadline exceeded.',
                cause: AiErrorCause.timeout,
              ),
            );
            controller.close();
            return;
          }
          overallTimer = Timer(remaining, () {
            if (isCancelled || controller.isClosed) return;
            cleanup();
            if (!controller.isClosed) {
              controller.addError(
                AiException(
                  'Operation deadline exceeded.',
                  cause: AiErrorCause.timeout,
                ),
              );
              controller.close();
            }
          });
        }
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
        config: GoogleAIConfig.googleAI(authProvider: ApiKeyProvider(apiKey)),
      );
      _cachedApiKey = apiKey;
    }

    final request = GenerateContentRequest(
      systemInstruction: Content.text(systemInstruction),
      generationConfig: const GenerationConfig(responseMimeType: 'text/plain'),
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
      final cleaned = text
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();
      return jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      throw AiException(
        'Something went wrong parsing the response. Please try again.',
        cause: AiErrorCause.parse,
      );
    }
  }
}
