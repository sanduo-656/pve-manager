import 'dart:io';

/// Keep the version shown inside the app aligned with pubspec.
void main(List<String> arguments) {
  if (arguments.any((argument) => argument != '--check')) {
    stderr.writeln('Usage: dart run tool/sync_app_version.dart [--check]');
    exitCode = 64;
    return;
  }
  final root = File.fromUri(Platform.script).parent.parent;
  final pubspec = File('${root.path}/pubspec.yaml').readAsStringSync();
  final matches = RegExp(
    r'^version:\s*(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)(?:\+(\d+))?\s*(?:#.*)?$',
    multiLine: true,
  ).allMatches(pubspec).toList();
  if (matches.length != 1) {
    stderr.writeln('pubspec.yaml must contain one valid top-level version.');
    exitCode = 65;
    return;
  }
  final version = matches.single.group(1)!;
  final buildNumber = int.tryParse(matches.single.group(2) ?? '1');
  if (buildNumber == null || buildNumber < 1 || buildNumber > 2100000000) {
    stderr.writeln('The Android build number must be within 1..2100000000.');
    exitCode = 65;
    return;
  }
  final generated =
      '''// Generated from pubspec.yaml by tool/sync_app_version.dart.
// Run the generator after changing the package version.
abstract final class AppInfo {
  static const name = 'PVE 管家';
  static const version = '$version';
  static const buildNumber = $buildNumber;
  static const displayName = '\$name v\$version';
}
''';
  final output = File('${root.path}/lib/app/app_info.dart');
  final isCurrent =
      output.existsSync() && output.readAsStringSync() == generated;
  if (arguments.contains('--check')) {
    if (!isCurrent) {
      stderr.writeln(
        'Run dart run tool/sync_app_version.dart to update AppInfo.',
      );
      exitCode = 1;
    }
    return;
  }
  if (!isCurrent) output.writeAsStringSync(generated);
  stdout.writeln('In-app title: PVE 管家 v$version (build $buildNumber)');
}
