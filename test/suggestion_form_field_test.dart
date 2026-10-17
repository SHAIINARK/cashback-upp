import 'package:balance_app/presentation/suggestion_form_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('empty field opens all options and filters as the user types', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(() => tester.view.resetViewInsets());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuggestionFormField(
            controller: controller,
            suggestions: const ['Аптеки', 'Такси', 'Транспорт'],
            label: 'Категория',
            hint: 'Введите название',
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    expect(find.text('Аптеки'), findsOneWidget);
    expect(find.text('Такси'), findsOneWidget);
    expect(find.text('Транспорт'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'апт');
    await tester.pumpAndSettle();
    expect(find.text('Аптеки'), findsOneWidget);
    expect(find.text('Такси'), findsNothing);

    await tester.tap(find.text('Аптеки'));
    await tester.pumpAndSettle();
    expect(controller.text, 'Аптеки');
  });

  testWidgets('custom entry is offered when no saved option matches', (
    tester,
  ) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    tester.view.viewInsets = const FakeViewPadding(bottom: 280);
    addTearDown(() => tester.view.resetViewInsets());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SuggestionFormField(
            controller: controller,
            suggestions: const ['Рубли', 'Бонусы', 'Сбер Спасибо'],
            label: 'Вознаграждение',
            hint: 'Введите вариант',
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Мили банка');
    await tester.pumpAndSettle();
    expect(find.text('Использовать «Мили банка»'), findsOneWidget);
    await tester.tap(find.text('Использовать «Мили банка»'));
    await tester.pumpAndSettle();
    expect(controller.text, 'Мили банка');
  });
}
