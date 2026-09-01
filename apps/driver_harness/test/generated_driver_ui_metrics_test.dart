import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/generate_driver_ui_metrics.dart';

void main() {
  test('generated Driver UI constants match the canonical geometry spec', () {
    final spec =
        jsonDecode(File('design/driver_ui_spec.json').readAsStringSync())
            as Map<String, dynamic>;
    final checkedIn = File(
      'lib/src/app/generated/driver_ui_metrics.g.dart',
    ).readAsStringSync();

    expect(checkedIn, generateDriverUiMetrics(spec));
  });
}
