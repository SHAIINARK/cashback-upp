import 'package:balance_app/app/app.dart';
import 'package:balance_app/data/empty_cashback_repository.dart';
import 'package:balance_app/domain/models.dart';
import 'package:balance_app/logic/cashback_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('Empty user data and navigation to import review', (
    tester,
  ) async {
    final controller = CashbackController(
      EmptyCashbackRepository(),
      initialMonth: CashbackMonth(2026, 12),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(CashbackApp(controller: controller));
    expect(find.text('Здесь будут ваши категории'), findsOneWidget);
    await tester.tap(find.byTooltip('Следующий месяц'));
    await tester.pump();
    expect(find.text('Январь 2027'), findsOneWidget);
    await tester.tap(find.text('Мои карты').last);
    await tester.pumpAndSettle();
    expect(find.text('Карты ещё не добавлены'), findsOneWidget);
    await tester.tap(find.text('Импорт'));
    await tester.pumpAndSettle();
    final review = find.text('Открыть проверку импорта');
    await tester.ensureVisible(review);
    await tester.pumpAndSettle();
    await tester.tap(review);
    await tester.pumpAndSettle();
    expect(find.text('Пока нечего проверять'), findsOneWidget);
    await tester.tap(find.text('Вернуться к импорту'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Настройки').last);
    await tester.pumpAndSettle();
    expect(find.text('Без доступа к банку'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Compact display supports large text without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final controller = CashbackController(EmptyCashbackRepository());
    addTearDown(controller.dispose);
    await tester.pumpWidget(CashbackApp(controller: controller));
    for (final label in ['Мои карты', 'Импорт', 'Настройки', 'Главная']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
}
