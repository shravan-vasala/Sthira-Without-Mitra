import 'dart:io';
import 'package:trufit_bodamma/services/ai_client.dart';
import 'package:googleai_dart/googleai_dart.dart';

void main() async {
  final client = GoogleAIClient(apiKey: 'fake');
  try {
    throw Exception('Error testing format: Invalid request: quota exceeded');
  } catch(e) {
    print(classifyAiError(e.toString()));
  }
}
