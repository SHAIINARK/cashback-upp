import 'package:flutter/material.dart';

import 'app/app.dart';
import 'data/empty_cashback_repository.dart';
import 'logic/cashback_controller.dart';

void main() => runApp(
  CashbackApp(controller: CashbackController(EmptyCashbackRepository())),
);
