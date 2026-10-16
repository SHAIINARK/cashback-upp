import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../domain/models.dart';
import '../logic/cashback_controller.dart';
import 'widgets.dart';

export 'ocr_import_screen.dart';
export 'ocr_review_screen.dart';
export 'manual_entries_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.controller,
    required this.onImport,
    required this.onManual,
  });
  final CashbackController controller;
  final VoidCallback onImport;
  final VoidCallback onManual;
  static const _monthNames = [
    'янв.',
    'фев.',
    'мар.',
    'апр.',
    'май',
    'июн.',
    'июл.',
    'авг.',
    'сен.',
    'окт.',
    'ноя.',
    'дек.',
  ];
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const PageHeading(
        eyebrow: 'КЭШБЭК РЯДОМ',
        title: 'Чем платить\nсегодня?',
        subtitle: 'Категории ваших карт — в одном месте.',
      ),
      FilledButton.icon(
        onPressed: onManual,
        icon: const Icon(Icons.edit_outlined),
        label: const Text('Мои карты и категории'),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          for (final offset in [-1, 0, 1])
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: offset == 1 ? 0 : 8),
                child: _MonthPill(
                  label: offset == 0
                      ? 'Текущий'
                      : offset < 0
                      ? 'Предыдущий'
                      : 'Следующий',
                  month: controller.anchorMonth.shift(offset),
                  selected:
                      controller.month == controller.anchorMonth.shift(offset),
                  onTap: () => controller.moveMonth(offset),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 22),
      _HomeCashbackView(controller: controller, onImport: onImport),
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

class _MonthPill extends StatelessWidget {
  const _MonthPill({
    required this.label,
    required this.month,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final CashbackMonth month;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.primary : const Color(0xFFE2E8E1),
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              HomeScreen._monthNames[month.month - 1],
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _HomeCashbackView extends StatefulWidget {
  const _HomeCashbackView({required this.controller, required this.onImport});
  final CashbackController controller;
  final VoidCallback onImport;
  @override
  State<_HomeCashbackView> createState() => _HomeCashbackViewState();
}

class _HomeCashbackViewState extends State<_HomeCashbackView> {
  bool _byCard = false;
  String? _cardId;

  @override
  Widget build(BuildContext context) {
    final sets = widget.controller.selectedSets;
    final cards = widget.controller.selectedCards;
    final usable =
        sets
            .expand((set) => set.categories)
            .where((category) => category.rewardType == RewardType.rubles)
            .toList()
          ..sort((a, b) => b.percent.compareTo(a.percent));
    final cardById = {
      for (final card in widget.controller.cards) card.id: card,
    };
    final bankCategories = [
      for (final set in sets)
        for (final category in set.categories.where(
          (item) => item.rewardType == RewardType.rubles,
        ))
          (category: category, card: cardById[set.cardId]),
    ]..sort((a, b) => b.category.percent.compareTo(a.category.percent));
    final selectedCard = cards.any((card) => card.id == _cardId)
        ? _cardId
        : cards.firstOrNull?.id;
    final cardSet = selectedCard == null
        ? null
        : sets.where((set) => set.cardId == selectedCard).firstOrNull;
    final otherSets = sets
        .expand((set) => set.categories)
        .where((category) => category.rewardType != RewardType.rubles)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              label: Text('По категориям'),
              icon: Icon(Icons.category_outlined),
            ),
            ButtonSegment(
              value: true,
              label: Text('По картам'),
              icon: Icon(Icons.credit_card_outlined),
            ),
          ],
          selected: {_byCard},
          onSelectionChanged: (values) =>
              setState(() => _byCard = values.first),
        ),
        const SizedBox(height: 16),
        if (_byCard && cards.isNotEmpty) ...[
          DropdownButtonFormField<String>(
            initialValue: selectedCard,
            decoration: const InputDecoration(labelText: 'Карта'),
            items: [
              for (final card in cards)
                DropdownMenuItem(
                  value: card.id,
                  child: Text(
                    '${card.bank.label}${widget.controller.cards.where((item) => item.bank == card.bank).length > 1 || !card.id.startsWith('auto-') ? ' · ${card.name}' : ''}',
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _cardId = value),
          ),
          const SizedBox(height: 12),
          if (cardSet == null || cardSet.categories.isEmpty)
            const _CompactEmpty(message: 'Для этой карты пока нет категорий.')
          else if (cardSet.categories.any(
            (item) => item.rewardType == RewardType.rubles,
          ))
            _CategoryList(
              categories: [
                ...cardSet.categories.where(
                  (item) => item.rewardType == RewardType.rubles,
                ),
              ]..sort((a, b) => b.percent.compareTo(a.percent)),
            ),
          if (cardSet != null &&
              cardSet.categories.any(
                (item) => item.rewardType != RewardType.rubles,
              )) ...[
            const SizedBox(height: 18),
            Text(
              'Бонусы и баллы',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _CategoryList(
              categories: cardSet.categories
                  .where((item) => item.rewardType != RewardType.rubles)
                  .toList(),
            ),
          ],
        ] else if (_byCard || usable.isEmpty) ...[
          _CompactEmpty(
            message: _byCard
                ? 'В этом месяце нет добавленных карт.'
                : 'Добавьте выбранные категории, чтобы сравнить карты.',
            action: FilledButton.icon(
              onPressed: widget.onImport,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: const Text('Добавить скриншоты'),
            ),
          ),
        ] else ...[
          _CategoryList.entries(
            entries: bankCategories,
            cards: widget.controller.cards,
          ),
        ],
        if (otherSets.isNotEmpty) ...[
          const SizedBox(height: 18),
          Text(
            'Бонусы и баллы',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _CategoryList(categories: otherSets),
        ],
      ],
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({required this.categories})
    : entries = null,
      cards = const [];
  const _CategoryList.entries({required this.entries, required this.cards})
    : categories = null;
  final List<CashbackCategory>? categories;
  final List<({CashbackCategory category, BankCard? card})>? entries;
  final List<BankCard> cards;
  @override
  Widget build(BuildContext context) {
    final rows =
        entries ??
        [for (final category in categories!) (category: category, card: null)];
    return SurfacePanel(
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rows[i].category.originalName),
                      if (rows[i].card != null)
                        Text(
                          '${rows[i].card!.bank.label}${cards.where((card) => card.bank == rows[i].card!.bank).length > 1 || !rows[i].card!.id.startsWith('auto-') ? ' · ${rows[i].card!.name}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${rows[i].category.isUpTo ? 'до ' : ''}${rows[i].category.percent.toStringAsFixed(rows[i].category.percent % 1 == 0 ? 0 : 1)}% · ${rows[i].category.rewardType.label}',
                ),
              ],
            ),
            if (i != rows.length - 1) const Divider(height: 22),
          ],
        ],
      ),
    );
  }
}

class _CompactEmpty extends StatelessWidget {
  const _CompactEmpty({required this.message, this.action});
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => SurfacePanel(
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 16), action!],
      ],
    ),
  );
}

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
            const Text('Версия 0.5.2 · быстрый импорт'),
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
