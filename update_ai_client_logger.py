import re

file_path = "lib/services/ai_client.dart"
with open(file_path, "r", encoding="utf-8") as f:
    code = f.read()

if "import 'ai_logger.dart';" not in code:
    code = code.replace("import 'package:flutter/foundation.dart';", "import 'package:flutter/foundation.dart';\\nimport 'ai_logger.dart';")

# In generateJson, add StopWatch
old_call = """          final response = await _callModel(
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
          return json;"""

new_call = """          final sw = Stopwatch()..start();
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
          sw.stop();
          
          if (response == null || response.isEmpty) throw AiException("Empty response", cause: AiErrorCause.unknown);
          
          final json = _parseJson(response);
          if (i > 0) json['modelUsed'] = modelName;
          
          AiLogger.log(purpose: isVision ? 'scan plate (vision)' : 'scan description', model: modelName, durationMs: sw.elapsedMilliseconds, outcome: 'success');
          
          breaker.recordSuccess();
          if (cache != null) await cache!.set(prompt, json, imageContext);
          return json;"""

code = code.replace(old_call, new_call)

error_handling = """          final cause = (e is AiException && e.cause != null) ? e.cause! : _classifyError(errStr);
          lastCause = cause;
          lastErrorMsg = errStr;"""

new_error_handling = """          final cause = (e is AiException && e.cause != null) ? e.cause! : _classifyError(errStr);
          lastCause = cause;
          lastErrorMsg = errStr;
          AiLogger.log(purpose: 'AI error fallback', model: modelName, durationMs: 0, outcome: cause.toString());"""
code = code.replace(error_handling, new_error_handling)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(code)

print("Injected AiLogger into ai_client.dart")
