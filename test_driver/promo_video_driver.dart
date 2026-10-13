import 'dart:convert';
import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() async {
  final adb = Platform.environment['PVE_ADB'] ?? 'adb';
  final output = Directory(
    Platform.environment['PVE_PROMO_RAW_DIR'] ?? 'build/promo/raw',
  );
  await output.create(recursive: true);
  const remote = '/sdcard/pve_manager_promo_walkthrough.mp4';
  final startUtc = DateTime.now().toUtc().toIso8601String();
  final recording = await Process.start(adb, [
    '-s',
    'emulator-5554',
    'shell',
    'screenrecord',
    '--time-limit',
    '110',
    '--bit-rate',
    '16000000',
    remote,
  ]);
  recording.stdout.transform(utf8.decoder).listen(stdout.write);
  recording.stderr.transform(utf8.decoder).listen(stderr.write);
  var finished = false;
  Future<void> finishRecording() async {
    if (finished) return;
    finished = true;
    await Process.run(adb, [
      '-s',
      'emulator-5554',
      'shell',
      'pkill',
      '-INT',
      'screenrecord',
    ]);
    await recording.exitCode.timeout(const Duration(seconds: 15));
    final pulled = await Process.run(adb, [
      '-s',
      'emulator-5554',
      'pull',
      remote,
      '${output.path}/pve_manager_walkthrough.mp4',
    ]);
    stdout.write(pulled.stdout);
    stderr.write(pulled.stderr);
    if (pulled.exitCode != 0) {
      throw StateError('Emulator recording pull failed.');
    }
  }

  try {
    await integrationDriver(
      timeout: const Duration(minutes: 4),
      writeResponseOnFailure: true,
      responseDataCallback: (data) async {
        await File('${output.path}/promo_cues.json').writeAsString(
          const JsonEncoder.withIndent('  ').convert({
            'recordingStartUtc': startUtc,
            'device': 'emulator-5554',
            'source': 'native adb screenrecord',
            ...?data,
          }),
          flush: true,
        );
        // integrationDriver exits the process after this callback. Finalize
        // and pull the recording before it reports completion.
        await finishRecording();
      },
    );
  } finally {
    await finishRecording();
  }
}
