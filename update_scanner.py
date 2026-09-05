import re

file_path = "lib/screens/home/widgets/photo_calorie_scanner_sheet.dart"
with open(file_path, "r", encoding="utf-8") as f:
    code = f.read()


# Add imports
imports = """import 'dart:async';
import '../../../../services/ai_client.dart';
"""
code = code.replace("import 'package:flutter/foundation.dart';", imports + "import 'package:flutter/foundation.dart';")

# Add state variables
state_vars_old = """  bool _describeMode = false;
  String? _confidence;
  String? _errorMessage;
  bool _isOffline = false;"""

state_vars_new = """  bool _describeMode = false;
  String? _confidence;
  String? _errorMessage;
  String? _techErrorMsg;
  AiErrorCause? _errorCause;
  bool _isOffline = false;
  
  int _analysisSessionToken = 0;
  Timer? _statusTimer;
  int _elapsedSeconds = 0;
  Timer? _countdownTimer;
  int _cooldownSeconds = 0;
  
  void _startStatusTimer() {
    _elapsedSeconds = 0;
    _statusTimer?.cancel();
    _statusTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() { _elapsedSeconds++; });
    });
  }
  
  void _startCooldown(int seconds) {
    _cooldownSeconds = seconds;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
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
    _statusTimer?.cancel();
    setState(() {
      _isAnalyzing = false;
    });
  }
"""
code = code.replace(state_vars_old, state_vars_new)

# Update _analyzeImage
code = code.replace("""    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });""", """    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _techErrorMsg = null;
      _errorCause = null;
    });
    final currentToken = ++_analysisSessionToken;
    _startStatusTimer();""")

code = code.replace("""      if (result != null) {
        _applyResult(result);
      } else {
        _showError('AI could not analyze the image.');
      }""", """      if (currentToken != _analysisSessionToken) return;
      _statusTimer?.cancel();
      if (result != null) {
        _applyResult(result);
      } else {
        _showError('AI could not analyze the image.');
      }""")

# Update _analyzeDescription
code = code.replace("""    setState(() {
      _isAnalyzing = true;
      _analysisComplete = false;
      _errorMessage = null;
      _items = [];
      _selectedImages = [];
    });""", """    setState(() {
      _isAnalyzing = true;
      _analysisComplete = false;
      _errorMessage = null;
      _techErrorMsg = null;
      _errorCause = null;
      _items = [];
      _selectedImages = [];
    });
    final currentToken = ++_analysisSessionToken;
    _startStatusTimer();""")

code = code.replace("""      if (result != null) {
        _applyResult(result);
      } else {
        _showError('AI could not estimate from that description.');
      }""", """      if (currentToken != _analysisSessionToken) return;
      _statusTimer?.cancel();
      if (result != null) {
        _applyResult(result);
      } else {
        _showError('AI could not estimate from that description.');
      }""")


# Handle analyze error
old_handle_error = """  void _handleAnalyzeError(Object e) {
    final msg = e.toString();
    if (msg.contains('Service temporarily unavailable')) {
      _showError('OFFLINE_FALLBACK');
    } else if (msg.contains('FormatException') || msg.contains('json')) {
      _showError('Couldn\\'t analyze — try again or add items yourself.');
    } else if (msg.contains('api key') || msg.contains('API key')) {
      _showError('Invalid API key. Add it in Profile → AI Settings.');
    } else if (msg.contains('SocketException') || msg.contains('network')) {
      _showError('Network error. Please check your connection.');
    } else {
      _showError(msg.replaceAll('Exception: ', ''));
    }
  }

  void _showError(String message) {
    setState(() {
      _isAnalyzing = false;
      _errorMessage = message;
    });
  }"""

new_handle_error = """  void _handleAnalyzeError(Object e) {
    _statusTimer?.cancel();
    final msg = e.toString().replaceAll('Exception: ', '').replaceAll('AiException: ', '');
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
    
    if (msg.contains('OFFLINE_FALLBACK') || msg.contains('Service temporarily unavailable')) {
       humanMsg = 'OFFLINE_FALLBACK';
    }

    setState(() {
      _isAnalyzing = false;
      _errorMessage = humanMsg;
      _techErrorMsg = msg;
      _errorCause = cause;
    });
  }

  void _showError(String message) {
    _statusTimer?.cancel();
    setState(() {
      _isAnalyzing = false;
      _errorMessage = message;
    });
  }"""
code = code.replace(old_handle_error, new_handle_error)


# Update UI parts for loading indicator (Photo section)
old_loading_ui = """                          Text(
                            'AI is analyzing your meal...',
                            style: TextStyle(
                              color: context.colors.textDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),"""
new_loading_ui = """                          Expanded(
                            child: Text(
                              _elapsedSeconds > 15 ? 'Still working — big plates take a moment...' : 'AI is analyzing your meal...',
                              style: TextStyle(
                                color: context.colors.textDark,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                              maxLines: 2,
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.cancel_rounded, color: context.colors.textMedium),
                            onPressed: _cancelAnalysis,
                          ),"""
code = code.replace(old_loading_ui, new_loading_ui)

# And for description mode
old_text_loading = """                    Text(
                      'AI is estimating macros...',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: context.colors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This usually takes 2-4 seconds',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textMedium,
                      ),
                    ),"""

new_text_loading = """                    Text(
                      _elapsedSeconds > 15 ? 'Still working — big requests take a moment...' : 'AI is estimating macros...',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: context.colors.textDark,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This usually takes 2-4 seconds',
                      style: TextStyle(
                        fontSize: 13,
                        color: context.colors.textMedium,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: _cancelAnalysis,
                      icon: const Icon(Icons.cancel),
                      label: const Text('Cancel Analysis'),
                      style: TextButton.styleFrom(foregroundColor: context.colors.textMedium),
                    ),"""
code = code.replace(old_text_loading, new_text_loading)

# Error Card logic replacement
old_error_card = """            AsyncErrorCard(
              title: 'Analysis Failed',
              message: _errorMessage!,
              onRetry: () {
                setState(() => _errorMessage = null);
                if (_describeMode) {
                  _analyzeDescription();
                } else if (_selectedImages.isNotEmpty) {
                  _analyzeImage(skipCache: true);
                } else {
                  _pickImage(ImageSource.gallery);
                }
              },
              actionText: _describeMode ? 'Try again' : 'Try again',
            ),"""

new_error_card = """            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.colors.red.withValues(alpha: 0.1),
                border: Border.all(color: context.colors.red.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: context.colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: context.colors.textDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_techErrorMsg != null && _techErrorMsg != _errorMessage) ...[
                    const SizedBox(height: 12),
                    Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        title: Text('Details', style: TextStyle(fontSize: 13, color: context.colors.red)),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: const EdgeInsets.only(bottom: 8),
                        children: [
                          Text(
                            _techErrorMsg!,
                            style: TextStyle(fontSize: 12, fontFamily: 'monospace', color: context.colors.textMedium),
                          )
                        ]
                      )
                    )
                  ],
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _cooldownSeconds > 0 ? null : () {
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
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) 
                      : const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(_cooldownSeconds > 0 ? 'Wait $_cooldownSeconds s...' : 'Try again'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),"""

code = code.replace(old_error_card, new_error_card)


with open(file_path, "w", encoding="utf-8") as f:
    f.write(code)

print("Updated scanner sheet")
