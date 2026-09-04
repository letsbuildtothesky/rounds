class DriverMessageTextSegment {
  const DriverMessageTextSegment({required this.text, this.uri});

  final String text;
  final Uri? uri;
}

final _messageUrlPattern = RegExp(
  r'(?:https?://|www\.)[^\s]+',
  caseSensitive: false,
);
final _trailingUrlPunctuation = RegExp(r'[.,!?;:)\]}]+$');

List<DriverMessageTextSegment> parseDriverMessageText(String text) {
  final segments = <DriverMessageTextSegment>[];
  var offset = 0;
  for (final match in _messageUrlPattern.allMatches(text)) {
    if (match.start > offset) {
      segments.add(
        DriverMessageTextSegment(text: text.substring(offset, match.start)),
      );
    }
    final matched = match.group(0)!;
    final urlText = matched.replaceFirst(_trailingUrlPunctuation, '');
    final punctuation = matched.substring(urlText.length);
    final normalized = urlText.toLowerCase().startsWith('www.')
        ? 'https://$urlText'
        : urlText;
    final uri = Uri.tryParse(normalized);
    segments.add(
      DriverMessageTextSegment(
        text: urlText,
        uri: uri?.hasAuthority == true ? uri : null,
      ),
    );
    if (punctuation.isNotEmpty) {
      segments.add(DriverMessageTextSegment(text: punctuation));
    }
    offset = match.end;
  }
  if (offset < text.length) {
    segments.add(DriverMessageTextSegment(text: text.substring(offset)));
  }
  if (segments.isEmpty) segments.add(DriverMessageTextSegment(text: text));
  return segments;
}
