// Pure helpers for composing WhatsApp hearing-update messages.
//
// This file deliberately has no Flutter/Firebase dependencies so it can be
// unit-tested in isolation.

enum HearingUpdateKind { short, detailed }

enum HearingDateOrigin {
  /// The advocate typed the date manually.
  manual,

  /// The date came from the latest authorized case record stored in LED.
  caseRecord,

  /// No reliable provenance could be established.
  unknown,
}

class HearingUpdateMessageBuilder {
  HearingUpdateMessageBuilder._();

  static const List<String> _monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  static String formatDate(DateTime date) {
    final day = date.day.toString();
    final month = _monthNames[date.month - 1];
    return '$day $month ${date.year}';
  }

  static String _clientGreeting(String? clientName) {
    final name = (clientName ?? '').trim();
    if (name.isEmpty) return 'Dear Client,';
    return 'Dear $name,';
  }

  static String _advocateClosing(String advocateName) {
    final name = advocateName.trim();
    final closingName = name.isEmpty ? 'Advocate' : name;
    return 'Warm regards,\n\n$closingName';
  }

  static String build({
    required HearingUpdateKind kind,
    String? clientName,
    DateTime? hearingDate,
    String? hearingPurpose,
    HearingDateOrigin dateOrigin = HearingDateOrigin.unknown,
    required String advocateName,
  }) {
    final greeting = _clientGreeting(clientName);
    final closing = _advocateClosing(advocateName);

    if (kind == HearingUpdateKind.short) {
      final body = hearingDate == null
          ? 'This is to inform you that your next hearing date has not yet been scheduled.'
          : 'This is to inform you that your next hearing date is ${formatDate(hearingDate)}.';
      return '$greeting\n\n$body\n\n'
          'Please contact me if you need any clarification.\n\n$closing';
    }

    // Detailed.
    final purposeText = (hearingPurpose ?? '').trim();
    final purposeLine = purposeText.isEmpty
        ? 'Purpose of the hearing: Not provided.'
        : 'Purpose of the hearing: $purposeText.';

    String dateInfo;
    switch (dateOrigin) {
      case HearingDateOrigin.manual:
        dateInfo = 'This date was manually entered by the advocate.';
        break;
      case HearingDateOrigin.caseRecord:
        dateInfo = 'This date comes from the latest authorized case record stored in LED.';
        break;
      case HearingDateOrigin.unknown:
        dateInfo = 'The source of this date could not be established.';
        break;
    }

    final dateClause = hearingDate == null
        ? 'your next hearing has not yet been scheduled.'
        : 'your next hearing is scheduled for ${formatDate(hearingDate)}.';

    return '$greeting\n\n'
        'This is to inform you that $dateClause\n\n'
        '$purposeLine\n\n'
        'Date information: $dateInfo\n\n'
        'Please contact me if you need any clarification regarding the upcoming hearing.\n\n'
        '$closing';
  }
}
