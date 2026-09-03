import 'dart:io';

void main() {
  final file = File('pubspec.yaml');
  var content = file.readAsStringSync();
  
  content = content.replaceAll(RegExp(r'share_plus: \^12\.0\.3'), 'share_plus: any');
  content = content.replaceAll(RegExp(r'home_widget: \^0\.9\.4'), 'home_widget: any');
  content = content.replaceAll(RegExp(r'mobile_scanner: \^7\.5\.0'), 'mobile_scanner: any');
  content = content.replaceAll(RegExp(r'flutter_timezone: \^5\.1\.1'), 'flutter_timezone: any');
  
  file.writeAsStringSync(content);
  print('Updated pubspec dependencies to any.');
}
