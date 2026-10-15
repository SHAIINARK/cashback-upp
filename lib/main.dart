import 'package:flutter/material.dart';

import 'app/app.dart';
import 'data/local_cashback_repository.dart';
import 'logic/cashback_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = LocalCashbackRepository();
  try {
    await repository.load();
    runApp(CashbackApp(controller: CashbackController(repository)));
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Не удалось открыть сохранённые данные. Данные не изменены. Попробуйте перезапустить приложение.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
