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
  final d03d04 = screens['D03D04'] as Map<String, dynamic>;
  final pickupTop = d03d04['topBar'] as Map<String, dynamic>;
  final pickupContent = d03d04['content'] as Map<String, dynamic>;
  final pickupManifest = d03d04['manifest'] as Map<String, dynamic>;
  final pickupProblem = d03d04['problem'] as Map<String, dynamic>;
  final pickupFooter = d03d04['footer'] as Map<String, dynamic>;
  final e01 = screens['E01'] as Map<String, dynamic>;
  final e01Top = e01['topBar'] as Map<String, dynamic>;
  final e01Summary = e01['mapSummary'] as Map<String, dynamic>;
  final e01Dock = e01['nextDock'] as Map<String, dynamic>;
  final e02 = screens['E02'] as Map<String, dynamic>;
  final control = e02['roadControl'] as Map<String, dynamic>;
  final dock = e02['stopDock'] as Map<String, dynamic>;
  final type = e02['typography'] as Map<String, dynamic>;
  final f08 = screens['F08'] as Map<String, dynamic>;
  final f08Complete = f08['completeBar'] as Map<String, dynamic>;
  final f08Dock = f08['nextDock'] as Map<String, dynamic>;
  final i01 = screens['I01'] as Map<String, dynamic>;
  final i01Top = i01['topBar'] as Map<String, dynamic>;
  final i01Hero = i01['hero'] as Map<String, dynamic>;
  final i01Continuation = i01['continuation'] as Map<String, dynamic>;
  final i01Footer = i01['footer'] as Map<String, dynamic>;

  return '''// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: $_sourcePath

abstract final class DriverReferenceViewport {
  static const double width = ${_double(viewport['width'])};
  static const double height = ${_double(viewport['height'])};
  static const double compactBreakpoint = ${_double(viewport['compactBreakpoint'])};
}

abstract final class DriverD03D04Metrics {
  static const String source = '${d03d04['source']}';

  static const double topBarHeight = ${_double(pickupTop['height'])};
  static const double topBarPaddingHorizontal = ${_double(pickupTop['paddingHorizontal'])};
  static const double topButtonSize = ${_double(pickupTop['buttonSize'])};
  static const double topButtonRadius = ${_double(pickupTop['buttonRadius'])};
  static const double topIconSize = ${_double(pickupTop['iconSize'])};
  static const double topColumnGap = ${_double(pickupTop['columnGap'])};
  static const double topEyebrowSize = ${_double(pickupTop['eyebrowSize'])};
  static const double topEyebrowWeight = ${_double(pickupTop['eyebrowWeight'])};
  static const double topEyebrowTracking = ${_double(pickupTop['eyebrowTracking'])};
  static const double topNameGap = ${_double(pickupTop['nameGap'])};
  static const double topNameSize = ${_double(pickupTop['nameSize'])};
  static const double topNameWeight = ${_double(pickupTop['nameWeight'])};
  static const double topMetaGap = ${_double(pickupTop['metaGap'])};
  static const double topMetaSize = ${_double(pickupTop['metaSize'])};
  static const double topMetaWeight = ${_double(pickupTop['metaWeight'])};

  static const double contentPaddingTop = ${_double(pickupContent['paddingTop'])};
  static const double contentPaddingHorizontal = ${_double(pickupContent['paddingHorizontal'])};
  static const double compactContentPaddingHorizontal = ${_double(pickupContent['compactPaddingHorizontal'])};
  static const double contentPaddingBottom = ${_double(pickupContent['paddingBottom'])};
  static const double heroPaddingBottom = ${_double(pickupContent['heroPaddingBottom'])};
  static const double heroColumnGap = ${_double(pickupContent['heroColumnGap'])};
  static const double heroTitleSize = ${_double(pickupContent['heroTitleSize'])};
  static const double compactHeroTitleSize = ${_double(pickupContent['compactHeroTitleSize'])};
  static const double heroTitleHeight = ${_double(pickupContent['heroTitleHeight'])};
  static const double heroTitleWeight = ${_double(pickupContent['heroTitleWeight'])};
  static const double heroTitleTracking = ${_double(pickupContent['heroTitleTracking'])};
  static const double progressSize = ${_double(pickupContent['progressSize'])};
  static const double compactProgressSize = ${_double(pickupContent['compactProgressSize'])};
  static const double progressHeight = ${_double(pickupContent['progressHeight'])};
  static const double progressWeight = ${_double(pickupContent['progressWeight'])};
  static const double progressTracking = ${_double(pickupContent['progressTracking'])};
  static const double progressLabelGap = ${_double(pickupContent['progressLabelGap'])};
  static const double progressLabelSize = ${_double(pickupContent['progressLabelSize'])};
  static const double progressLabelWeight = ${_double(pickupContent['progressLabelWeight'])};
  static const double summaryGap = ${_double(pickupContent['summaryGap'])};
  static const double summarySize = ${_double(pickupContent['summarySize'])};
  static const double summaryWeight = ${_double(pickupContent['summaryWeight'])};
  static const double summaryStrongWeight = ${_double(pickupContent['summaryStrongWeight'])};

  static const double manifestMarginTop = ${_double(pickupManifest['marginTop'])};
  static const double manifestRadius = ${_double(pickupManifest['radius'])};
  static const double manifestBorderWidth = ${_double(pickupManifest['borderWidth'])};
  static const double manifestHeadHeight = ${_double(pickupManifest['headHeight'])};
  static const double manifestHeadPaddingHorizontal = ${_double(pickupManifest['headPaddingHorizontal'])};
  static const double manifestHeadColumnGap = ${_double(pickupManifest['headColumnGap'])};
  static const double manifestHeadTitleSize = ${_double(pickupManifest['headTitleSize'])};
  static const double manifestHeadTitleWeight = ${_double(pickupManifest['headTitleWeight'])};
  static const double manifestHeadMetaSize = ${_double(pickupManifest['headMetaSize'])};
  static const double manifestHeadMetaWeight = ${_double(pickupManifest['headMetaWeight'])};
  static const double manifestLineHeight = ${_double(pickupManifest['lineHeight'])};
  static const double compactManifestLineHeight = ${_double(pickupManifest['compactLineHeight'])};
  static const double manifestLinePaddingHorizontal = ${_double(pickupManifest['linePaddingHorizontal'])};
  static const double compactManifestLinePaddingHorizontal = ${_double(pickupManifest['compactLinePaddingHorizontal'])};
  static const double manifestLinePaddingVertical = ${_double(pickupManifest['linePaddingVertical'])};
  static const double manifestLineColumnGap = ${_double(pickupManifest['lineColumnGap'])};
  static const double compactManifestLineColumnGap = ${_double(pickupManifest['compactLineColumnGap'])};
  static const double manifestCheckSize = ${_double(pickupManifest['checkSize'])};
  static const double manifestCheckRadius = ${_double(pickupManifest['checkRadius'])};
  static const double manifestCheckBorderWidth = ${_double(pickupManifest['checkBorderWidth'])};
  static const double manifestCheckIconSize = ${_double(pickupManifest['checkIconSize'])};
  static const double manifestTitleSize = ${_double(pickupManifest['lineTitleSize'])};
  static const double compactManifestTitleSize = ${_double(pickupManifest['compactLineTitleSize'])};
  static const double manifestTitleHeight = ${_double(pickupManifest['lineTitleHeight'])};
  static const double manifestTitleWeight = ${_double(pickupManifest['lineTitleWeight'])};
  static const double manifestTitleTracking = ${_double(pickupManifest['lineTitleTracking'])};
  static const double manifestMetaGap = ${_double(pickupManifest['lineMetaGap'])};
  static const double manifestMetaSize = ${_double(pickupManifest['lineMetaSize'])};
  static const double compactManifestMetaSize = ${_double(pickupManifest['compactLineMetaSize'])};
  static const double manifestMetaHeight = ${_double(pickupManifest['lineMetaHeight'])};
  static const double manifestSideMinWidth = ${_double(pickupManifest['lineSideMinWidth'])};
  static const double manifestQuantitySize = ${_double(pickupManifest['quantitySize'])};
  static const double manifestQuantityWeight = ${_double(pickupManifest['quantityWeight'])};
  static const double manifestCareGap = ${_double(pickupManifest['careGap'])};
  static const double manifestCareSize = ${_double(pickupManifest['careSize'])};
  static const double manifestCareWeight = ${_double(pickupManifest['careWeight'])};

  static const double problemHeight = ${_double(pickupProblem['height'])};
  static const double problemMarginTop = ${_double(pickupProblem['marginTop'])};
  static const double problemRadius = ${_double(pickupProblem['radius'])};
  static const double problemPaddingHorizontal = ${_double(pickupProblem['paddingHorizontal'])};
  static const double problemSize = ${_double(pickupProblem['size'])};
  static const double problemWeight = ${_double(pickupProblem['weight'])};
  static const double problemIconSize = ${_double(pickupProblem['iconSize'])};

  static const double footerHeight = ${_double(pickupFooter['height'])};
  static const double footerPaddingTop = ${_double(pickupFooter['paddingTop'])};
  static const double footerPaddingHorizontal = ${_double(pickupFooter['paddingHorizontal'])};
  static const double compactFooterPaddingHorizontal = ${_double(pickupFooter['compactPaddingHorizontal'])};
  static const double footerPaddingBottom = ${_double(pickupFooter['paddingBottom'])};
  static const double primaryHeight = ${_double(pickupFooter['primaryHeight'])};
  static const double primaryRadius = ${_double(pickupFooter['primaryRadius'])};
  static const double primarySize = ${_double(pickupFooter['primarySize'])};
  static const double primaryWeight = ${_double(pickupFooter['primaryWeight'])};
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

abstract final class DriverF08Metrics {
  static const String source = '${f08['source']}';

  static const double completeBarHeight = ${_double(f08Complete['height'])};
  static const double compactCompleteBarHeight = ${_double(f08Complete['compactHeight'])};
  static const double completeBarPaddingHorizontal = ${_double(f08Complete['paddingHorizontal'])};
  static const double completeIconSize = ${_double(f08Complete['iconSize'])};
  static const double completeColumnGap = ${_double(f08Complete['columnGap'])};
  static const double completeTitleSize = ${_double(f08Complete['titleSize'])};
  static const double completeDetailGap = ${_double(f08Complete['detailGap'])};
  static const double completeDetailSize = ${_double(f08Complete['detailSize'])};

  static const double dockHeight = ${_double(f08Dock['height'])};
  static const double compactDockHeight = ${_double(f08Dock['compactHeight'])};
  static const double dockPaddingHorizontal = ${_double(f08Dock['paddingHorizontal'])};
  static const double dockPaddingTop = ${_double(f08Dock['paddingTop'])};
  static const double dockPaddingBottom = ${_double(f08Dock['paddingBottom'])};
  static const double kickerSize = ${_double(f08Dock['kickerSize'])};
  static const double nameGap = ${_double(f08Dock['nameGap'])};
  static const double nameSize = ${_double(f08Dock['nameSize'])};
  static const double placeGap = ${_double(f08Dock['placeGap'])};
  static const double placeSize = ${_double(f08Dock['placeSize'])};
  static const double primaryHeight = ${_double(f08Dock['primaryHeight'])};
  static const double primaryMarginTop = ${_double(f08Dock['primaryMarginTop'])};
  static const double primaryRadius = ${_double(f08Dock['primaryRadius'])};
  static const double primarySize = ${_double(f08Dock['primarySize'])};
  static const double remainingHeight = ${_double(f08Dock['remainingHeight'])};
  static const double remainingMarginTop = ${_double(f08Dock['remainingMarginTop'])};
}

abstract final class DriverI01Metrics {
  static const String source = '${i01['source']}';

  static const double topBarHeight = ${_double(i01Top['height'])};
  static const double topBarPaddingHorizontal = ${_double(i01Top['paddingHorizontal'])};
  static const double brandSize = ${_double(i01Top['brandSize'])};
  static const double heroPaddingHorizontal = ${_double(i01Hero['paddingHorizontal'])};
  static const double heroPaddingTop = ${_double(i01Hero['paddingTop'])};
  static const double heroPaddingBottom = ${_double(i01Hero['paddingBottom'])};
  static const double heroStateSize = ${_double(i01Hero['stateSize'])};
  static const double heroStateGap = ${_double(i01Hero['stateGap'])};
  static const double heroStateBottom = ${_double(i01Hero['stateBottom'])};
  static const double heroTitleSize = ${_double(i01Hero['titleSize'])};
  static const double heroTitleHeight = ${_double(i01Hero['titleHeight'])};
  static const double heroSubtitleTop = ${_double(i01Hero['subtitleTop'])};
  static const double heroSubtitleSize = ${_double(i01Hero['subtitleSize'])};
  static const double heroMetaTop = ${_double(i01Hero['metaTop'])};
  static const double heroMetaSize = ${_double(i01Hero['metaSize'])};
  static const double continuationPaddingHorizontal = ${_double(i01Continuation['paddingHorizontal'])};
  static const double continuationPaddingTop = ${_double(i01Continuation['paddingTop'])};
  static const double continuationSectionSize = ${_double(i01Continuation['sectionSize'])};
  static const double continuationSectionBottom = ${_double(i01Continuation['sectionBottom'])};
  static const double continuationStateSize = ${_double(i01Continuation['stateSize'])};
  static const double continuationStateBottom = ${_double(i01Continuation['stateBottom'])};
  static const double continuationMessageSize = ${_double(i01Continuation['messageSize'])};
  static const double footerPaddingHorizontal = ${_double(i01Footer['paddingHorizontal'])};
  static const double footerPaddingTop = ${_double(i01Footer['paddingTop'])};
  static const double footerPaddingBottom = ${_double(i01Footer['paddingBottom'])};
  static const double primaryHeight = ${_double(i01Footer['primaryHeight'])};
  static const double primaryRadius = ${_double(i01Footer['primaryRadius'])};
  static const double primarySize = ${_double(i01Footer['primarySize'])};
}
''';
}

String _double(Object? value) {
  final number = value as num;
  return number is int ? '${number.toDouble()}' : number.toString();
}
