class NusQuickAddParsedInput {
  const NusQuickAddParsedInput({
    required this.title,
    required this.dateTime,
    required this.scheduleDetected,
  });

  final String title;
  final DateTime dateTime;
  final bool scheduleDetected;
}

class NusQuickAddParser {
  const NusQuickAddParser._();

  static NusQuickAddParsedInput parse(String raw, {DateTime? now}) {
    final current = now ?? DateTime.now();
    var title = _normalize(raw).trim();
    var dateTime = current.add(const Duration(hours: 1));
    var detected = false;

    final relativeHour = RegExp(r'(?:^|\s)بعد\s+ساعة(?:\s+واحدة)?(?=\s|$)', caseSensitive: false);
    if (relativeHour.hasMatch(title)) {
      dateTime = current.add(const Duration(hours: 1));
      title = title.replaceFirst(relativeHour, ' ');
      detected = true;
    }

    final tomorrowPattern = RegExp(r'(?:^|\s)(?:بكرة|غدا|غدًا)(?=\s|$)', caseSensitive: false);
    final todayPattern = RegExp(r'(?:^|\s)(?:النهارده|اليوم)(?=\s|$)', caseSensitive: false);
    final slashDatePattern = RegExp(r'(?:^|\s)(\d{1,2})\s*/\s*(\d{1,2})(?=\s|$)');
    final slashDateMatch = slashDatePattern.firstMatch(title);

    int hour = 9;
    int minute = 0;
    final explicitTimePattern = RegExp(
      r'(?:^|\s)الساعة\s*(\d{1,2})(?::(\d{2}))?\s*(صباحًا|صباحا|صباح|مساءً|مساء|م|ص)?(?=\s|$)',
      caseSensitive: false,
    );
    final meridiemOnlyTimePattern = RegExp(
      r'(?:^|\s)(\d{1,2})(?::(\d{2}))\s*(صباحًا|صباحا|صباح|مساءً|مساء|م|ص)(?=\s|$)',
      caseSensitive: false,
    );
    final explicitTimeMatch = explicitTimePattern.firstMatch(title);
    final meridiemOnlyTimeMatch = meridiemOnlyTimePattern.firstMatch(title);
    final timeMatch = explicitTimeMatch ?? meridiemOnlyTimeMatch;
    final timePattern = explicitTimeMatch != null ? explicitTimePattern : meridiemOnlyTimePattern;

    if (timeMatch != null) {
      final parsedHour = int.tryParse(timeMatch.group(1) ?? '');
      final parsedMinute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
      if (parsedHour != null && parsedHour >= 0 && parsedHour <= 23 && parsedMinute >= 0 && parsedMinute <= 59) {
        hour = parsedHour;
        minute = parsedMinute;
        final meridiem = (timeMatch.group(3) ?? '').toLowerCase();
        if ((meridiem.contains('مساء') || meridiem == 'م') && hour < 12) hour += 12;
        if ((meridiem.contains('صباح') || meridiem == 'ص') && hour == 12) hour = 0;
        if (meridiem.isEmpty && hour <= 7) hour += 12;
        detected = true;
        title = title.replaceFirst(timePattern, ' ');
      }
    }

    DateTime? explicitDate;
    if (slashDateMatch != null) {
      final day = int.tryParse(slashDateMatch.group(1) ?? '');
      final month = int.tryParse(slashDateMatch.group(2) ?? '');
      if (day != null && month != null && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        var candidate = DateTime(current.year, month, day, hour, minute);
        if (candidate.isBefore(current)) candidate = DateTime(current.year + 1, month, day, hour, minute);
        explicitDate = candidate;
        detected = true;
      }
      title = title.replaceFirst(slashDatePattern, ' ');
    } else if (tomorrowPattern.hasMatch(title)) {
      explicitDate = DateTime(current.year, current.month, current.day + 1, hour, minute);
      title = title.replaceFirst(tomorrowPattern, ' ');
      detected = true;
    } else if (todayPattern.hasMatch(title)) {
      explicitDate = DateTime(current.year, current.month, current.day, hour, minute);
      title = title.replaceFirst(todayPattern, ' ');
      if (explicitDate.isBefore(current) && timeMatch != null) explicitDate = explicitDate.add(const Duration(days: 1));
      detected = true;
    } else {
      final dayPhrase = RegExp(r'(?:^|\s)يوم\s*\d{1,2}(?=\s|$)');
      final dayMatch = dayPhrase.firstMatch(title);
      if (dayMatch != null) {
        final numberMatch = RegExp(r'\d{1,2}').firstMatch(dayMatch.group(0) ?? '');
        final day = int.tryParse(numberMatch?.group(0) ?? '');
        if (day != null && day >= 1 && day <= 31) {
          var candidate = DateTime(current.year, current.month, day, hour, minute);
          if (candidate.isBefore(current)) {
            final nextMonth = current.month == 12 ? 1 : current.month + 1;
            final nextYear = current.month == 12 ? current.year + 1 : current.year;
            candidate = DateTime(nextYear, nextMonth, day, hour, minute);
          }
          explicitDate = candidate;
          detected = true;
        }
        title = title.replaceFirst(dayPhrase, ' ');
      }
    }

    if (explicitDate != null) dateTime = explicitDate;

    title = title
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .replaceAll(RegExp(r'^[،,.:\-]+|[،,.:\-]+$'), '')
        .trim();
    if (title.isEmpty) title = _normalize(raw).trim();

    return NusQuickAddParsedInput(
      title: title,
      dateTime: dateTime,
      scheduleDetected: detected,
    );
  }

  static String _normalize(String value) {
    return value
        .replaceAll('٠', '0')
        .replaceAll('١', '1')
        .replaceAll('٢', '2')
        .replaceAll('٣', '3')
        .replaceAll('٤', '4')
        .replaceAll('٥', '5')
        .replaceAll('٦', '6')
        .replaceAll('٧', '7')
        .replaceAll('٨', '8')
        .replaceAll('٩', '9')
        .replaceAll('إ', 'ا')
        .replaceAll('أ', 'ا')
        .replaceAll('آ', 'ا');
  }
}
