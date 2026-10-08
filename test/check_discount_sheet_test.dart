import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cashier_app/generated/l10n.dart';
import 'package:cashier_app/features/pos_account/presentation/widgets/check_discount_sheet.dart';
import 'package:cashier_app/features/pos_sale/domain/discount.dart';

void main() {
  testWidgets('every option is reachable on a 768px-tall window', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1024, 768);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final discounts = [
      for (var i = 1; i <= 12; i++)
        Discount(
          id: 'c$i',
          name: 'Chegirma $i',
          kind: DiscountKind.fixed,
          value: i * 1000,
          scope: DiscountScope.check,
        ),
    ];
    Discount? selected;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [AppLocalization.delegate],
        supportedLocales: AppLocalization.delegate.supportedLocales,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Center(
              child: SizedBox(
                width: 400,
                child: CheckDiscountButton(
                  discounts: discounts,
                  selected: selected,
                  onChanged: (d) => setState(() => selected = d),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(CheckDiscountButton));
    await tester.pumpAndSettle();

    final last = find.text('Chegirma 12');
    await tester.scrollUntilVisible(
      last,
      100,
      scrollable: find
          .descendant(
            of: find.byType(Dialog),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(last);
    await tester.pumpAndSettle();

    expect(selected?.id, 'c12');
    expect(find.byType(Dialog), findsNothing);
    expect(find.text(checkDiscountLabel(discounts.last)), findsOneWidget);
  });
}
