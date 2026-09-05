import os
import re

file_path = "lib/services/ai_client.dart"
with open(file_path, "r", encoding="utf-8") as f:
    code = f.read()

# Replace Exception
old_exception = """class AiException implements Exception {
  final String message;
  AiException(this.message);
  @override
  String toString() => message;
}"""

new_exception = """enum AiErrorCause { invalidKey, offline, notFound, rateLimited, overloaded, parse, timeout, unknown }

class AiException implements Exception {
  final String message;
  final AiErrorCause? cause;
  AiException(this.message, {this.cause});
  @override
  String toString() => message;
}

AiErrorCause _classifyError(String errorString) {
  if (errorString.contains('API_KEY_INVALID') || errorString.contains('API key not valid') || errorString.contains('disabled') || errorString.contains('has not been used in project')) {
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
}"""

code = code.replace(old_exception, new_exception)

# Remove temperatures
code = re.sub(r'temperature:\s*[\d\.]+,\s*', '', code)


# Let's replace generateJson function entirely
generate_json_replacement = """  Future<Map<String, dynamic>?> generateJson({
    required String prompt,
    required String systemInstruction,
    List<Uint8List>? imageBytesList,
    String? mimeType,
    required bool useFirebase,
    String? apiKey,
    bool skipCache = false,
  }) async {
    if (!useFirebase && (apiKey == null || apiKey.isEmpty)) {
      throw AiException('API Key is required if not using Firebase. Add it in Profile -> AI Settings.', cause: AiErrorCause.invalidKey);
    }

    String? imageContext;
    final List<Uint8List> processedImages = [];
    String? actualMimeType = mimeType;
    if (imageBytesList != null && imageBytesList.isNotEmpty) {
      final b = BytesBuilder();
      for (var imageBytes in imageBytesList) {
        final processed = await ImagePreprocessor.processImage(imageBytes, mimeType ?? 'image/jpeg');
        processedImages.add(processed.$1);
        actualMimeType = processed.$2;
        b.add(processed.$1);
      }
      imageContext = sha256.convert(b.toBytes()).toString();
    }

    if (cache != null && !skipCache) {
      final cachedResult = cache!.get(prompt, imageContext);
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
        try {
          debugPrint('AiClient: Trying model: $modelName (attempt ${attempt + 1})...');
          final response = await _callModel(
            modelName: modelName,
            prompt: prompt,
            systemInstruction: systemInstruction,
            useFirebase: useFirebase,
            apiKey: apiKey,
            imageBytesList: processedImages.isNotEmpty ? processedImages : null,
            mimeType: actualMimeType,
            timeout: perAttemptTimeout,
          );
          
          if (response == null || response.isEmpty) throw AiException("Empty response", cause: AiErrorCause.unknown);
          
          final json = _parseJson(response);
          if (i > 0) json['modelUsed'] = modelName;
          
          breaker.recordSuccess();
          if (cache != null) await cache!.set(prompt, json, imageContext);
          return json;
          
        } catch (e) {
          final errStr = e.toString();
          final cause = (e is AiException && e.cause != null) ? e.cause! : _classifyError(errStr);
          lastCause = cause;
          lastErrorMsg = errStr;
          
          if (cause == AiErrorCause.invalidKey) {
            throw AiException('Your API Key is invalid or not authorized. Please check your AI Settings.', cause: cause);
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
    
    throw AiException('Couldn\\'t analyze right now ($reason). Try again in a minute.', cause: lastCause);
  }"""

# Inject timeout into _callModel params
code = code.replace(
    '''  Future<String?> _callModel({
    required String modelName,
    required String prompt,
    String? systemInstruction,
    required bool useFirebase,
    String? apiKey,
    List<Uint8List>? imageBytesList,
    String? mimeType,
  }) async {''',
    '''  Future<String?> _callModel({
    required String modelName,
    required String prompt,
    String? systemInstruction,
    required bool useFirebase,
    String? apiKey,
    List<Uint8List>? imageBytesList,
    String? mimeType,
    Duration timeout = const Duration(seconds: 30),
  }) async {'''
)
code = code.replace(
    '''.timeout(const Duration(seconds: 30));''',
    '''.timeout(timeout);'''
)

# And now generateTextStream
generate_text_stream_replacement = """  Stream<String> generateTextStream({
    required String prompt,
    required String systemInstruction,
    required bool useFirebase,
    String? apiKey,
  }) async* {
    if (_textCircuitBreaker.isOpen) {
      throw AiException('Our AI is taking a quick breather to handle traffic. Give it about a minute.', cause: AiErrorCause.rateLimited);
    }

    AiErrorCause? lastCause;

    for (final modelName in textModelsToTry) {
      try {
        final stream = _callModelStream(
          modelName: modelName,
          prompt: prompt,
          systemInstruction: systemInstruction,
          useFirebase: useFirebase,
          apiKey: apiKey,
        );
        
        await for (final chunk in stream) {
           if (chunk != null && chunk.isNotEmpty) yield chunk;
         }
         _textCircuitBreaker.recordSuccess();
         return;
       } catch (e) {
        final errStr = e.toString();
        final cause = (e is AiException && e.cause != null) ? e.cause! : _classifyError(errStr);
        lastCause = cause;
        
        if (cause == AiErrorCause.invalidKey) {
          throw AiException('Your API Key is invalid or not authorized.', cause: cause);
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
    
    if (lastCause == AiErrorCause.rateLimited || lastCause == AiErrorCause.overloaded) {
      _textCircuitBreaker.recordFailure();
    }
    
    String reason = 'unknown error';
    if (lastCause == AiErrorCause.rateLimited) reason = 'rate limited';
    if (lastCause == AiErrorCause.overloaded) reason = 'model overloaded';
    if (lastCause == AiErrorCause.timeout) reason = 'timed out';
    
    throw AiException('Failed to generate response ($reason). Please try again later.', cause: lastCause);
  }"""

# Do regex substitution for functions
import re
code = re.sub(r'Future<Map<String, dynamic>\?> generateJson.*?throw AiException.*?;\n  \}', generate_json_replacement, code, flags=re.DOTALL)
code = re.sub(r'Stream<String> generateTextStream.*?throw AiException.*?;\n  \}', generate_text_stream_replacement, code, flags=re.DOTALL)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(code)

print("success")
