import 'dart:isolate'; import 'dart:io'; void main() async { var uri = await Isolate.resolvePackageUri(Uri.parse('package:csv/csv.dart')); print(File(uri!.toFilePath()).readAsStringSync()); }
