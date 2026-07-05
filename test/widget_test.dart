import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:runova_diary/app.dart';

void main() {
  testWidgets('App renders splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: RunovaDiaryApp(),
      ),
    );

    expect(find.text('Runova Diary'), findsOneWidget);
  });
}
