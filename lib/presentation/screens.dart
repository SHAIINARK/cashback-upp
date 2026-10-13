import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../domain/models.dart';
import '../logic/cashback_controller.dart';
import 'widgets.dart';

export 'ocr_import_screen.dart';
export 'ocr_review_screen.dart';

const _months = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onImport,
  });
  final CashbackController controller;
  final VoidCallback onImport;
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const PageHeading(
        eyebrow: 'КЭШБЭК РЯДОМ',
        title: 'Чем платить\nсегодня?',
        subtitle: 'Категории ваших карт — в одном месте.',
      ),
      Row(
        children: [
          IconButton(
            tooltip: 'Предыдущий месяц',
            onPressed: () => controller.moveMonth(-1),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Text(
              '${_months[controller.month.month - 1]} ${controller.month.year}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          IconButton(
            tooltip: 'Следующий месяц',
            onPressed: () => controller.moveMonth(1),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
      const SizedBox(height: 20),
      EmptyState(
        icon: Icons.wallet_outlined,
        title: 'Здесь будут ваши категории',
        description: 'Добавьте выбранный кэшбэк, чтобы видеть проценты по своим картам. Сейчас категории ещё не загружены.',
        action: FilledButton.icon(
          onPressed: onImport,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Как добавить категории'),
        ),
      ),
      const SizedBox(height: 20),
      SurfacePanel(
        color: const Color(0xFFE9EFE7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Процент — только часть условий. Рубли и бонусы будут обозначены отдельно, а ограничения — рядом с категорией.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class CardsScreen extends StatelessWidget {
  const CardsScreen({super.key, required this.onImport});
  final VoidCallback onImport;
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const PageHeading(
        eyebrow: 'ВАШ КОШЕЛЁК',
        title: 'Мои карты',
        subtitle: 'Только ваши карты и выбранные категории.',
      ),
      EmptyState(
        icon: Icons.credit_card_rounded,
        title: 'Карты ещё не добавлены',
        description: 'После добавления здесь появятся банк, название карты и категории на выбранный месяц.',
        action: OutlinedButton(
          onPressed: onImport,
          child: const Text('О добавлении карт'),
        ),
      ),
      const SizedBox(height: 28),
      Text(
        'Банки первой версии',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 8),
      const Text('Это список поддерживаемых банков, а не добавленные карты.'),
      const SizedBox(height: 16),
      SurfacePanel(
        child: Column(
          children: [
            for (final bank in Bank.values) ...[
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _bankColor(bank).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _bankMark(bank),
                      style: TextStyle(
                        color: _bankColor(bank),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      bank.label,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
              if (bank != Bank.values.last)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1),
                ),
            ],
          ],
        ),
      ),
    ],
  );
}

Color _bankColor(Bank bank) => switch (bank) {
  Bank.alfa => const Color(0xFFCF3434),
  Bank.tbank => const Color(0xFF806700),
  Bank.sber => const Color(0xFF218447),
  Bank.vtb => const Color(0xFF2464AD),
  Bank.ozon => const Color(0xFF195FFF),
};
String _bankMark(Bank bank) => switch (bank) {
  Bank.alfa => 'А',
  Bank.tbank => 'Т',
  Bank.sber => 'С',
  Bank.vtb => 'В',
  Bank.ozon => 'О',
};

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const PageHeading(
        eyebrow: 'О ПРИЛОЖЕНИИ',
        title: 'Настройки',
        subtitle: 'Простая подсказка для ваших покупок.',
      ),
      SurfacePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Кэшбэк рядом', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Версия 0.2.0 · проверка распознавания'),
            const Divider(height: 32),
            const _SettingRow(
              icon: Icons.language,
              title: 'Язык',
              subtitle: 'Русский',
            ),
            const SizedBox(height: 20),
            const _SettingRow(
              icon: Icons.light_mode_outlined,
              title: 'Оформление',
              subtitle: 'Светлое',
            ),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const SurfacePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingRow(
              icon: Icons.privacy_tip_outlined,
              title: 'Без доступа к банку',
              subtitle: 'Приложение не подключается к банковским аккаунтам и не запрашивает реквизиты карт.',
            ),
            SizedBox(height: 20),
            _SettingRow(
              icon: Icons.savings_outlined,
              title: 'Рубли и бонусы отдельно',
              subtitle: 'Бонусы Спасибо не считаются рублями. Названия категорий разных банков не объединяются автоматически.',
            ),
          ],
        ),
      ),
    ],
  );
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: AppColors.primary),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(subtitle),
          ],
        ),
      ),
    ],
  );
}
