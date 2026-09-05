import re

file_path = "lib/screens/profile/profile_screen.dart"
with open(file_path, "r", encoding="utf-8") as f:
    code = f.read()

# Add imports
imports = """import 'dart:async';
import '../../services/ai_logger.dart';
import '../../services/ai_client.dart';
"""
code = code.replace("import 'package:flutter/foundation.dart';", imports + "import 'package:flutter/foundation.dart';")

# Add MenuCard for AI Activity
menu_ai = """              _MenuCard(
                icon: Icons.auto_awesome_rounded,
                title: 'AI Settings',
                subtitle: 'Coach name & Gemini API key (optional)',
                onTap: () => _showGeminiKeyDialog(context, ref, profile),
              ),"""

new_menu_ai = """              _MenuCard(
                icon: Icons.auto_awesome_rounded,
                title: 'AI Settings',
                subtitle: 'Coach name & Gemini API key (optional)',
                onTap: () => _showGeminiKeyDialog(context, ref, profile),
              ),
              _MenuCard(
                icon: Icons.history_rounded,
                title: 'Recent AI Activity',
                subtitle: 'View local diagnostic logs',
                onTap: () => showAppBottomSheet(context: context, builder: (_) => const _AiActivitySheet()),
              ),"""
code = code.replace(menu_ai, new_menu_ai)

# Now, we define the new classes at the end of the file.
new_classes = """
class _AiActivitySheet extends StatelessWidget {
  const _AiActivitySheet();
  @override
  Widget build(BuildContext context) {
    if (AiLogger.logs.isEmpty) {
      return AppSheet(
        title: 'Recent AI Activity',
        scrollable: true,
        child: const Padding(
           padding: EdgeInsets.all(24),
           child: Center(child: Text('No AI requests made yet.')),
        )
      );
    }
    return AppSheet(
      title: 'Recent AI Activity',
      scrollable: true,
      child: Column(
        children: AiLogger.logs.map((log) => ListTile(
           title: Text('${log.purpose} • ${log.model}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor)),
           subtitle: Text('Outcome: ${log.outcome}\\n${log.timestamp.toString().substring(11, 16)}', style: const TextStyle(fontSize: 12)),
           trailing: Text('${log.durationMs} ms', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
           contentPadding: EdgeInsets.zero,
        )).toList(),
      )
    );
  }
}

class _DiagnosticsTestSheet extends StatefulWidget {
  final WidgetRef ref;
  const _DiagnosticsTestSheet({required this.ref});
  @override
  State<_DiagnosticsTestSheet> createState() => _DiagnosticsTestSheetState();
}

class _DiagnosticsTestSheetState extends State<_DiagnosticsTestSheet> {
  final Map<String, Map<String, dynamic>> _results = {};
  bool _isTesting = false;
  
  @override
  void initState() {
    super.initState();
    _runTests();
  }
  
  Future<void> _runTests() async {
    setState(() => _isTesting = true);
    final allModels = {...AiClient.textModelsToTry, ...AiClient.visionModelsToTry}.toList();
    final client = widget.ref.read(geminiFoodServiceProvider).aiClient;
    final useFirebase = widget.ref.read(isSignedInProvider);
    final profile = widget.ref.read(profileProvider);
    
    for (final model in allModels) {
      if (!mounted) break;
      final sw = Stopwatch()..start();
      try {
        await client.generateJson(
          prompt: '{"test":"Respond with exactly {\\"status\\":\\"ok\\"}"}',
          systemInstruction: 'Respond only in valid JSON.',
          useFirebase: useFirebase,
          apiKey: profile.geminiApiKey,
          skipCache: true,
        );
        sw.stop();
        if (mounted) setState(() { _results[model] = {'status': '✓', 'latency': sw.elapsedMilliseconds, 'error': null}; });
      } catch (e) {
        sw.stop();
        final cause = (e is AiException) ? e.cause : null;
        if (mounted) setState(() { _results[model] = {'status': '✗', 'latency': sw.elapsedMilliseconds, 'error': cause?.toString() ?? e.toString()}; });
      }
    }
    if (mounted) setState(() => _isTesting = false);
  }
  
  @override
  Widget build(BuildContext context) {
     return AppSheet(
       title: 'AI Connection Test',
       scrollable: true,
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.stretch,
         children: [
            if (_isTesting) const LinearProgressIndicator(), 
            const SizedBox(height: 16),
            ..._results.entries.map((e) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                color: Colors.transparent,
                child: Row(
                  children: [
                    Text(e.value['status'], style: TextStyle(color: e.value['status'] == '✓' ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                          Text(e.key, style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (e.value['error'] != null) Text(e.value['error'], style: const TextStyle(color: Colors.red, fontSize: 12)),
                       ],
                    )),
                    Text('${e.value['latency']} ms'),
                  ]
                )
            )).toList()
         ]
       )
     );
  }
}
"""

code = code + new_classes

old_test_connection_btn = """                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(key.isNotEmpty ? 'Connected & Verified ✅' : 'AI settings saved successfully'),
                      backgroundColor: context.colors.green,
                    ),
                  );
                  Navigator.of(ctx).pop();
                }
              },
            ),
          ],
        ),"""

new_test_connection_btn = """                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(key.isNotEmpty ? 'Connected & Verified ✅' : 'AI settings saved successfully'),
                      backgroundColor: context.colors.green,
                    ),
                  );
                  Navigator.of(ctx).pop();
                }
              },
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () { 
                 Navigator.pop(ctx);
                 showAppBottomSheet(context: context, builder: (_) => _DiagnosticsTestSheet(ref: ref)); 
              },
              icon: const Icon(Icons.speed_rounded),
              label: const Text('Test AI connection'),
            ),
          ],
        ),"""

code = code.replace(old_test_connection_btn, new_test_connection_btn)

with open(file_path, "w", encoding="utf-8") as f:
    f.write(code)

print("Updated profile_screen")
