/// Text normalisation for on-device command parsing (Arabic + English).
///
/// Arabic: diacritics and tatweel removed, alef/hamza forms unified
/// (أ إ آ ٱ → ا, ؤ → و, ئ → ي), ى → ي, ة → ه, Arabic-Indic and Persian
/// digits → ASCII, Arabic punctuation → ASCII. English: lower case.
/// The result is a single-spaced string; punctuation that separates
/// clauses (`,` `;` `.` `!` `?` and newlines) is kept as its own token.
String normalizeCommandText(String input) {
  final b = StringBuffer();
  for (final rune in input.runes) {
    final c = String.fromCharCode(rune);
    // Harakat, tanween, shadda, sukun, superscript alef, Quranic marks, tatweel.
    if ((rune >= 0x064B && rune <= 0x065F) || rune == 0x0670 || rune == 0x0640 || (rune >= 0x06D6 && rune <= 0x06ED)) {
      continue;
    }
    if (rune >= 0x0660 && rune <= 0x0669) {
      b.writeCharCode(0x30 + rune - 0x0660);
      continue;
    }
    if (rune >= 0x06F0 && rune <= 0x06F9) {
      b.writeCharCode(0x30 + rune - 0x06F0);
      continue;
    }
    b.write(switch (c) {
      'أ' || 'إ' || 'آ' || 'ٱ' => 'ا',
      'ؤ' => 'و',
      'ئ' => 'ي',
      'ى' => 'ي',
      'ة' => 'ه',
      '،' => ',',
      '؛' => ';',
      '؟' => '?',
      '٪' => '%',
      '٫' => '.',
      '“' || '”' || '«' || '»' || '"' || '(' || ')' || '[' || ']' => ' ',
      _ => c.toLowerCase(),
    });
  }
  var s = b.toString();
  // Separate clause punctuation (but keep decimals such as 0.5 intact).
  s = s.replaceAllMapped(RegExp(r'([,;!?\n])'), (m) => ' ${m[1] == '\n' ? ',' : m[1]} ');
  s = s.replaceAllMapped(RegExp(r'(?<!\d)\.|\.(?!\d)'), (_) => ' . ');
  s = s.replaceAll('&', ' and ');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Arabic attached prefixes a token may carry before a dictionary stem:
/// conjunctions (و ف), prepositions (ب ل ك) and the article (ال).
const _arabicPrefixes = ['وبال', 'وال', 'فال', 'بال', 'كال', 'لل', 'ال', 'و', 'ف', 'ب', 'ل'];

/// Candidate stems of [token]: the token itself, then the token with each
/// matching Arabic prefix removed (longest first), never shorter than two
/// letters. English tokens yield themselves only.
List<String> tokenStems(String token) {
  final out = <String>[token];
  if (!_isArabic(token)) return out;
  for (final p in _arabicPrefixes) {
    if (token.length - p.length >= 2 && token.startsWith(p)) {
      final rest = token.substring(p.length);
      if (!out.contains(rest)) out.add(rest);
    }
  }
  return out;
}

bool _isArabic(String s) => s.runes.any((r) => r >= 0x0600 && r <= 0x06FF);
