import 'package:flutter/widgets.dart';

enum HarnessLocale { thai, english }

extension HarnessLocaleValue on HarnessLocale {
  Locale get locale => switch (this) {
    HarnessLocale.thai => const Locale('th', 'TH'),
    HarnessLocale.english => const Locale('en'),
  };

  String get storageValue => switch (this) {
    HarnessLocale.thai => 'th-TH',
    HarnessLocale.english => 'en',
  };

  static HarnessLocale fromStorage(String? value) =>
      value == HarnessLocale.english.storageValue
      ? HarnessLocale.english
      : HarnessLocale.thai;
}

class AppStrings {
  const AppStrings(this.locale);

  final HarnessLocale locale;

  bool get isThai => locale == HarnessLocale.thai;
  String get appName => 'Rounds';
  String get languageEyebrow => isThai ? 'ภาษา' : 'First time';
  String get languageTitle => isThai ? 'เลือกภาษา' : 'Choose your language';
  String get languageLead => isThai
      ? 'เปลี่ยนได้ภายหลังในโปรไฟล์'
      : 'You can change this later in Profile.';
  String get thai => 'ไทย';
  String get english => 'English';
  String get thaiLanguageDescription => 'ภาษาไทย';
  String get englishLanguageDescription => isThai ? 'ภาษาอังกฤษ' : 'English';
  String get languageContinueAction => isThai ? 'ต่อไป' : 'Continue in English';
  String get chooseLanguage => isThai ? 'เลือกภาษา' : 'Choose language';
  String get continueAction => isThai ? 'ดำเนินการต่อ' : 'Continue';
  String get assignedRound => isThai ? 'รอบที่ได้รับมอบหมาย' : 'Assigned Round';
  String get currentStop => isThai ? 'จุดส่งปัจจุบัน' : 'Current Stop';
  String get startNavigation => isThai ? 'เริ่มนำทาง' : 'Start navigation';
  String get contactOperations =>
      isThai ? 'ติดต่อฝ่ายปฏิบัติการ' : 'Contact Operations';
  String get reportException => isThai ? 'แจ้งปัญหา' : 'Report exception';
  String get arrived => isThai ? 'ถึงแล้ว' : 'Arrived';
  String get podPlaceholder =>
      isThai ? 'ดำเนินการหลักฐานการส่ง' : 'Continue to proof of delivery';
  String get nextStop => isThai ? 'จุดถัดไป' : 'Next Stop';
  String get live => isThai ? 'สด' : 'LIVE';
  String get aging => isThai ? 'กำลังล่าช้า' : 'AGING';
  String get stale => isThai ? 'ตำแหน่งล่าสุด' : 'LAST KNOWN';
  String get unknown => isThai ? 'ไม่ทราบตำแหน่ง' : 'UNKNOWN';
  String get telemetryBuffered =>
      isThai ? 'บันทึกตำแหน่งไว้ในเครื่อง' : 'Location buffered locally';
  String get pendingSync => isThai ? 'รอซิงค์' : 'Pending sync';
  String get navigationReady => isThai
      ? 'Google Navigation · โหมดรถจักรยานยนต์'
      : 'Google Navigation · TWO_WHEELER';
  String get retryTwoWheeler =>
      isThai ? 'ลองเส้นทางรถจักรยานยนต์อีกครั้ง' : 'Retry TWO_WHEELER';
  String get testDrivingRoute =>
      isThai ? 'ทดสอบเส้นทางรถยนต์' : 'Test DRIVING route';
  String get routeDiagnosticHelp => isThai
      ? 'แผนที่ยังใช้งานได้ เลือกลองอีกครั้งหรือทดสอบรถยนต์เพื่อแยกปัญหาของ Google'
      : 'The map is still available. Retry or test DRIVING to isolate the Google routing failure.';
  String get demoAddress => isThai
      ? 'อาคารอินเตอร์เชนจ์ 21 ถนนสุขุมวิท กรุงเทพมหานคร'
      : 'Interchange 21, Sukhumvit Road, Bangkok';
  String get recipient =>
      isThai ? 'คุณศิริพร · UrbanFlowers' : 'Siriporn · UrbanFlowers';
}
