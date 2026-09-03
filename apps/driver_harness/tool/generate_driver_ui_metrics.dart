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
  final d01 = screens['D01'] as Map<String, dynamic>;
  final d01Control = d01['roadControl'] as Map<String, dynamic>;
  final d01Instruction = d01['instruction'] as Map<String, dynamic>;
  final d01Dock = d01['pickupDock'] as Map<String, dynamic>;
  final d01Type = d01['typography'] as Map<String, dynamic>;
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
  final g01 = screens['G01'] as Map<String, dynamic>;
  final g01Top = g01['topBar'] as Map<String, dynamic>;
  final g01Content = g01['content'] as Map<String, dynamic>;
  final g01Recipient = g01['recipient'] as Map<String, dynamic>;
  final g01Ledger = g01['ledger'] as Map<String, dynamic>;
  final g01Footer = g01['footer'] as Map<String, dynamic>;
  final g01Sheet = g01['sheet'] as Map<String, dynamic>;
  final g02 = screens['G02'] as Map<String, dynamic>;
  final g02Top = g02['topBar'] as Map<String, dynamic>;
  final g02Content = g02['content'] as Map<String, dynamic>;
  final g02Choice = g02['choice'] as Map<String, dynamic>;
  final g02Footer = g02['footer'] as Map<String, dynamic>;
  final g02Sheet = g02['sheet'] as Map<String, dynamic>;
  final h03 = screens['H03'] as Map<String, dynamic>;
  final h03Top = h03['topBar'] as Map<String, dynamic>;
  final h03Context = h03['context'] as Map<String, dynamic>;
  final h03Connection = h03['connection'] as Map<String, dynamic>;
  final h03Ledger = h03['ledger'] as Map<String, dynamic>;
  final h03Footer = h03['footer'] as Map<String, dynamic>;
  final i01 = screens['I01'] as Map<String, dynamic>;
  final i01Top = i01['topBar'] as Map<String, dynamic>;
  final i01Hero = i01['hero'] as Map<String, dynamic>;
  final i01Continuation = i01['continuation'] as Map<String, dynamic>;
  final i01Footer = i01['footer'] as Map<String, dynamic>;
  final j01 = screens['J01'] as Map<String, dynamic>;
  final j01Top = j01['topBar'] as Map<String, dynamic>;
  final j01Body = j01['body'] as Map<String, dynamic>;
  final j01Header = j01['header'] as Map<String, dynamic>;
  final j01Active = j01['active'] as Map<String, dynamic>;
  final j01Completed = j01['completed'] as Map<String, dynamic>;
  final j01BottomNav = j01['bottomNav'] as Map<String, dynamic>;
  final j01Sheet = j01['sheet'] as Map<String, dynamic>;

  return '''// GENERATED CODE - DO NOT MODIFY BY HAND.
// Source: $_sourcePath

abstract final class DriverReferenceViewport {
  static const double width = ${_double(viewport['width'])};
  static const double height = ${_double(viewport['height'])};
  static const double compactBreakpoint = ${_double(viewport['compactBreakpoint'])};
}

abstract final class DriverD01Metrics {
  static const String source = '${d01['source']}';

  static const double roadControlSize = ${_double(d01Control['size'])};
  static const double compactRoadControlSize = ${_double(d01Control['compactSize'])};
  static const double roadControlRadius = ${_double(d01Control['radius'])};
  static const double roadControlIconSize = ${_double(d01Control['iconSize'])};
  static const double outerMargin = ${_double(d01Control['outerMargin'])};
  static const double compactOuterMargin = ${_double(d01Control['compactOuterMargin'])};
  static const double roadControlGap = ${_double(d01Control['gap'])};
  static const double compactRoadControlGap = ${_double(d01Control['compactGap'])};

  static const double instructionHeight = ${_double(d01Instruction['height'])};
  static const double compactInstructionHeight = ${_double(d01Instruction['compactHeight'])};
  static const double instructionRadius = ${_double(d01Instruction['radius'])};
  static const double instructionPaddingLeft = ${_double(d01Instruction['paddingLeft'])};
  static const double instructionPaddingRight = ${_double(d01Instruction['paddingRight'])};
  static const double compactInstructionPaddingLeft = ${_double(d01Instruction['compactPaddingLeft'])};
  static const double compactInstructionPaddingRight = ${_double(d01Instruction['compactPaddingRight'])};
  static const double instructionIconSize = ${_double(d01Instruction['iconSize'])};
  static const double compactInstructionIconSize = ${_double(d01Instruction['compactIconSize'])};
  static const double instructionIconRadius = ${_double(d01Instruction['iconRadius'])};
  static const double instructionColumnGap = ${_double(d01Instruction['columnGap'])};
  static const double compactInstructionColumnGap = ${_double(d01Instruction['compactColumnGap'])};
  static const double instructionDistanceSize = ${_double(d01Instruction['distanceSize'])};
  static const double compactInstructionDistanceSize = ${_double(d01Instruction['compactDistanceSize'])};
  static const double instructionDistanceWeight = ${_double(d01Instruction['distanceWeight'])};
  static const double instructionDistanceTracking = ${_double(d01Instruction['distanceTracking'])};
  static const double instructionUnitSize = ${_double(d01Instruction['unitSize'])};
  static const double instructionTextGap = ${_double(d01Instruction['textGap'])};
  static const double instructionTextSize = ${_double(d01Instruction['textSize'])};
  static const double compactInstructionTextSize = ${_double(d01Instruction['compactTextSize'])};
  static const double instructionTextHeight = ${_double(d01Instruction['textHeight'])};
  static const double instructionTextWeight = ${_double(d01Instruction['textWeight'])};

  static const double dockRowHeight = ${_double(d01Dock['rowHeight'])};
  static const double compactDockRowHeight = ${_double(d01Dock['compactRowHeight'])};
  static const double dockPaddingHorizontal = ${_double(d01Dock['paddingHorizontal'])};
  static const double dockPaddingVertical = ${_double(d01Dock['paddingVertical'])};
  static const double compactDockPadding = ${_double(d01Dock['compactPadding'])};
  static const double dockColumnGap = ${_double(d01Dock['columnGap'])};
  static const double dockRadius = ${_double(d01Dock['radius'])};
  static const double dockBorderWidth = ${_double(d01Dock['borderWidth'])};
  static const double dockTextGap = ${_double(d01Dock['textGap'])};
  static const double arrivalHeight = ${_double(d01Dock['arrivalHeight'])};
  static const double arrivalMarginHorizontal = ${_double(d01Dock['arrivalMarginHorizontal'])};
  static const double arrivalMarginBottom = ${_double(d01Dock['arrivalMarginBottom'])};

  static const double kickerSize = ${_double(d01Type['kickerSize'])};
  static const double kickerHeight = ${_double(d01Type['kickerHeight'])};
  static const double kickerWeight = ${_double(d01Type['kickerWeight'])};
  static const double kickerTracking = ${_double(d01Type['kickerTracking'])};
  static const double titleSize = ${_double(d01Type['titleSize'])};
  static const double compactTitleSize = ${_double(d01Type['compactTitleSize'])};
  static const double titleHeight = ${_double(d01Type['titleHeight'])};
  static const double titleWeight = ${_double(d01Type['titleWeight'])};
  static const double titleTracking = ${_double(d01Type['titleTracking'])};
  static const double placeSize = ${_double(d01Type['placeSize'])};
  static const double placeHeight = ${_double(d01Type['placeHeight'])};
  static const double placeWeight = ${_double(d01Type['placeWeight'])};
  static const double etaSize = ${_double(d01Type['etaSize'])};
  static const double compactEtaSize = ${_double(d01Type['compactEtaSize'])};
  static const double etaHeight = ${_double(d01Type['etaHeight'])};
  static const double etaWeight = ${_double(d01Type['etaWeight'])};
  static const double etaTracking = ${_double(d01Type['etaTracking'])};
  static const double distanceSize = ${_double(d01Type['distanceSize'])};
  static const double distanceHeight = ${_double(d01Type['distanceHeight'])};
  static const double distanceWeight = ${_double(d01Type['distanceWeight'])};
  static const double arrivalSize = ${_double(d01Type['arrivalSize'])};
  static const double arrivalWeight = ${_double(d01Type['arrivalWeight'])};
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

abstract final class DriverG01Metrics {
  static const String source = '${g01['source']}';

  static const double topBarHeight = ${_double(g01Top['height'])};
  static const double topBarPaddingHorizontal = ${_double(g01Top['paddingHorizontal'])};
  static const double topButtonSize = ${_double(g01Top['buttonSize'])};
  static const double topColumnGap = ${_double(g01Top['columnGap'])};
  static const double topEyebrowSize = ${_double(g01Top['eyebrowSize'])};
  static const double topEyebrowTracking = ${_double(g01Top['eyebrowTracking'])};
  static const double topTitleGap = ${_double(g01Top['titleGap'])};
  static const double topTitleSize = ${_double(g01Top['titleSize'])};
  static const double topIconSize = ${_double(g01Top['iconSize'])};

  static const double contentPaddingTop = ${_double(g01Content['paddingTop'])};
  static const double contentPaddingHorizontal = ${_double(g01Content['paddingHorizontal'])};
  static const double contentPaddingBottom = ${_double(g01Content['paddingBottom'])};
  static const double issueDotSize = ${_double(g01Content['issueDotSize'])};
  static const double issueGap = ${_double(g01Content['issueGap'])};
  static const double issueSize = ${_double(g01Content['issueSize'])};
  static const double issueTracking = ${_double(g01Content['issueTracking'])};
  static const double heroGap = ${_double(g01Content['heroGap'])};
  static const double heroSize = ${_double(g01Content['heroSize'])};
  static const double heroHeight = ${_double(g01Content['heroHeight'])};
  static const double heroTracking = ${_double(g01Content['heroTracking'])};
  static const double locationGap = ${_double(g01Content['locationGap'])};
  static const double locationSize = ${_double(g01Content['locationSize'])};
  static const double locationHeight = ${_double(g01Content['locationHeight'])};
  static const double sectionGap = ${_double(g01Content['sectionGap'])};

  static const double recipientMarginTop = ${_double(g01Recipient['marginTop'])};
  static const double recipientPaddingTop = ${_double(g01Recipient['paddingTop'])};
  static const double recipientColumnGap = ${_double(g01Recipient['columnGap'])};
  static const double recipientEyebrowSize = ${_double(g01Recipient['eyebrowSize'])};
  static const double recipientEyebrowTracking = ${_double(g01Recipient['eyebrowTracking'])};
  static const double recipientEyebrowBottom = ${_double(g01Recipient['eyebrowBottom'])};
  static const double recipientNameSize = ${_double(g01Recipient['nameSize'])};
  static const double recipientNameHeight = ${_double(g01Recipient['nameHeight'])};
  static const double recipientNameTracking = ${_double(g01Recipient['nameTracking'])};
  static const double recipientNoteGap = ${_double(g01Recipient['noteGap'])};
  static const double recipientNoteSize = ${_double(g01Recipient['noteSize'])};
  static const double recipientNoteHeight = ${_double(g01Recipient['noteHeight'])};
  static const double itemPaddingTop = ${_double(g01Recipient['itemPaddingTop'])};
  static const double itemDotSize = ${_double(g01Recipient['itemDotSize'])};
  static const double itemDotGap = ${_double(g01Recipient['itemDotGap'])};
  static const double itemSize = ${_double(g01Recipient['itemSize'])};

  static const double ledgerTitleSize = ${_double(g01Ledger['titleSize'])};
  static const double ledgerTitleTracking = ${_double(g01Ledger['titleTracking'])};
  static const double ledgerTitleBottom = ${_double(g01Ledger['titleBottom'])};
  static const double ledgerEmptyHeight = ${_double(g01Ledger['emptyHeight'])};
  static const double ledgerRowHeight = ${_double(g01Ledger['rowHeight'])};
  static const double ledgerTimeColumnWidth = ${_double(g01Ledger['timeColumnWidth'])};
  static const double ledgerTimeSize = ${_double(g01Ledger['timeSize'])};
  static const double ledgerRowTitleSize = ${_double(g01Ledger['titleSizeRow'])};
  static const double ledgerOutcomeSize = ${_double(g01Ledger['outcomeSize'])};

  static const double footerPaddingTop = ${_double(g01Footer['paddingTop'])};
  static const double footerPaddingHorizontal = ${_double(g01Footer['paddingHorizontal'])};
  static const double footerPaddingBottom = ${_double(g01Footer['paddingBottom'])};
  static const double primaryHeight = ${_double(g01Footer['primaryHeight'])};
  static const double primaryRadius = ${_double(g01Footer['primaryRadius'])};
  static const double secondaryHeight = ${_double(g01Footer['secondaryHeight'])};
  static const double secondaryGap = ${_double(g01Footer['secondaryGap'])};

  static const double sheetRadius = ${_double(g01Sheet['radius'])};
  static const double sheetPaddingTop = ${_double(g01Sheet['paddingTop'])};
  static const double sheetPaddingHorizontal = ${_double(g01Sheet['paddingHorizontal'])};
  static const double sheetPaddingBottom = ${_double(g01Sheet['paddingBottom'])};
  static const double sheetHandleWidth = ${_double(g01Sheet['handleWidth'])};
  static const double sheetHandleHeight = ${_double(g01Sheet['handleHeight'])};
  static const double sheetHandleBottom = ${_double(g01Sheet['handleBottom'])};
  static const double sheetTitleSize = ${_double(g01Sheet['titleSize'])};
  static const double sheetTitleBottom = ${_double(g01Sheet['titleBottom'])};
  static const double sheetRowHeight = ${_double(g01Sheet['rowHeight'])};
  static const double sheetRowPaddingHorizontal = ${_double(g01Sheet['rowPaddingHorizontal'])};
  static const double sheetRowSize = ${_double(g01Sheet['rowSize'])};
  static const double sheetDetailSize = ${_double(g01Sheet['detailSize'])};
}

abstract final class DriverG02Metrics {
  static const String source = '${g02['source']}';

  static const double topBarHeight = ${_double(g02Top['height'])};
  static const double topBarPaddingHorizontal = ${_double(g02Top['paddingHorizontal'])};
  static const double topButtonSize = ${_double(g02Top['buttonSize'])};
  static const double topColumnGap = ${_double(g02Top['columnGap'])};
  static const double topButtonRadius = ${_double(g02Top['buttonRadius'])};
  static const double topIconSize = ${_double(g02Top['iconSize'])};
  static const double topKickerSize = ${_double(g02Top['kickerSize'])};
  static const double topKickerWeight = ${_double(g02Top['kickerWeight'])};
  static const double topKickerTracking = ${_double(g02Top['kickerTracking'])};
  static const double topTitleGap = ${_double(g02Top['titleGap'])};
  static const double topTitleSize = ${_double(g02Top['titleSize'])};
  static const double topTitleWeight = ${_double(g02Top['titleWeight'])};
  static const double topTitleTracking = ${_double(g02Top['titleTracking'])};

  static const double contentPaddingTop = ${_double(g02Content['paddingTop'])};
  static const double contentPaddingHorizontal = ${_double(g02Content['paddingHorizontal'])};
  static const double compactContentPaddingTop = ${_double(g02Content['compactPaddingTop'])};
  static const double compactContentPaddingHorizontal = ${_double(g02Content['compactPaddingHorizontal'])};
  static const double contentPaddingBottom = ${_double(g02Content['paddingBottom'])};
  static const double footerReserve = ${_double(g02Content['footerReserve'])};
  static const double compactFooterReserve = ${_double(g02Content['compactFooterReserve'])};
  static const double issueSize = ${_double(g02Content['issueSize'])};
  static const double issueWeight = ${_double(g02Content['issueWeight'])};
  static const double issueTracking = ${_double(g02Content['issueTracking'])};
  static const double issueDotSize = ${_double(g02Content['issueDotSize'])};
  static const double heroGap = ${_double(g02Content['heroGap'])};
  static const double heroSize = ${_double(g02Content['heroSize'])};
  static const double compactHeroSize = ${_double(g02Content['compactHeroSize'])};
  static const double heroHeight = ${_double(g02Content['heroHeight'])};
  static const double heroWeight = ${_double(g02Content['heroWeight'])};
  static const double heroTracking = ${_double(g02Content['heroTracking'])};
  static const double locationGap = ${_double(g02Content['locationGap'])};
  static const double locationSize = ${_double(g02Content['locationSize'])};
  static const double locationHeight = ${_double(g02Content['locationHeight'])};
  static const double contextGap = ${_double(g02Content['contextGap'])};
  static const double contextPaddingTop = ${_double(g02Content['contextPaddingTop'])};
  static const double sectionGap = ${_double(g02Content['sectionGap'])};
  static const double compactSectionGap = ${_double(g02Content['compactSectionGap'])};

  static const double choiceHeight = ${_double(g02Choice['height'])};
  static const double compactChoiceHeight = ${_double(g02Choice['compactHeight'])};
  static const double choiceIconColumn = ${_double(g02Choice['iconColumn'])};
  static const double compactChoiceIconColumn = ${_double(g02Choice['compactIconColumn'])};
  static const double choiceColumnGap = ${_double(g02Choice['columnGap'])};
  static const double compactChoiceColumnGap = ${_double(g02Choice['compactColumnGap'])};
  static const double choiceIconSize = ${_double(g02Choice['iconSize'])};
  static const double compactChoiceIconSize = ${_double(g02Choice['compactIconSize'])};
  static const double choiceTitleSize = ${_double(g02Choice['titleSize'])};
  static const double compactChoiceTitleSize = ${_double(g02Choice['compactTitleSize'])};
  static const double choiceTitleHeight = ${_double(g02Choice['titleHeight'])};
  static const double choiceTitleWeight = ${_double(g02Choice['titleWeight'])};
  static const double choiceTitleTracking = ${_double(g02Choice['titleTracking'])};

  static const double footerPaddingTop = ${_double(g02Footer['paddingTop'])};
  static const double footerPaddingHorizontal = ${_double(g02Footer['paddingHorizontal'])};
  static const double compactFooterPaddingHorizontal = ${_double(g02Footer['compactPaddingHorizontal'])};
  static const double footerPaddingBottom = ${_double(g02Footer['paddingBottom'])};
  static const double primaryHeight = ${_double(g02Footer['primaryHeight'])};
  static const double compactPrimaryHeight = ${_double(g02Footer['compactPrimaryHeight'])};
  static const double primaryRadius = ${_double(g02Footer['primaryRadius'])};
  static const double primarySize = ${_double(g02Footer['primarySize'])};
  static const double primaryWeight = ${_double(g02Footer['primaryWeight'])};
  static const double secondaryHeight = ${_double(g02Footer['secondaryHeight'])};
  static const double compactSecondaryHeight = ${_double(g02Footer['compactSecondaryHeight'])};
  static const double secondarySize = ${_double(g02Footer['secondarySize'])};
  static const double secondaryWeight = ${_double(g02Footer['secondaryWeight'])};

  static const double sheetInset = ${_double(g02Sheet['inset'])};
  static const double compactSheetInset = ${_double(g02Sheet['compactInset'])};
  static const double sheetRadiusTop = ${_double(g02Sheet['radiusTop'])};
  static const double sheetRadiusBottom = ${_double(g02Sheet['radiusBottom'])};
  static const double sheetHandleHeight = ${_double(g02Sheet['handleHeight'])};
  static const double sheetHandleWidth = ${_double(g02Sheet['handleWidth'])};
  static const double sheetHandleThickness = ${_double(g02Sheet['handleThickness'])};
  static const double sheetHeadPaddingHorizontal = ${_double(g02Sheet['headPaddingHorizontal'])};
  static const double compactSheetHeadPaddingHorizontal = ${_double(g02Sheet['compactHeadPaddingHorizontal'])};
  static const double sheetHeadPaddingBottom = ${_double(g02Sheet['headPaddingBottom'])};
  static const double sheetTitleSize = ${_double(g02Sheet['titleSize'])};
  static const double compactSheetTitleSize = ${_double(g02Sheet['compactTitleSize'])};
  static const double sheetRowHeight = ${_double(g02Sheet['rowHeight'])};
  static const double compactSheetRowHeight = ${_double(g02Sheet['compactRowHeight'])};
  static const double sheetRowPaddingHorizontal = ${_double(g02Sheet['rowPaddingHorizontal'])};
  static const double compactSheetRowPaddingHorizontal = ${_double(g02Sheet['compactRowPaddingHorizontal'])};
  static const double sheetRowIconSize = ${_double(g02Sheet['rowIconSize'])};
  static const double sheetRowSize = ${_double(g02Sheet['rowSize'])};
  static const double compactSheetRowSize = ${_double(g02Sheet['compactRowSize'])};
  static const double sheetMapHeight = ${_double(g02Sheet['mapHeight'])};
  static const double compactSheetMapHeight = ${_double(g02Sheet['compactMapHeight'])};
}

abstract final class DriverH03Metrics {
  static const String source = '${h03['source']}';

  static const double topBarHeight = ${_double(h03Top['height'])};
  static const double topBarPaddingHorizontal = ${_double(h03Top['paddingHorizontal'])};
  static const double topButtonSize = ${_double(h03Top['buttonSize'])};
  static const double topColumnGap = ${_double(h03Top['columnGap'])};
  static const double topIconSize = ${_double(h03Top['iconSize'])};
  static const double topTitleSize = ${_double(h03Top['titleSize'])};
  static const double topStatusGap = ${_double(h03Top['statusGap'])};
  static const double topStatusSize = ${_double(h03Top['statusSize'])};
  static const double topStatusDotSize = ${_double(h03Top['statusDotSize'])};
  static const double topStatusDotGap = ${_double(h03Top['statusDotGap'])};

  static const double contextHeight = ${_double(h03Context['height'])};
  static const double contextPaddingHorizontal = ${_double(h03Context['paddingHorizontal'])};
  static const double contextColumnGap = ${_double(h03Context['columnGap'])};
  static const double contextKickerSize = ${_double(h03Context['kickerSize'])};
  static const double contextKickerTracking = ${_double(h03Context['kickerTracking'])};
  static const double contextNameGap = ${_double(h03Context['nameGap'])};
  static const double contextNameSize = ${_double(h03Context['nameSize'])};
  static const double contextMetaGap = ${_double(h03Context['metaGap'])};
  static const double contextMetaSize = ${_double(h03Context['metaSize'])};
  static const double contextActionHeight = ${_double(h03Context['actionHeight'])};
  static const double contextActionSize = ${_double(h03Context['actionSize'])};

  static const double connectionPaddingVertical = ${_double(h03Connection['paddingVertical'])};
  static const double connectionPaddingHorizontal = ${_double(h03Connection['paddingHorizontal'])};
  static const double connectionSize = ${_double(h03Connection['size'])};
  static const double connectionHeight = ${_double(h03Connection['height'])};

  static const double ledgerPaddingTop = ${_double(h03Ledger['paddingTop'])};
  static const double ledgerPaddingHorizontal = ${_double(h03Ledger['paddingHorizontal'])};
  static const double ledgerPaddingBottom = ${_double(h03Ledger['paddingBottom'])};
  static const double daySize = ${_double(h03Ledger['daySize'])};
  static const double dayTracking = ${_double(h03Ledger['dayTracking'])};
  static const double dayBottom = ${_double(h03Ledger['dayBottom'])};
  static const double timelineLeft = ${_double(h03Ledger['timelineLeft'])};
  static const double timeColumnWidth = ${_double(h03Ledger['timeColumnWidth'])};
  static const double dotColumnWidth = ${_double(h03Ledger['dotColumnWidth'])};
  static const double eventColumnGap = ${_double(h03Ledger['columnGap'])};
  static const double eventMinHeight = ${_double(h03Ledger['eventMinHeight'])};
  static const double eventBottom = ${_double(h03Ledger['eventBottom'])};
  static const double timePaddingTop = ${_double(h03Ledger['timePaddingTop'])};
  static const double timeSize = ${_double(h03Ledger['timeSize'])};
  static const double dotSize = ${_double(h03Ledger['dotSize'])};
  static const double dotPaddingTop = ${_double(h03Ledger['dotPaddingTop'])};
  static const double eventTitleSize = ${_double(h03Ledger['titleSize'])};
  static const double eventTitleHeight = ${_double(h03Ledger['titleHeight'])};
  static const double detailGap = ${_double(h03Ledger['detailGap'])};
  static const double detailSize = ${_double(h03Ledger['detailSize'])};
  static const double detailHeight = ${_double(h03Ledger['detailHeight'])};
  static const double humanSize = ${_double(h03Ledger['humanSize'])};
  static const double humanHeight = ${_double(h03Ledger['humanHeight'])};

  static const double footerPaddingTop = ${_double(h03Footer['paddingTop'])};
  static const double footerPaddingHorizontal = ${_double(h03Footer['paddingHorizontal'])};
  static const double footerPaddingBottom = ${_double(h03Footer['paddingBottom'])};
  static const double primaryHeight = ${_double(h03Footer['primaryHeight'])};
  static const double primaryRadius = ${_double(h03Footer['primaryRadius'])};
  static const double primarySize = ${_double(h03Footer['primarySize'])};
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

abstract final class DriverJ01Metrics {
  static const String source = '${j01['source']}';

  static const double topBarHeight = ${_double(j01Top['height'])};
  static const double topBarPaddingHorizontal = ${_double(j01Top['paddingHorizontal'])};
  static const double brandSize = ${_double(j01Top['brandSize'])};
  static const double topButtonSize = ${_double(j01Top['buttonSize'])};
  static const double topIconSize = ${_double(j01Top['iconSize'])};
  static const double bottomNavHeight = ${_double(j01Body['bottomNavHeight'])};
  static const double headerPaddingTop = ${_double(j01Header['paddingTop'])};
  static const double headerPaddingHorizontal = ${_double(j01Header['paddingHorizontal'])};
  static const double headerPaddingBottom = ${_double(j01Header['paddingBottom'])};
  static const double eyebrowSize = ${_double(j01Header['eyebrowSize'])};
  static const double eyebrowBottom = ${_double(j01Header['eyebrowBottom'])};
  static const double titleSize = ${_double(j01Header['titleSize'])};
  static const double activePaddingTop = ${_double(j01Active['paddingTop'])};
  static const double activePaddingHorizontal = ${_double(j01Active['paddingHorizontal'])};
  static const double activePaddingBottom = ${_double(j01Active['paddingBottom'])};
  static const double activeBorderLeft = ${_double(j01Active['borderLeft'])};
  static const double activeKickerSize = ${_double(j01Active['kickerSize'])};
  static const double activeKickerBottom = ${_double(j01Active['kickerBottom'])};
  static const double activeMerchantSize = ${_double(j01Active['merchantSize'])};
  static const double activeMerchantBottom = ${_double(j01Active['merchantBottom'])};
  static const double activeTitleSize = ${_double(j01Active['titleSize'])};
  static const double activeNextTop = ${_double(j01Active['nextTop'])};
  static const double activeNextSize = ${_double(j01Active['nextSize'])};
  static const double activeSideSize = ${_double(j01Active['sideSize'])};
  static const double activeSideLabelTop = ${_double(j01Active['sideLabelTop'])};
  static const double activeSideLabelSize = ${_double(j01Active['sideLabelSize'])};
  static const double activeMetaTop = ${_double(j01Active['metaTop'])};
  static const double activeMetaSize = ${_double(j01Active['metaSize'])};
  static const double activeButtonTop = ${_double(j01Active['buttonTop'])};
  static const double activeButtonHeight = ${_double(j01Active['buttonHeight'])};
  static const double activeButtonRadius = ${_double(j01Active['buttonRadius'])};
  static const double activeButtonSize = ${_double(j01Active['buttonSize'])};
  static const double completedPaddingTop = ${_double(j01Completed['paddingTop'])};
  static const double completedPaddingHorizontal = ${_double(j01Completed['paddingHorizontal'])};
  static const double completedPaddingBottom = ${_double(j01Completed['paddingBottom'])};
  static const double completedSectionSize = ${_double(j01Completed['sectionSize'])};
  static const double completedSectionCountSize = ${_double(j01Completed['sectionCountSize'])};
  static const double completedSectionBottom = ${_double(j01Completed['sectionBottom'])};
  static const double completedRowMinHeight = ${_double(j01Completed['rowMinHeight'])};
  static const double completedRowPaddingVertical = ${_double(j01Completed['rowPaddingVertical'])};
  static const double completedRowTitleSize = ${_double(j01Completed['rowTitleSize'])};
  static const double completedKindSize = ${_double(j01Completed['kindSize'])};
  static const double completedSubTop = ${_double(j01Completed['subTop'])};
  static const double completedSubSize = ${_double(j01Completed['subSize'])};
  static const double completedProofTop = ${_double(j01Completed['proofTop'])};
  static const double completedProofSize = ${_double(j01Completed['proofSize'])};
  static const double completedProofDotSize = ${_double(j01Completed['proofDotSize'])};
  static const double completedSideSize = ${_double(j01Completed['sideSize'])};
  static const double completedSideMetaTop = ${_double(j01Completed['sideMetaTop'])};
  static const double completedSideMetaSize = ${_double(j01Completed['sideMetaSize'])};
  static const double bottomNavPaddingTop = ${_double(j01BottomNav['paddingTop'])};
  static const double bottomNavPaddingHorizontal = ${_double(j01BottomNav['paddingHorizontal'])};
  static const double bottomNavPaddingBottom = ${_double(j01BottomNav['paddingBottom'])};
  static const double bottomNavIconSize = ${_double(j01BottomNav['iconSize'])};
  static const double bottomNavLabelSize = ${_double(j01BottomNav['labelSize'])};
  static const double bottomNavGap = ${_double(j01BottomNav['gap'])};
  static const double sheetPaddingTop = ${_double(j01Sheet['paddingTop'])};
  static const double sheetPaddingHorizontal = ${_double(j01Sheet['paddingHorizontal'])};
  static const double sheetPaddingBottom = ${_double(j01Sheet['paddingBottom'])};
  static const double sheetRadius = ${_double(j01Sheet['radius'])};
  static const double sheetGrabWidth = ${_double(j01Sheet['grabWidth'])};
  static const double sheetGrabHeight = ${_double(j01Sheet['grabHeight'])};
  static const double sheetGrabBottom = ${_double(j01Sheet['grabBottom'])};
  static const double sheetKickerSize = ${_double(j01Sheet['kickerSize'])};
  static const double sheetKickerBottom = ${_double(j01Sheet['kickerBottom'])};
  static const double sheetTitleSize = ${_double(j01Sheet['titleSize'])};
  static const double sheetSubTop = ${_double(j01Sheet['subTop'])};
  static const double sheetSubSize = ${_double(j01Sheet['subSize'])};
  static const double sheetEvidenceTop = ${_double(j01Sheet['evidenceTop'])};
  static const double sheetRowHeight = ${_double(j01Sheet['rowHeight'])};
  static const double sheetRowLabelSize = ${_double(j01Sheet['rowLabelSize'])};
  static const double sheetRowValueSize = ${_double(j01Sheet['rowValueSize'])};
  static const double sheetButtonTop = ${_double(j01Sheet['buttonTop'])};
  static const double sheetButtonHeight = ${_double(j01Sheet['buttonHeight'])};
  static const double sheetButtonRadius = ${_double(j01Sheet['buttonRadius'])};
  static const double sheetButtonSize = ${_double(j01Sheet['buttonSize'])};
}
''';
}

String _double(Object? value) {
  final number = value as num;
  return number is int ? '${number.toDouble()}' : number.toString();
}
