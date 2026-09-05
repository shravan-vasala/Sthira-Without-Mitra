import os

# Fix ai_client.dart
ai_client_path = "lib/services/ai_client.dart"
with open(ai_client_path, "r", encoding="utf-8") as f:
    code_ai = f.read()

# Fix literal backslash n from earlier replace
code_ai = code_ai.replace("import 'package:flutter/foundation.dart';\\nimport 'ai_logger.dart';", "import 'package:flutter/foundation.dart';\nimport 'ai_logger.dart';")

# Fix stream timeout definition error
old_timeout_1 = "          .timeout(timeout);"
new_timeout_1 = "          .timeout(const Duration(seconds: 20));"
code_ai = code_ai.replace(old_timeout_1, new_timeout_1)

old_timeout_2 = "      ).timeout(timeout);"
new_timeout_2 = "      ).timeout(const Duration(seconds: 20));"
code_ai = code_ai.replace(old_timeout_2, new_timeout_2)

with open(ai_client_path, "w", encoding="utf-8") as f:
    f.write(code_ai)

# Fix profile_screen.dart
profile_path = "lib/screens/profile/profile_screen.dart"
with open(profile_path, "r", encoding="utf-8") as f:
    code_prof = f.read()

# Fix literal backslash n from earlier replace
bad_imports = "import 'dart:async';\\nimport '../../services/ai_logger.dart';\\nimport '../../services/ai_client.dart';\\nimport 'package:flutter/foundation.dart';"
good_imports = "import 'dart:async';\nimport '../../services/ai_logger.dart';\nimport '../../services/ai_client.dart';\nimport 'package:flutter/foundation.dart';"
code_prof = code_prof.replace(bad_imports, good_imports)

# Fix AiException null check compilation error
code_prof = code_prof.replace("final cause = (e is AiException) ? e.cause : null;", "final cause = (e is AiException) ? (e as AiException).cause : null;")

# Fix aiClient test
code_prof = code_prof.replace("final client = widget.ref.read(geminiFoodServiceProvider).aiClient;", "final client = AiClient();")

with open(profile_path, "w", encoding="utf-8") as f:
    f.write(code_prof)

print("Fixed syntax issues")
