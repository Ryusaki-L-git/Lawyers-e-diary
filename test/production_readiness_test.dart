import 'package:flutter_test/flutter_test.dart';
import 'package:lawyers_e_diary/models/case_model.dart';
import 'package:lawyers_e_diary/models/todo_model.dart';
import 'package:lawyers_e_diary/splash_screen.dart';
import 'package:lawyers_e_diary/utils/case_actions_helper.dart';
import 'package:lawyers_e_diary/utils/hearing_update_message.dart';

/// Regression tests for the defects found during the production-readiness
/// audit:
///
///  * startup routing must trust Firebase Authentication, not a local flag
///  * a hearing purpose recorded on a case must survive serialization
///  * the WhatsApp helper must fail closed and must not misreport a date's
///    provenance
void main() {
  group('Startup routing (Mission C)', () {
    test('a signed-out user is sent to the login screen', () {
      expect(
        resolveStartupDestination(
          hasAuthenticatedUser: false,
          profileCompleted: true,
        ),
        StartupDestination.login,
      );
      expect(
        resolveStartupDestination(
          hasAuthenticatedUser: false,
          profileCompleted: false,
        ),
        StartupDestination.login,
      );
    });

    test('a signed-in user with a complete profile reaches the app', () {
      expect(
        resolveStartupDestination(
          hasAuthenticatedUser: true,
          profileCompleted: true,
        ),
        StartupDestination.home,
      );
    });

    test('a signed-in user with an incomplete profile completes it first', () {
      expect(
        resolveStartupDestination(
          hasAuthenticatedUser: true,
          profileCompleted: false,
        ),
        StartupDestination.welcome,
      );
    });

    test('the profile state never grants access to a signed-out user', () {
      // A stale local flag saying "profile completed" must not be able to
      // route a signed-out user into the authenticated app.
      expect(
        resolveStartupDestination(
          hasAuthenticatedUser: false,
          profileCompleted: true,
        ),
        StartupDestination.login,
      );
    });
  });

  group('Case model hearing provenance (Mission D)', () {
    test('the hearing purpose round-trips through the cloud map', () {
      final model = CaseModel(
        id: 'case-1',
        caseTitle: 'Mehta v. State',
        caseNumber: 'CNR-1',
        clientName: 'Mehta & Partners',
        opponentName: 'State',
        courtName: 'District Court',
        caseType: 'Criminal',
        status: 'active',
        nextHearingDate: DateTime(2026, 10, 25),
        hearingPurpose: 'Interim application',
        caseSource: 'manual',
      );

      final map = model.toMap();
      expect(map['hearingPurpose'], 'Interim application');
      expect(map['caseSource'], 'manual');

      final restored = CaseModel.fromMap('case-1', map);
      expect(restored.hearingPurpose, 'Interim application');
      expect(restored.caseSource, 'manual');
    });

    test('a missing hearing purpose stays absent rather than invented', () {
      final model = CaseModel(
        id: 'case-2',
        caseTitle: 'Untitled',
        caseNumber: 'CNR-2',
        clientName: 'Client',
        opponentName: '',
        courtName: 'Court',
        caseType: 'Civil',
        status: 'active',
      );

      final map = model.toMap();
      expect(map.containsKey('hearingPurpose'), isFalse);

      final restored = CaseModel.fromMap('case-2', map);
      expect(restored.hearingPurpose, isNull);
    });

    test(
      'a case sourced from the authorised backend is labelled as a case record',
      () {
        final model = CaseModel(
          id: 'case-3',
          caseTitle: 'Synced matter',
          caseNumber: 'CNR-3',
          clientName: 'Client',
          opponentName: '',
          courtName: 'Court',
          caseType: 'Civil',
          status: 'active',
          caseSource: 'smart_backend',
        );
        expect(model.caseSource, 'smart_backend');
        expect(model.toMap()['caseSource'], 'smart_backend');
      },
    );

    test('the default case source is manual, never a synchronised claim', () {
      final model = CaseModel(
        id: 'case-4',
        caseTitle: 'Untitled',
        caseNumber: 'CNR-4',
        clientName: 'Client',
        opponentName: '',
        courtName: 'Court',
        caseType: 'Civil',
        status: 'active',
      );
      expect(model.caseSource, 'manual');
    });
  });

  group('WhatsApp hearing update helpers (Mission F)', () {
    test('a manually entered date is reported as manual', () {
      expect(
        CaseActionsHelper.originFromCaseSource('manual'),
        HearingDateOrigin.manual,
      );
      expect(
        CaseActionsHelper.originFromCaseSource('MANUAL'),
        HearingDateOrigin.manual,
      );
    });

    test('an authorised backend source is reported as a case record', () {
      for (final source in [
        'ecourt',
        'synced',
        'court',
        'authorized',
        'case_record',
        'smart_backend',
      ]) {
        expect(
          CaseActionsHelper.originFromCaseSource(source),
          HearingDateOrigin.caseRecord,
          reason: 'expected "$source" to map to a case-record origin',
        );
      }
    });

    test('an unrecognised source is reported as unknown, never guessed', () {
      expect(
        CaseActionsHelper.originFromCaseSource(''),
        HearingDateOrigin.unknown,
      );
      expect(
        CaseActionsHelper.originFromCaseSource('something-else'),
        HearingDateOrigin.unknown,
      );
    });

    test('phone numbers are reduced to digits and short numbers rejected', () {
      expect(
        CaseActionsHelper.normalizeWhatsAppNumber('+91 98765 43210'),
        '919876543210',
      );
      expect(
        CaseActionsHelper.normalizeWhatsAppNumber('(020) 7946-0000'),
        '02079460000',
      );
      expect(CaseActionsHelper.normalizeWhatsAppNumber('12345'), isNull);
      expect(CaseActionsHelper.normalizeWhatsAppNumber(''), isNull);
      expect(CaseActionsHelper.normalizeWhatsAppNumber(null), isNull);
    });

    test(
      'a phone number never carries characters that could alter the link',
      () {
        final normalized = CaseActionsHelper.normalizeWhatsAppNumber(
          '+91 98765-43210 &evil=1',
        );
        // Only digits survive, so nothing in the input can inject a query
        // parameter or a path segment into the WhatsApp link.
        expect(normalized, isNot(contains('&')));
        expect(normalized, isNot(contains('=')));
        expect(normalized, isNot(contains(' ')));
        expect(normalized, isNot(contains('?')));
        expect(normalized, isNot(contains('/')));
        expect(RegExp(r'^\d+$').hasMatch(normalized!), isTrue);
      },
    );
  });

  group('To-Do model (Mission E)', () {
    test('a completed task records when it was completed', () {
      final model = TodoModel(
        id: 'todo-1',
        userId: 'user-1',
        title: 'Draft the plaint',
      );
      expect(model.isCompleted, isFalse);
      expect(model.isOverdue, isFalse);

      final completed = model.copyWith(isCompleted: true);
      expect(completed.isCompleted, isTrue);
      expect(completed.completedAt, isNotNull);

      final reopened = completed.copyWith(isCompleted: false);
      expect(reopened.isCompleted, isFalse);
      expect(reopened.completedAt, isNull);
    });
  });
}
