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
  final e01 = screens['E01'] as Map<String, dynamic>;
  final e01Top = e01['topBar'] as Map<String, dynamic>;
  final e01Summary = e01['mapSummary'] as Map<String, dynamic>;
  final e01Dock = e01['nextDock'] as Map<String, dynamic>;
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

abstract final class DriverE01Metrics {
  static const String source = '${e01['source']}';

  static const double topBarHeight = ${_double(e01Top['height'])};
  static const double topBarPaddingHorizontal = ${_double(e01Top['paddingHorizontal'])};
  static const double compactTopBarPaddingHorizontal = ${_double(e01Top['compactPaddingHorizontal'])};
  static const double topButtonSize = ${_double(e01Top['buttonSize'])};
  static const double compactTopButtonSize = ${_double(e01Top['compactButtonSize'])};
  static const double topColumnGap = ${_double(e01Top['columnGap'])};
  static const double compactTopColumnGap = ${_double(e01Top['compactColumnGap'])};
  static const double topButtonRadius = ${_double(e01Top['buttonRadius'])};
  static const double topIconSize = ${_double(e01Top['iconSize'])};
  static const double topStateGap = ${_double(e01Top['stateGap'])};
  static const double topStateDotSize = ${_double(e01Top['stateDotSize'])};
  static const double topStateSize = ${_double(e01Top['stateSize'])};
  static const double topStateHeight = ${_double(e01Top['stateHeight'])};
  static const double topStateWeight = ${_double(e01Top['stateWeight'])};
  static const double topStateTracking = ${_double(e01Top['stateTracking'])};
  static const double topTitleGap = ${_double(e01Top['titleGap'])};
  static const double topTitleSize = ${_double(e01Top['titleSize'])};
  static const double compactTopTitleSize = ${_double(e01Top['compactTitleSize'])};
  static const double topTitleHeight = ${_double(e01Top['titleHeight'])};
  static const double topTitleWeight = ${_double(e01Top['titleWeight'])};
  static const double topTitleTracking = ${_double(e01Top['titleTracking'])};

  static const double mapSummaryLeft = ${_double(e01Summary['left'])};
  static const double compactMapSummaryLeft = ${_double(e01Summary['compactLeft'])};
  static const double mapSummaryTop = ${_double(e01Summary['top'])};
  static const double compactMapSummaryTop = ${_double(e01Summary['compactTop'])};
  static const double mapSummaryPaddingHorizontal = ${_double(e01Summary['paddingHorizontal'])};
  static const double mapSummaryPaddingVertical = ${_double(e01Summary['paddingVertical'])};
  static const double mapSummaryRadius = ${_double(e01Summary['radius'])};
  static const double mapSummaryTitleSize = ${_double(e01Summary['titleSize'])};
  static const double mapSummaryTitleWeight = ${_double(e01Summary['titleWeight'])};
  static const double mapSummaryDetailGap = ${_double(e01Summary['detailGap'])};
  static const double mapSummaryDetailSize = ${_double(e01Summary['detailSize'])};
  static const double mapSummaryDetailWeight = ${_double(e01Summary['detailWeight'])};

  static const double dockHeight = ${_double(e01Dock['height'])};
  static const double compactDockHeight = ${_double(e01Dock['compactHeight'])};
  static const double dockPaddingLeft = ${_double(e01Dock['paddingLeft'])};
  static const double dockPaddingTop = ${_double(e01Dock['paddingTop'])};
  static const double dockPaddingRight = ${_double(e01Dock['paddingRight'])};
  static const double dockPaddingBottom = ${_double(e01Dock['paddingBottom'])};
  static const double compactDockPaddingHorizontal = ${_double(e01Dock['compactPaddingHorizontal'])};
  static const double compactDockPaddingTop = ${_double(e01Dock['compactPaddingTop'])};
  static const double compactDockPaddingBottom = ${_double(e01Dock['compactPaddingBottom'])};
  static const double dockColumnGap = ${_double(e01Dock['columnGap'])};
  static const double kickerSize = ${_double(e01Dock['kickerSize'])};
  static const double kickerHeight = ${_double(e01Dock['kickerHeight'])};
  static const double kickerWeight = ${_double(e01Dock['kickerWeight'])};
  static const double kickerTracking = ${_double(e01Dock['kickerTracking'])};
  static const double nameGap = ${_double(e01Dock['nameGap'])};
  static const double nameSize = ${_double(e01Dock['nameSize'])};
  static const double compactNameSize = ${_double(e01Dock['compactNameSize'])};
  static const double nameHeight = ${_double(e01Dock['nameHeight'])};
  static const double nameWeight = ${_double(e01Dock['nameWeight'])};
  static const double nameTracking = ${_double(e01Dock['nameTracking'])};
  static const double placeGap = ${_double(e01Dock['placeGap'])};
  static const double placeSize = ${_double(e01Dock['placeSize'])};
  static const double placeHeight = ${_double(e01Dock['placeHeight'])};
  static const double placeWeight = ${_double(e01Dock['placeWeight'])};
  static const double etaPaddingTop = ${_double(e01Dock['etaPaddingTop'])};
  static const double etaSize = ${_double(e01Dock['etaSize'])};
  static const double compactEtaSize = ${_double(e01Dock['compactEtaSize'])};
  static const double etaHeight = ${_double(e01Dock['etaHeight'])};
  static const double etaWeight = ${_double(e01Dock['etaWeight'])};
  static const double etaTracking = ${_double(e01Dock['etaTracking'])};
  static const double distanceGap = ${_double(e01Dock['distanceGap'])};
  static const double distanceSize = ${_double(e01Dock['distanceSize'])};
  static const double distanceWeight = ${_double(e01Dock['distanceWeight'])};
  static const double taskMarginTop = ${_double(e01Dock['taskMarginTop'])};
  static const double compactTaskMarginTop = ${_double(e01Dock['compactTaskMarginTop'])};
  static const double taskGap = ${_double(e01Dock['taskGap'])};
  static const double taskDotSize = ${_double(e01Dock['taskDotSize'])};
  static const double taskSize = ${_double(e01Dock['taskSize'])};
  static const double taskWeight = ${_double(e01Dock['taskWeight'])};
  static const double primaryHeight = ${_double(e01Dock['primaryHeight'])};
  static const double compactPrimaryHeight = ${_double(e01Dock['compactPrimaryHeight'])};
  static const double primaryMarginTop = ${_double(e01Dock['primaryMarginTop'])};
  static const double compactPrimaryMarginTop = ${_double(e01Dock['compactPrimaryMarginTop'])};
  static const double primaryRadius = ${_double(e01Dock['primaryRadius'])};
  static const double primarySize = ${_double(e01Dock['primarySize'])};
  static const double primaryWeight = ${_double(e01Dock['primaryWeight'])};
  static const double remainingHeight = ${_double(e01Dock['remainingHeight'])};
  static const double compactRemainingHeight = ${_double(e01Dock['compactRemainingHeight'])};
  static const double remainingMarginTop = ${_double(e01Dock['remainingMarginTop'])};
  static const double compactRemainingMarginTop = ${_double(e01Dock['compactRemainingMarginTop'])};
  static const double remainingPaddingHorizontal = ${_double(e01Dock['remainingPaddingHorizontal'])};
  static const double remainingSize = ${_double(e01Dock['remainingSize'])};
  static const double remainingWeight = ${_double(e01Dock['remainingWeight'])};
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
