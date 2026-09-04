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

  String get pickupEyebrow => isThai ? 'ถึงจุดรับของ' : 'AT PICKUP';
  String pickupDeliveryCount(int count) => isThai
      ? '$count งานส่ง'
      : '$count ${count == 1 ? 'delivery' : 'deliveries'}';
  String get confirmPickup => isThai ? 'ยืนยันรับของ' : 'Confirm pickup';
  String get pickupConfirmed => isThai ? 'ยืนยันแล้ว' : 'confirmed';
  String pickupManifestSummary(int count) => isThai
      ? '$count แพ็กเกจ · ตรวจของจริง'
      : '$count package${count == 1 ? '' : 's'} · physical manifest';
  String get pickupCollect => isThai ? 'รับของ' : 'Collect';
  String get pickupTapWhenPresent =>
      isThai ? 'แตะเมื่อของอยู่กับคุณแล้ว' : 'Tap when physically present';
  String get pickupProblem => isThai ? 'มีปัญหารับของ' : 'Pickup problem';
  String get pickupPendingSync =>
      isThai ? 'รอซิงค์ — ยังไม่ได้ยืนยัน' : 'Pending sync — not confirmed';
  String get pickupSending =>
      isThai ? 'กำลังส่งไปยังเซิร์ฟเวอร์…' : 'Sending to server…';
  String get pickupProblemLead => isThai
      ? 'เลือกงานส่งและปัญหาที่ตรงกัน การรับของจะหยุดจนกว่าฝ่ายปฏิบัติการจะแก้ไข'
      : 'Choose the exact delivery and problem. Ordinary pickup will stop until Operations resolves it.';
  String get delivery => isThai ? 'งานส่ง' : 'Delivery';
  String get pickupWhatIsWrong => isThai ? 'มีปัญหาอะไร?' : 'What is wrong?';
  String get pickupMissingItem => isThai ? 'ของไม่ครบ' : 'Missing item';
  String get pickupMissingItemHelp => isThai
      ? 'ไม่พบแพ็กเกจหรือสิ่งของที่ควรมี'
      : 'An expected package or item is not here';
  String get pickupWrongItem => isThai ? 'ของไม่ตรง' : 'Wrong item';
  String get pickupWrongItemHelp => isThai
      ? 'แพ็กเกจไม่ตรงกับงานส่งนี้'
      : 'The package does not match this delivery';
  String get pickupDamagedItem => isThai ? 'ของเสียหาย' : 'Damaged item';
  String get pickupDamagedItemHelp =>
      isThai ? 'แพ็กเกจหรือสิ่งของเสียหาย' : 'The package or item is damaged';
  String get pickupOperationsNote => isThai
      ? 'หมายเหตุถึงฝ่ายปฏิบัติการ (ไม่บังคับ)'
      : 'Note for Operations (optional)';
  String get pickupSendToOperations =>
      isThai ? 'ส่งให้ฝ่ายปฏิบัติการ' : 'Send to Operations';
  String get pickupSavedLocally => isThai
      ? 'บันทึกการรับของไว้ในโทรศัพท์แล้ว กำลังรอซิงค์ — ยังไม่ยืนยันการรับผิดชอบ'
      : 'Pickup saved on this phone. Pending sync — custody is not confirmed yet.';
  String get pickupCouldNotConfirm =>
      isThai ? 'ไม่สามารถยืนยันการรับของได้' : 'Pickup could not be confirmed';
  String get pickupProblemSent => isThai
      ? 'ส่งปัญหาให้ฝ่ายปฏิบัติการแล้ว หยุดการรับของ'
      : 'Pickup problem sent to Operations. Pickup stopped.';
  String get pickupProblemSavedLocally => isThai
      ? 'บันทึกปัญหาไว้ในโทรศัพท์แล้ว กำลังรอซิงค์ — อย่ายืนยันการรับของ'
      : 'Problem saved on this phone. Pending sync — do not confirm pickup.';
  String get pickupProblemCouldNotSend => isThai
      ? 'ไม่สามารถส่งปัญหาการรับของได้'
      : 'Pickup problem could not be sent';

  String pickupHandlingNote(String note) {
    if (!isThai) return note;
    final normalized = note.toLowerCase();
    if (normalized.contains('cool')) return 'เก็บให้เย็น';
    if (normalized.contains('fragile')) return 'ระวัง';
    return note;
  }
}
