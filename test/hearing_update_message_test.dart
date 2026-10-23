import 'package:flutter_test/flutter_test.dart';
import 'package:lawyers_e_diary/utils/hearing_update_message.dart';

void main() {
  const advocate = 'Aarav Mehta';
  final hearingDate = DateTime(2026, 10, 25);

  test('short message for valid case includes client name, hearing date, and advocate closing', () {
    final message = HearingUpdateMessageBuilder.build(
      kind: HearingUpdateKind.short,
      clientName: 'Priya Sharma',
      hearingDate: hearingDate,
      advocateName: advocate,
    );
    expect(message, contains('Dear Priya Sharma,'));
    expect(message, contains('your next hearing date is 25 October 2026.'));
    expect(
      message,
      contains('Please contact me if you need any clarification.'),
    );
    expect(message, endsWith('Warm regards,\n\nAarav Mehta'));
    expect(message, isNot(contains('Lawyer\'s E-Diary')));
  });

  test('short message omits purpose and date-source information', () {
    final message = HearingUpdateMessageBuilder.build(
      kind: HearingUpdateKind.short,
      clientName: 'Priya Sharma',
      hearingDate: hearingDate,
      hearingPurpose: 'Interim application',
      dateOrigin: HearingDateOrigin.caseRecord,
      advocateName: advocate,
    );
    expect(message, isNot(contains('Purpose of the hearing')));
    expect(message, isNot(contains('Date information')));
  });

  test('detailed message includes client name, date, purpose, date source, and advocate closing', () {
    final message = HearingUpdateMessageBuilder.build(
      kind: HearingUpdateKind.detailed,
      clientName: 'Priya Sharma',
      hearingDate: hearingDate,
      hearingPurpose: 'Interim application',
      dateOrigin: HearingDateOrigin.caseRecord,
      advocateName: advocate,
    );
    expect(message, contains('Dear Priya Sharma,'));
    expect(
      message,
      contains('your next hearing is scheduled for 25 October 2026.'),
    );
    expect(message, contains('Purpose of the hearing: Interim application.'));
    expect(
      message,
      contains(
        'Date information: This date comes from the latest authorized case record stored in LED.',
      ),
    );
    expect(message, endsWith('Warm regards,\n\nAarav Mehta'));
  });

  test('detailed message states purpose not provided when missing', () {
    final message = HearingUpdateMessageBuilder.build(
      kind: HearingUpdateKind.detailed,
      clientName: 'Priya Sharma',
      hearingDate: hearingDate,
      advocateName: advocate,
    );
    expect(message, contains('Purpose of the hearing: Not provided.'));
  });

  test('detailed message states date source unknown when provenance cannot be established', () {
    final message = HearingUpdateMessageBuilder.build(
      kind: HearingUpdateKind.detailed,
      clientName: 'Priya Sharma',
      hearingDate: hearingDate,
      advocateName: advocate,
    );
    expect(
      message,
      contains(
        'Date information: The source of this date could not be established.',
      ),
    );
  });

  test('detailed message distinguishes manually entered date from case-record date', () {
    final manual = HearingUpdateMessageBuilder.build(
      kind: HearingUpdateKind.detailed,
      clientName: 'Priya Sharma',
      hearingDate: hearingDate,
      dateOrigin: HearingDateOrigin.manual,
      advocateName: advocate,
    );
    expect(manual, contains('This date was manually entered by the advocate.'));

    final recorded = HearingUpdateMessageBuilder.build(
      kind: HearingUpdateKind.detailed,
      clientName: 'Priya Sharma',
      hearingDate: hearingDate,
      dateOrigin: HearingDateOrigin.caseRecord,
      advocateName: advocate,
    );
    expect(
      recorded,
      contains(
        'This date comes from the latest authorized case record stored in LED.',
      ),
    );
  });

  test(
    'missing client name uses graceful fallback without literal placeholder',
    () {
      final message = HearingUpdateMessageBuilder.build(
        kind: HearingUpdateKind.short,
        clientName: null,
        hearingDate: hearingDate,
        advocateName: advocate,
      );
      expect(message, contains('Dear Client,'));
      expect(message, isNot(contains('[Client Name]')));
      expect(message, isNot(contains('null')));
    },
  );

  test('missing hearing date is reported without fabricating a date', () {
    final message = HearingUpdateMessageBuilder.build(
      kind: HearingUpdateKind.short,
      clientName: 'Priya Sharma',
      hearingDate: null,
      advocateName: advocate,
    );
    expect(
      message,
      contains('your next hearing date has not yet been scheduled.'),
    );
    expect(message, isNot(contains('25 October 2026')));
  });

  test('advocate name fallback avoids literal placeholder when empty', () {
    final message = HearingUpdateMessageBuilder.build(
      kind: HearingUpdateKind.short,
      clientName: 'Priya Sharma',
      hearingDate: hearingDate,
      advocateName: '',
    );
    expect(message, endsWith('Warm regards,\n\nAdvocate'));
  });
}
