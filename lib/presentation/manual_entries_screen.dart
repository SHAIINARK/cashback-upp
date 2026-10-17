import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../logic/cashback_controller.dart';
import '../logic/import_period.dart';
import 'widgets.dart';

class ManualEntriesScreen extends StatefulWidget {
  const ManualEntriesScreen({super.key, required this.controller});
  final CashbackController controller;
  @override
  State<ManualEntriesScreen> createState() => _ManualEntriesScreenState();
}

class _ManualEntriesScreenState extends State<ManualEntriesScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось сохранить данные. Попробуйте ещё раз.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editCard([BankCard? card]) async {
    final result =
        await showDialog<({Bank bank, String name, RewardType rewardType})>(
          context: context,
          builder: (_) =>
              _CardDialog(card: card, cards: widget.controller.cards),
        );
    if (result == null) return;
    await _run(
      () => widget.controller.saveCard(
        BankCard(
          id: card?.id ?? widget.controller.newId(),
          bank: result.bank,
          name: result.name,
          rewardType: result.rewardType,
        ),
      ),
    );
  }

  Future<void> _editCategory(
    BankCard card, [
    CashbackMonth? period,
    CashbackCategory? category,
  ]) async {
    final result =
        await showDialog<
          ({
            CashbackMonth period,
            String name,
            double percent,
            RewardType rewardType,
            bool isUpTo,
            String notes,
          })
        >(
          context: context,
          builder: (_) => _CategoryDialog(
            card: card,
            period: period ?? widget.controller.month,
            category: category,
          ),
        );
    if (result == null) return;
    await _run(
      () => widget.controller.saveCategory(
        card.id,
        result.period,
        CashbackCategory(
          id: category?.id ?? widget.controller.newId(),
          originalName: result.name,
          percent: result.percent,
          rewardType: result.rewardType,
          isUpTo: result.isUpTo,
          notes: result.notes,
        ),
      ),
    );
  }

  Future<bool> _confirm(String title, String detail) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(detail),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final cards = widget.controller.cards;
      return Scaffold(
        appBar: AppBar(title: const Text('Мои карты и категории')),
        body: SafeArea(
          child: PageBody(
            children: [
              const Text(
                'При импорте достаточно выбрать банк: карта появится автоматически. Добавляйте отдельную карту, только если у вас несколько карт одного банка. Номер карты не нужен.',
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : () => _editCard(),
                icon: const Icon(Icons.add),
                label: const Text('Добавить карту'),
              ),
              const SizedBox(height: 20),
              if (cards.isEmpty)
                const EmptyState(
                  icon: Icons.credit_card_outlined,
                  title: 'Карт пока нет',
                  description:
                      'Добавьте скриншот категорий или создайте карту вручную.',
                ),
              for (final card in cards) ...[
                SurfacePanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${card.bank.label}${cards.where((item) => item.bank == card.bank).length > 1 || !card.id.startsWith('auto-') ? ' · ${card.name}' : ''}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Действия с картой',
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await _editCard(card);
                                return;
                              }
                              if (await _confirm(
                                'Удалить карту?',
                                'Её категории за все месяцы тоже будут удалены.',
                              )) {
                                await _run(
                                  () => widget.controller.deleteCard(card.id),
                                );
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'edit',
                                child: Text('Переименовать'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Удалить карту'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Text(card.rewardType.label),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: _busy ? null : () => _editCategory(card),
                        icon: const Icon(Icons.add),
                        label: const Text('Добавить категорию'),
                      ),
                      for (final set in widget.controller.allSets.where(
                        (set) => set.cardId == card.id,
                      )) ...[
                        const Divider(height: 24),
                        Text(
                          'Месяц ${set.period.month}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        for (final category in set.categories)
                          Material(
                            type: MaterialType.transparency,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(category.originalName),
                              subtitle: Text(
                                '${category.isUpTo ? 'До ' : ''}${category.percent}% · ${category.rewardType.label}${category.notes.isEmpty ? '' : '\n${category.notes}'}',
                              ),
                              isThreeLine: category.notes.isNotEmpty,
                              onTap: _busy
                                  ? null
                                  : () => _editCategory(
                                      card,
                                      set.period,
                                      category,
                                    ),
                              trailing: IconButton(
                                tooltip: 'Удалить категорию',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: _busy
                                    ? null
                                    : () async {
                                        if (await _confirm(
                                          'Удалить категорию?',
                                          category.originalName,
                                        )) {
                                          await _run(
                                            () => widget.controller
                                                .deleteCategory(
                                                  card.id,
                                                  set.period,
                                                  category.id,
                                                ),
                                          );
                                        }
                                      },
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class _CardDialog extends StatefulWidget {
  const _CardDialog({this.card, required this.cards});
  final BankCard? card;
  final List<BankCard> cards;
  @override
  State<_CardDialog> createState() => _CardDialogState();
}

class _CardDialogState extends State<_CardDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.card?.name ?? '');
  late final _customBank = TextEditingController(
    text: widget.card?.bank.isCustom == true ? widget.card!.bank.label : '',
  );
  late Bank _bank = widget.card?.bank ?? Bank.alfa;
  late bool _useCustomBank = widget.card?.bank.isCustom ?? false;
  late RewardType _reward = widget.card?.rewardType ?? RewardType.rubles;
  Bank get _effectiveBank =>
      _useCustomBank ? Bank.named(_customBank.text) : _bank;

  @override
  void dispose() {
    _name.dispose();
    _customBank.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.card == null ? 'Добавить карту' : 'Название карты'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _useCustomBank ? '__custom__' : _bank.name,
              decoration: const InputDecoration(labelText: 'Банк'),
              items: [
                for (final bank in Bank.withSaved(
                  widget.cards.map((card) => card.bank),
                ))
                  DropdownMenuItem(value: bank.name, child: Text(bank.label)),
                const DropdownMenuItem(
                  value: '__custom__',
                  child: Text('Ввести другой банк'),
                ),
              ],
              onChanged: widget.card == null
                  ? (value) => setState(() {
                      _useCustomBank = value == '__custom__';
                      if (!_useCustomBank) {
                        _bank = Bank.withSaved(
                          widget.cards.map((card) => card.bank),
                        ).firstWhere((bank) => bank.name == value);
                      }
                      if (!_useCustomBank && _bank == Bank.sber) {
                        _reward = RewardType.sberSpasibo;
                      }
                      if ((_useCustomBank || _bank != Bank.sber) &&
                          _reward == RewardType.sberSpasibo) {
                        _reward = RewardType.rubles;
                      }
                    })
                  : null,
            ),
            if (_useCustomBank) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customBank,
                enabled: widget.card == null || widget.card!.bank.isCustom,
                maxLength: 60,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Название банка',
                  hintText: 'Как вы хотите его видеть',
                ),
                validator: (value) {
                  try {
                    Bank.named(value ?? '');
                    return null;
                  } catch (_) {
                    return 'Введите название банка до 60 символов';
                  }
                },
              ),
            ],
            TextFormField(
              controller: _name,
              autofocus: true,
              maxLength: 60,
              decoration: InputDecoration(
                labelText:
                    widget.cards.any(
                      (card) =>
                          card.bank ==
                              (widget.card?.bank ??
                                  (_useCustomBank ? null : _bank)) &&
                          card.id != widget.card?.id,
                    )
                    ? 'Как отличать эту карту?'
                    : 'Название карты',
                hintText: 'Например, дебетовая или кредитная',
              ),
              validator: (value) {
                final name = value?.trim() ?? '';
                if (name.isEmpty) return 'Введите название';
                Bank bank;
                try {
                  bank = _effectiveBank;
                } catch (_) {
                  return null;
                }
                if (widget.cards.any(
                  (card) =>
                      card.bank == bank &&
                      card.id != widget.card?.id &&
                      card.name.toLowerCase() == name.toLowerCase(),
                )) {
                  return 'У этого банка уже есть карта с таким названием';
                }
                return null;
              },
            ),
            DropdownButtonFormField<RewardType>(
              key: ValueKey(_reward),
              initialValue: _reward,
              decoration: const InputDecoration(labelText: 'Вознаграждение'),
              items: [
                for (final type in RewardType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: widget.card == null
                  ? (value) => setState(() => _reward = value!)
                  : null,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, (
              bank: _effectiveBank,
              name: _name.text.trim(),
              rewardType: _reward,
            ));
          }
        },
        child: const Text('Сохранить'),
      ),
    ],
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({
    required this.card,
    required this.period,
    this.category,
  });
  final BankCard card;
  final CashbackMonth period;
  final CashbackCategory? category;
  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.category?.originalName ?? '',
  );
  late final _rate = TextEditingController(
    text: widget.category?.percent.toString() ?? '',
  );
  late final _notes = TextEditingController(text: widget.category?.notes ?? '');
  late int _month = widget.period.month;
  late int _year = widget.period.year;
  late bool _upTo = widget.category?.isUpTo ?? false;
  late RewardType _reward =
      widget.category?.rewardType ?? widget.card.rewardType;
  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.category == null ? 'Добавить категорию' : 'Изменить категорию',
    ),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${widget.card.bank.label} · ${widget.card.name}'),
            const SizedBox(height: 12),
            DropdownButtonFormField<CashbackMonth>(
              initialValue: CashbackMonth(_year, _month),
              decoration: const InputDecoration(labelText: 'Месяц'),
              items: [
                for (final period in [
                  ...importMonthChoices(),
                  if (widget.category != null &&
                      !importMonthChoices().contains(widget.period))
                    widget.period,
                ])
                  DropdownMenuItem(
                    value: period,
                    child: Text(importMonthLabel(period)),
                  ),
              ],
              onChanged: widget.category == null
                  ? (value) {
                      _month = value!.month;
                      _year = value.year;
                    }
                  : null,
            ),
            TextFormField(
              controller: _name,
              maxLength: 100,
              decoration: const InputDecoration(labelText: 'Точное название'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Введите категорию'
                  : null,
            ),
            TextFormField(
              controller: _rate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Процент'),
              validator: (value) {
                final rate = double.tryParse(
                  (value ?? '').replaceAll(',', '.'),
                );
                return rate == null || !rate.isFinite || rate < 0 || rate > 100
                    ? 'От 0 до 100'
                    : null;
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('До указанного процента'),
              value: _upTo,
              onChanged: (value) => setState(() => _upTo = value),
            ),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              maxLength: 300,
              decoration: const InputDecoration(
                labelText: 'Условия или примечание',
              ),
            ),
            DropdownButtonFormField<RewardType>(
              initialValue: _reward,
              decoration: const InputDecoration(labelText: 'Вознаграждение'),
              items: [
                for (final type in RewardType.values)
                  DropdownMenuItem(value: type, child: Text(type.label)),
              ],
              onChanged: (value) => setState(() => _reward = value!),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          _form.currentState!.save();
          Navigator.pop(context, (
            period: CashbackMonth(_year, _month),
            name: _name.text.trim(),
            percent: double.parse(_rate.text.replaceAll(',', '.')),
            rewardType: _reward,
            isUpTo: _upTo,
            notes: _notes.text.trim(),
          ));
        },
        child: const Text('Сохранить'),
      ),
    ],
  );
}
