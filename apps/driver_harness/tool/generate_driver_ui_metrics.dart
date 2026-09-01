import 'dart:convert';
import 'dart:io';

const _sourcePath = 'design/driver_ui_spec.json';
const _outputPath = 'lib/src/app/generated/driver_ui_metrics.g.dart';

void main(List<String> arguments) {
  final source = File(_sourcePath);
  if (!source.existsSync()) {
    stderr.writeln('Missing canonical Driver UI spec: $_sourcePath');
    exitCode = 1;
    return;
  }

  final json = jsonDecode(source.readAsStringSync()) as Map<String, dynamic>;
  final generated = generateDriverUiMetrics(json);

  final output = File(_outputPath);
  if (arguments.contains('--check')) {
    if (!output.existsSync() || output.readAsStringSync() != generated) {
      stderr.writeln(
        'Generated Driver UI metrics are stale. Run: '
        'dart run tool/generate_driver_ui_metrics.dart',
      );
      exitCode = 1;
    }
    return;
  }

  output.parent.createSync(recursive: true);
  output.writeAsStringSync(generated);
}

String generateDriverUiMetrics(Map<String, dynamic> json) {
  final viewport = json['referenceViewport'] as Map<String, dynamic>;
  final screens = json['screens'] as Map<String, dynamic>;
  final e02 = screens['E02'] as Map<String, dynamic>;
  final control = e02['roadControl'] as Map<String, dynamic>;
  final dock = e02['stopDock'] as Map<String, dynamic>;
  final type = e02['typography'] as Map<String, dynamic>;

  return '''// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: $_sourcePath

abstract final class DriverReferenceViewport {
  static const double width = ${_double(viewport['width'])};
  static const double height = ${_double(viewport['height'])};
  static const double compactBreakpoint = ${_double(viewport['compactBreakpoint'])};
}

abstract final class DriverE02Metrics {
  static const String source = '${e02['source']}';

  static const double roadControlSize = ${_double(control['size'])};
  static const double compactRoadControlSize = ${_double(control['compactSize'])};
  static const double roadControlRadius = ${_double(control['radius'])};
  static const double roadControlIconSize = ${_double(control['iconSize'])};
  static const double outerMargin = ${_double(control['outerMargin'])};
  static const double compactOuterMargin = ${_double(control['compactOuterMargin'])};
  static const double roadControlGap = ${_double(control['gap'])};
  static const double compactRoadControlGap = ${_double(control['compactGap'])};
  static const double vendorSafeBottomGap = ${_double(control['vendorSafeBottomGap'])};

  static const double dockRowHeight = ${_double(dock['rowHeight'])};
  static const double compactDockRowHeight = ${_double(dock['compactRowHeight'])};
  static const double dockPaddingHorizontal = ${_double(dock['paddingHorizontal'])};
  static const double dockPaddingVertical = ${_double(dock['paddingVertical'])};
  static const double compactDockPadding = ${_double(dock['compactPadding'])};
  static const double dockColumnGap = ${_double(dock['columnGap'])};
  static const double dockRadius = ${_double(dock['radius'])};
  static const double dockBorderWidth = ${_double(dock['borderWidth'])};
  static const double dockTextGap = ${_double(dock['textGap'])};
  static const double arrivalHeight = ${_double(dock['arrivalHeight'])};
  static const double arrivalMarginHorizontal = ${_double(dock['arrivalMarginHorizontal'])};
  static const double arrivalMarginBottom = ${_double(dock['arrivalMarginBottom'])};
  static const double pendingStatusHeight = ${_double(dock['pendingStatusHeight'])};

  static const double kickerSize = ${_double(type['kickerSize'])};
  static const double kickerHeight = ${_double(type['kickerHeight'])};
  static const double kickerWeight = ${_double(type['kickerWeight'])};
  static const double kickerTracking = ${_double(type['kickerTracking'])};
  static const double titleSize = ${_double(type['titleSize'])};
  static const double compactTitleSize = ${_double(type['compactTitleSize'])};
  static const double titleHeight = ${_double(type['titleHeight'])};
  static const double titleWeight = ${_double(type['titleWeight'])};
  static const double titleTracking = ${_double(type['titleTracking'])};
  static const double placeSize = ${_double(type['placeSize'])};
  static const double placeHeight = ${_double(type['placeHeight'])};
  static const double placeWeight = ${_double(type['placeWeight'])};
  static const double etaSize = ${_double(type['etaSize'])};
  static const double compactEtaSize = ${_double(type['compactEtaSize'])};
  static const double etaHeight = ${_double(type['etaHeight'])};
  static const double etaWeight = ${_double(type['etaWeight'])};
  static const double etaTracking = ${_double(type['etaTracking'])};
  static const double distanceSize = ${_double(type['distanceSize'])};
  static const double distanceHeight = ${_double(type['distanceHeight'])};
  static const double distanceWeight = ${_double(type['distanceWeight'])};
  static const double arrivalSize = ${_double(type['arrivalSize'])};
  static const double arrivalWeight = ${_double(type['arrivalWeight'])};
}
''';
}

String _double(Object? value) {
  final number = value as num;
  return number is int ? '${number.toDouble()}' : number.toString();
}
