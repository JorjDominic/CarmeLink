import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('October tester feedback contract', () {
    test(
      'owner billing prioritizes review work and limits advance rent preview',
      () {
        final source =
            File('lib/views/owner/owner_pages.dart').readAsStringSync();

        expect(
          source.contains('int _paymentDisplayRank(Payment payment)'),
          isTrue,
        );
        expect(
          source.contains('if (payment.isPending) return 0;'),
          isTrue,
        );
        expect(
          source.contains('BillingManagementPolicy.isFutureUnpaid(payment)'),
          isTrue,
        );
        expect(
          source.contains("Key('owner-advance-rent-toggle')"),
          isTrue,
        );
        expect(source.contains('Show upcoming bills'), isTrue);
      },
    );

    test(
      'caretaker single-tool billing category opens directly and room tools are merged',
      () {
        final source =
            File('lib/views/owner/owner_pages.dart').readAsStringSync();

        expect(
          source.contains('if (category.items.length == 1)'),
          isTrue,
        );
        expect(source.contains('category.items.first.page'), isTrue);
        expect(
          source.contains("'Rooms & inspections'"),
          isTrue,
        );
        expect(
          source.contains("'Room inspections'"),
          isFalse,
        );
      },
    );

    test('tenant payment records default to due-soon ordering', () {
      final source =
          File('lib/views/tenant/tenant_pages.dart').readAsStringSync();

      expect(
        source.contains(
          'RecordListSort _paymentSort = RecordListSort.oldest;',
        ),
        isTrue,
      );
      expect(
        source.contains('int _compareDueSoon(Payment a, Payment b)'),
        isTrue,
      );
      expect(source.contains("Text('Due soon first')"), isTrue);
      expect(
        source.contains(
          '..sort((a, b) => a.dueDate.compareTo(b.dueDate));',
        ),
        isTrue,
      );
    });

    test(
      'guardian curfew presence is collapsible and tenant status wraps',
      () {
        final source =
            File('lib/views/guardian/guardian_pages.dart').readAsStringSync();

        expect(
          source.contains("Key('guardian-presence-records-toggle')"),
          isTrue,
        );
        expect(
          source.contains(r"'Show more ($hiddenPresenceCount)'"),
          isTrue,
        );
        expect(source.contains('softWrap: true'), isTrue);
        expect(
          source.contains(
            'final aOpen = !a.isVerified && !a.isVoided;',
          ),
          isTrue,
        );
      },
    );
  });
}
