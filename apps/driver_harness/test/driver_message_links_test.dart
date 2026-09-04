import 'package:flutter_test/flutter_test.dart';
import 'package:rounds_driver_harness/src/driver/driver_message_links.dart';

void main() {
  test('detects http, https and www links without consuming punctuation', () {
    final segments = parseDriverMessageText(
      'Open (https://rounds.example/stop), then www.example.com/help.',
    );

    expect(
      segments
          .where((segment) => segment.uri != null)
          .map((segment) => segment.uri.toString()),
      ['https://rounds.example/stop', 'https://www.example.com/help'],
    );
    expect(
      segments.map((segment) => segment.text).join(),
      'Open (https://rounds.example/stop), then www.example.com/help.',
    );
  });

  test('leaves ordinary text as one non-link segment', () {
    final segments = parseDriverMessageText('Meet me at Gate B.');

    expect(segments, hasLength(1));
    expect(segments.single.text, 'Meet me at Gate B.');
    expect(segments.single.uri, isNull);
  });
}
