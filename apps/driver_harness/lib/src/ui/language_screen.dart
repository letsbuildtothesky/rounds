import 'package:flutter/material.dart';

import '../app/app_strings.dart';
import '../app/driver_design_system.dart';
import '../app/generated/driver_ui_metrics.g.dart';
import '../app/harness_app_controller.dart';

class LanguageScreen extends StatefulWidget {
  const LanguageScreen({required this.controller, super.key});

  final HarnessAppController controller;

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  late HarnessLocale _selection = widget.controller.locale;

  @override
  Widget build(BuildContext context) {
    final compact =
        MediaQuery.sizeOf(context).width <=
        DriverReferenceViewport.compactBreakpoint;
    final thai = _selection == HarnessLocale.thai;
    final strings = AppStrings(_selection);
    final horizontal = compact
        ? DriverA01BMetrics.compactContentPaddingHorizontal
        : DriverA01BMetrics.contentPaddingHorizontal;
    final top = thai
        ? compact
              ? DriverA01BMetrics.thaiCompactContentPaddingTop
              : DriverA01BMetrics.thaiContentPaddingTop
        : compact
        ? DriverA01BMetrics.englishCompactContentPaddingTop
        : DriverA01BMetrics.englishContentPaddingTop;
    final bottom = compact
        ? DriverA01BMetrics.compactContentPaddingBottom
        : DriverA01BMetrics.contentPaddingBottom;

    return Scaffold(
      backgroundColor: RoundsColors.surface,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                const _LanguageTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    key: const Key('a01b-body'),
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      top,
                      horizontal,
                      bottom,
                    ),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.languageEyebrow,
                            key: const Key('a01b-eyebrow'),
                            style: TextStyle(
                              color: RoundsColors.orange,
                              fontSize: thai
                                  ? DriverA01BMetrics.thaiEyebrowSize
                                  : DriverA01BMetrics.englishEyebrowSize,
                              height: thai
                                  ? DriverA01BMetrics.thaiEyebrowHeight
                                  : DriverA01BMetrics.englishEyebrowHeight,
                              fontWeight: thai
                                  ? FontWeight.w800
                                  : FontWeight.w900,
                              letterSpacing: thai
                                  ? DriverA01BMetrics.thaiEyebrowTracking
                                  : DriverA01BMetrics.englishEyebrowTracking,
                            ),
                          ),
                          SizedBox(
                            height: thai
                                ? DriverA01BMetrics.thaiEyebrowGap
                                : DriverA01BMetrics.englishEyebrowGap,
                          ),
                          Text(
                            strings.languageTitle,
                            key: const Key('a01b-title'),
                            style: TextStyle(
                              color: RoundsColors.ink,
                              fontSize: thai
                                  ? compact
                                        ? DriverA01BMetrics.thaiCompactTitleSize
                                        : DriverA01BMetrics.thaiTitleSize
                                  : compact
                                  ? DriverA01BMetrics.englishCompactTitleSize
                                  : DriverA01BMetrics.englishTitleSize,
                              height: thai
                                  ? DriverA01BMetrics.thaiTitleHeight
                                  : DriverA01BMetrics.englishTitleHeight,
                              fontWeight: thai
                                  ? FontWeight.w800
                                  : FontWeight.w900,
                              letterSpacing: thai
                                  ? DriverA01BMetrics.thaiTitleTracking
                                  : DriverA01BMetrics.englishTitleTracking,
                            ),
                          ),
                          SizedBox(
                            height: thai
                                ? DriverA01BMetrics.thaiLeadGap
                                : DriverA01BMetrics.englishLeadGap,
                          ),
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: thai
                                  ? DriverA01BMetrics.thaiLeadMaxWidth
                                  : DriverA01BMetrics.englishLeadMaxWidth,
                            ),
                            child: Text(
                              strings.languageLead,
                              key: const Key('a01b-lead'),
                              style: TextStyle(
                                color: RoundsColors.muted,
                                fontSize: DriverA01BMetrics.leadSize,
                                height: thai
                                    ? DriverA01BMetrics.thaiLeadHeight
                                    : DriverA01BMetrics.englishLeadHeight,
                                fontWeight: thai
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(
                            height: thai
                                ? compact
                                      ? DriverA01BMetrics
                                            .thaiCompactListMarginTop
                                      : DriverA01BMetrics.thaiListMarginTop
                                : compact
                                ? DriverA01BMetrics.englishCompactListMarginTop
                                : DriverA01BMetrics.englishListMarginTop,
                          ),
                          Container(
                            key: const Key('a01b-language-list'),
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(
                                  color: RoundsColors.line,
                                  width: DriverA01BMetrics.listBorderWidth,
                                ),
                              ),
                            ),
                            child: Column(
                              children: [
                                _LanguageChoice(
                                  key: const Key('a01b-english'),
                                  locale: HarnessLocale.english,
                                  title: strings.english,
                                  subtitle: strings.englishLanguageDescription,
                                  selected: _selection == HarnessLocale.english,
                                  compact: compact,
                                  thaiTypography: thai,
                                  onTap: () => setState(
                                    () => _selection = HarnessLocale.english,
                                  ),
                                ),
                                _LanguageChoice(
                                  key: const Key('a01b-thai'),
                                  locale: HarnessLocale.thai,
                                  title: strings.thai,
                                  subtitle: strings.thaiLanguageDescription,
                                  selected: _selection == HarnessLocale.thai,
                                  compact: compact,
                                  thaiTypography: thai,
                                  onTap: () => setState(
                                    () => _selection = HarnessLocale.thai,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _LanguageFooter(
                compact: compact,
                thai: thai,
                label: strings.languageContinueAction,
                onContinue: () => widget.controller.selectLocale(_selection),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LanguageTopBar extends StatelessWidget {
  const _LanguageTopBar();

  @override
  Widget build(BuildContext context) => SizedBox(
    key: const Key('a01b-topbar'),
    height: DriverA01BMetrics.topBarHeight,
    child: Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: DriverA01BMetrics.topBarPaddingHorizontal,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text(
              'Rounds',
              style: TextStyle(
                color: RoundsColors.ink,
                fontSize: DriverA01BMetrics.brandSize,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: DriverA01BMetrics.brandTracking,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(
                left: DriverA01BMetrics.brandDotMarginLeft,
                bottom: DriverA01BMetrics.brandDotMarginBottom,
              ),
              child: Container(
                width: DriverA01BMetrics.brandDotSize,
                height: DriverA01BMetrics.brandDotSize,
                decoration: const BoxDecoration(
                  color: RoundsColors.orange,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice({
    required this.locale,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.compact,
    required this.thaiTypography,
    required this.onTap,
    super.key,
  });

  final HarnessLocale locale;
  final String title;
  final String subtitle;
  final bool selected;
  final bool compact;
  final bool thaiTypography;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final height = compact
        ? thaiTypography
              ? DriverA01BMetrics.thaiCompactRowHeight
              : DriverA01BMetrics.englishCompactRowHeight
        : DriverA01BMetrics.rowHeight;
    return Semantics(
      selected: selected,
      button: true,
      label: title,
      child: Material(
        color: RoundsColors.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: height),
            padding: const EdgeInsets.only(
              right: DriverA01BMetrics.rowRightPadding,
            ),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: RoundsColors.line,
                  width: DriverA01BMetrics.listBorderWidth,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  key: Key('a01b-${locale.storageValue}-edge'),
                  width: DriverA01BMetrics.edgeWidth,
                  height: DriverA01BMetrics.edgeHeight,
                  color: selected ? RoundsColors.orange : Colors.transparent,
                ),
                const SizedBox(width: DriverA01BMetrics.rowColumnGap),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: RoundsColors.ink,
                          fontSize: DriverA01BMetrics.languageTitleSize,
                          height: thaiTypography
                              ? DriverA01BMetrics.thaiLanguageTitleHeight
                              : DriverA01BMetrics.englishLanguageTitleHeight,
                          fontWeight: thaiTypography
                              ? FontWeight.w800
                              : FontWeight.w900,
                          letterSpacing: thaiTypography
                              ? DriverA01BMetrics.thaiLanguageTitleTracking
                              : DriverA01BMetrics.englishLanguageTitleTracking,
                        ),
                      ),
                      SizedBox(
                        height: thaiTypography
                            ? DriverA01BMetrics.thaiSubtitleGap
                            : DriverA01BMetrics.englishSubtitleGap,
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: RoundsColors.muted,
                          fontSize: DriverA01BMetrics.subtitleSize,
                          height: thaiTypography
                              ? DriverA01BMetrics.thaiSubtitleHeight
                              : DriverA01BMetrics.englishSubtitleHeight,
                          fontWeight: thaiTypography
                              ? FontWeight.w500
                              : FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: DriverA01BMetrics.markColumnWidth,
                  child: Center(child: _SelectionMark(selected: selected)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionMark extends StatelessWidget {
  const _SelectionMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
    width: DriverA01BMetrics.markSize,
    height: DriverA01BMetrics.markSize,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(
        color: selected ? RoundsColors.orange : RoundsColors.lineStrong,
        width: DriverA01BMetrics.markBorderWidth,
      ),
    ),
    alignment: Alignment.center,
    child: Container(
      width: DriverA01BMetrics.markInnerSize,
      height: DriverA01BMetrics.markInnerSize,
      decoration: BoxDecoration(
        color: selected ? RoundsColors.orange : Colors.transparent,
        shape: BoxShape.circle,
      ),
    ),
  );
}

class _LanguageFooter extends StatelessWidget {
  const _LanguageFooter({
    required this.compact,
    required this.thai,
    required this.label,
    required this.onContinue,
  });

  final bool compact;
  final bool thai;
  final String label;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('a01b-footer'),
    color: RoundsColors.surface,
    padding: EdgeInsets.fromLTRB(
      compact
          ? DriverA01BMetrics.compactFooterPaddingHorizontal
          : DriverA01BMetrics.footerPaddingHorizontal,
      DriverA01BMetrics.footerPaddingTop,
      compact
          ? DriverA01BMetrics.compactFooterPaddingHorizontal
          : DriverA01BMetrics.footerPaddingHorizontal,
      DriverA01BMetrics.footerPaddingBottom,
    ),
    child: SizedBox(
      height: DriverA01BMetrics.buttonHeight,
      child: FilledButton(
        key: const Key('continue-language'),
        onPressed: onContinue,
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(DriverA01BMetrics.buttonHeight),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(DriverA01BMetrics.buttonRadius),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: DriverA01BMetrics.buttonSize,
            height: 1,
            fontWeight: thai ? FontWeight.w700 : FontWeight.w900,
            letterSpacing: thai
                ? DriverA01BMetrics.thaiButtonTracking
                : DriverA01BMetrics.englishButtonTracking,
          ),
        ),
      ),
    ),
  );
}
