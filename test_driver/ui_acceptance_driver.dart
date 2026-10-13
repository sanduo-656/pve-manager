import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:integration_test/integration_test_driver.dart';

import '../test/support/rt2w7_capture_contract.dart';

Future<void> main() async {
  final directory = Directory(
    Platform.environment['PVE_SCREENSHOT_DIR'] ?? 'docs/screenshots/rt2w7',
  );
  await directory.create(recursive: true);
  await integrationDriver(
    timeout: const Duration(minutes: 3),
    writeResponseOnFailure: true,
    responseDataCallback: (data) async {
      final captures = data?['rt2w7Captures'] as List? ?? const [];
      final manifest = <Map<String, Object>>[];
      for (final raw in captures) {
        final capture = raw as Map<String, dynamic>;
        final name = capture['name'] as String;
        final expected = rt2w7CaptureSizes[name];
        final bytes = Uint8List.fromList(
          (capture['bytes'] as List).cast<int>(),
        );
        if (expected == null ||
            bytes.length < 24 ||
            bytes[0] != 0x89 ||
            bytes[1] != 0x50 ||
            bytes[2] != 0x4e ||
            bytes[3] != 0x47) {
          throw StateError(
            'Unexpected or invalid UI acceptance capture: $name',
          );
        }
        final header = ByteData.sublistView(bytes);
        final width = header.getUint32(16);
        final height = header.getUint32(20);
        if (width != expected.width ||
            height != expected.height ||
            capture['pixelRatio'] != 1) {
          throw StateError(
            '$name must be ${expected.width}x${expected.height} at pixelRatio 1; received ${width}x$height.',
          );
        }
        await File(
          '${directory.path}/$name.png',
        ).writeAsBytes(bytes, flush: true);
        manifest.add({
          'name': name,
          'width': width,
          'height': height,
          'pixelRatio': 1,
        });
        stdout.writeln('RT2W7_CAPTURE_SAVED=$name ${width}x$height');
      }
      await File('${directory.path}/rt2w7-captures.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert({
          'reference': data?['rt2w7'] ?? rt2w7CaptureNotes,
          'captures': manifest,
        }),
        flush: true,
      );
    },
  );
}
