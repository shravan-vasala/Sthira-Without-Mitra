import 'dart:io';
import 'package:trufit_bodamma/services/ai_client.dart';
import 'package:trufit_bodamma/services/gemini_food_service.dart';
import 'package:googleai_dart/googleai_dart.dart';

class MockHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return MockHttpClient();
  }
}

class MockHttpClient implements HttpClient {
  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return MockHttpClientRequest();
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpClientRequest implements HttpClientRequest {
  @override
  final HttpHeaders headers = MockHttpHeaders();
  @override
  Future<HttpClientResponse> close() async {
    return MockHttpClientResponse();
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class MockHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  @override int get statusCode => 429;
  @override String get reasonPhrase => 'Too Many Requests';
  @override HttpHeaders get headers => MockHttpHeaders();
  
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value('{"error": {"message": "quota exceeded"}}'.codeUnits).listen(
      onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError
    );
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() async {
  HttpOverrides.global = MockHttpOverrides();
  final client = GoogleAIClient(apiKey: 'fake');
  try {
    await client.models.generateContent(
      model: 'models/fake',
      request: GenerateContentRequest(contents: [Content.text('ping')])
    );
  } catch(e) {
    print('EXCEPTION:');
    print(e.runtimeType);
    print(e.toString());
    print('CLASSIFIED AS:');
    print(classifyAiError(e.toString()));
  }
}
