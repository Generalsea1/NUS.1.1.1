class NusShoppingTextParser {
  const NusShoppingTextParser._();

  static List<String> parse(String raw) {
    var text = _stripPrefix(raw);
    text = text
        .replaceAll('قائمة المشتريات', '')
        .replaceAll('قائمه المشتريات', '')
        .trim();

    if (text.isEmpty) return const <String>[];

    final normalized = text
        .replaceAll('،', ',')
        .replaceAll('\n', ',')
        .trim();

    final candidates = <String>[];
    for (final commaPart in normalized.split(',')) {
      candidates.addAll(_splitConjunctions(commaPart.trim()));
    }

    final unique = <String>[];
    final seen = <String>{};
    for (final candidate in candidates) {
      final item = _cleanItem(candidate);
      if (item.isEmpty) continue;
      final key = item.replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
      if (seen.add(key)) unique.add(item);
    }
    return List<String>.unmodifiable(unique);
  }

  static String _stripPrefix(String raw) {
    var text = raw.trim();
    const prefixes = <String>[
      'عايز أجيب ',
      'عايز اجيب ',
      'عايز أجيب',
      'عايز اجيب',
      'قائمة المشتريات ',
      'قائمه المشتريات ',
      'مشتريات ',
      'قائمة المشتريات',
      'قائمه المشتريات',
      'مشتريات',
      'هات ',
      'هات',
      'جيب ',
      'جيب',
      'اشتري ',
      'اشتري',
      'اشترى ',
      'اشترى',
    ];
    for (final prefix in prefixes) {
      if (text.startsWith(prefix)) {
        return text.substring(prefix.length).trim();
      }
    }
    return text;
  }

  static List<String> _splitConjunctions(String segment) {
    final text = segment.trim();
    if (text.isEmpty) return const <String>[];

    // Standalone "و" is always an item separator. For an attached "و",
    // split only when the following token is substantial enough to be an
    // item; this preserves words such as "ورق" and "وصفة".
    final tokens = text.split(RegExp(r'\s+'));
    if (tokens.length < 2) return <String>[text];

    final result = <String>[];
    var current = <String>[];
    for (final token in tokens) {
      if (token == 'و' || token == 'و،' || token == 'و,') {
        if (current.isNotEmpty) {
          result.add(current.join(' '));
          current = <String>[];
        }
        continue;
      }

      if (token.startsWith('و') && token.length > 1 && current.isNotEmpty) {
        result.add(current.join(' '));
        current = <String>[token.substring(1)];
        continue;
      }

      current.add(token);
    }
    if (current.isNotEmpty) result.add(current.join(' '));
    return result;
  }

  static String _cleanItem(String item) => item
      .trim()
      .replaceFirst(RegExp(r'^[,،]+'), '')
      .replaceFirst(RegExp(r'[,،]+$'), '')
      .trim();
}
