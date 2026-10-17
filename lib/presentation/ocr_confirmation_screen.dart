import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../logic/bank_screenshot_parser.dart';
import '../logic/cashback_controller.dart';
import '../logic/import_review_draft.dart';
import '../logic/import_period.dart';
import '../logic/ocr_import_controller.dart';
import 'suggestion_catalog.dart';
import 'suggestion_form_field.dart';
import 'widgets.dart';

Future<ReviewRow?> showImportCategoryEditor(
  BuildContext context, {
  required RewardType defaultReward,
  required String defaultCustomRewardName,
  required List<String> categorySuggestions,
  required List<String> notesSuggestions,
  required List<String> rewardSuggestions,
  ReviewRow? row,
}) => showDialog<ReviewRow>(
  context: context,
  builder: (_) => _ReviewRowDialog(
    row: row,
    defaultReward: defaultReward,
    defaultCustomRewardName: defaultCustomRewardName,
    categorySuggestions: categorySuggestions,
    notesSuggestions: notesSuggestions,
    rewardSuggestions: rewardSuggestions,
  ),
);

class OcrConfirmationScreen extends StatefulWidget {
  const OcrConfirmationScreen({
    super.key,
    required this.result,
    required this.controller,
    this.initialBank,
    this.initialPeriod,
    this.initialCardId,
  });
  final ScreenshotResult result;
  final CashbackController controller;
  final Bank? initialBank;
  final CashbackMonth? initialPeriod;
  final String? initialCardId;

  @override
  State<OcrConfirmationScreen> createState() => _OcrConfirmationScreenState();
}

class _OcrConfirmationScreenState extends State<OcrConfirmationScreen> {
  late ImportReviewDraft _draft;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final parsed = widget.result.document == null
        ? widget.result.draft!
        : BankScreenshotParser().parse(
            widget.result.document!,
            bankHint: widget.initialBank,
          );
    _draft = ImportReviewDraft(parsed, bank: widget.initialBank);
    if (widget.initialPeriod != null) {
      _draft.month = widget.initialPeriod!.month;
      _draft.year = widget.initialPeriod!.year;
    }
    _draft.cardId = widget.initialCardId;
  }

  Future<void> _changeBank(Bank bank) async {
    if (bank == _draft.bank) return;
    if (_draft.rows.isNotEmpty) {
      final reset = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Сменить банк?'),
          content: const Text(
            'Категории будут разобраны заново. Правки и отметки на этом скриншоте сбросятся.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Сменить'),
            ),
          ],
        ),
      );
      if (reset != true || !mounted) return;
    }
    final previousPeriod = _draft.month == null
        ? null
        : importPeriod(_draft.month!, year: _draft.year);
    final parsed = widget.result.document == null
        ? widget.result.draft!
        : BankScreenshotParser().parse(widget.result.document!, bankHint: bank);
    setState(() {
      _draft = ImportReviewDraft(parsed, bank: bank);
      final period = previousPeriod ?? widget.initialPeriod;
      if (period != null) {
        _draft.month = period.month;
        _draft.year = period.year;
      }
    });
  }

  Future<void> _enterBank() async {
    final form = GlobalKey<FormState>();
    final name = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Название банка'),
        content: Form(
          key: form,
          child: SuggestionFormField(
            controller: name,
            suggestions: Bank.withSaved(
              widget.controller.cards.map((card) => card.bank),
            ).map((bank) => bank.label).toList(),
            label: 'Название банка',
            hint: 'Введите или выберите банк',
            autofocus: true,
            maxLength: 60,
            validator: (value) {
              try {
                Bank.named(value ?? '');
                return null;
              } catch (_) {
                return 'Введите название до 60 символов';
              }
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(dialogContext, name.text.trim());
              }
            },
            child: const Text('Выбрать'),
          ),
        ],
      ),
    );
    name.dispose();
    if (entered != null && mounted) await _changeBank(Bank.named(entered));
  }

  Future<void> _editRow([int? index]) async {
    final card = widget.controller.cards
        .where((item) => item.id == _draft.cardId)
        .firstOrNull;
    final reward = index == null
        ? card?.rewardType ??
              (_draft.bank == Bank.sber
                  ? RewardType.sberSpasibo
                  : RewardType.rubles)
        : _draft.rows[index].rewardType;
    final result = await showDialog<ReviewRow>(
      context: context,
      builder: (_) => _ReviewRowDialog(
        row: index == null ? null : _draft.rows[index],
        defaultReward: reward,
        defaultCustomRewardName: card?.customRewardName ?? '',
        categorySuggestions: categorySuggestions([
          ...widget.controller.learnedCategorySuggestions,
          ..._draft.rows.map((row) => row.name),
          ...widget.controller.allSets.expand(
            (set) => set.categories.map((category) => category.originalName),
          ),
        ]),
        notesSuggestions: widget.controller.allSets
            .expand((set) => set.categories)
            .map((category) => category.notes)
            .where((note) => note.trim().isNotEmpty)
            .toSet()
            .toList(),
        rewardSuggestions: {
          ..._draft.rows.map((row) => row.rewardLabel),
          ...widget.controller.allSets
              .expand((set) => set.categories)
              .map((category) => category.rewardLabel),
        }.where((label) => label.isNotEmpty).toList(),
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _draft.rows.add(result);
      } else {
        _draft.rows[index] = result;
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final error = _draft.validate(widget.controller.cards);
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final period = CashbackMonth(_draft.year!, _draft.month!);
    if (!importMonthChoices().contains(period)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Можно сохранить только предыдущий, текущий или следующий месяц.',
          ),
        ),
      );
      return;
    }
    final matchingCards = widget.controller.cards
        .where((item) => item.bank == _draft.bank)
        .toList();
    final card = _draft.cardId == null
        ? matchingCards.firstOrNull
        : matchingCards.where((item) => item.id == _draft.cardId).firstOrNull;
    final incoming = [
      for (final row in _draft.selectedRows)
        row.toCategory(widget.controller.newId()),
    ];
    final existing = card == null
        ? null
        : widget.controller.setFor(card.id, period);
    final existingNames =
        existing?.categories
            .map((item) => item.originalName.trim().toLowerCase())
            .toSet() ??
        <String>{};
    final duplicate = incoming.any(
      (item) => existingNames.contains(item.originalName.trim().toLowerCase()),
    );
    final mode = await showDialog<ImportSaveMode>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          existing == null ? 'Сохранить категории?' : 'Набор уже есть',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_draft.bank!.label}${matchingCards.length > 1 ? ' · ${card?.name ?? ''}' : ''} · ${importMonthLabel(period)}',
              ),
              const SizedBox(height: 10),
              Text('Новые выбранные строки: ${incoming.length}'),
              for (final item in incoming)
                Text(
                  '• ${item.originalName} — ${formatCashbackPercent(item.percent)}%',
                ),
              if (existing != null) ...[
                const SizedBox(height: 14),
                Text('Уже сохранено: ${existing.categories.length}'),
                for (final item in existing.categories)
                  Text(
                    '• ${item.originalName} — ${formatCashbackPercent(item.percent)}%',
                  ),
                if (duplicate)
                  const Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: Text(
                      'Есть совпадающие названия. Добавление недоступно; можно отменить или заменить весь набор.',
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          if (existing != null && !duplicate)
            TextButton(
              onPressed: () => Navigator.pop(context, ImportSaveMode.append),
              child: const Text('Добавить'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              existing == null ? ImportSaveMode.create : ImportSaveMode.replace,
            ),
            child: Text(existing == null ? 'Сохранить' : 'Заменить весь набор'),
          ),
        ],
      ),
    );
    if (mode == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.controller.saveImportedCategories(
        cardId: _draft.cardId,
        bank: _draft.bank!,
        period: period,
        incoming: incoming,
        mode: mode,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Не удалось сохранить набор. Данные не изменены. Попробуйте ещё раз.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = widget.controller.cards
        .where((card) => card.bank == _draft.bank)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Подтвердить категории')),
      body: SafeArea(
        child: PageBody(
          children: [
            const Text(
              'Проверьте найденные категории. Если банк показывает и предложения, отметьте только уже выбранные.',
            ),
            ExpansionTile(
              title: const Text('Посмотреть скриншот'),
              children: [
                Image.file(
                  File(widget.result.path),
                  cacheWidth: 1080,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Text('Предпросмотр недоступен'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Bank>(
              key: ValueKey('bank-${_draft.bank}'),
              initialValue: _draft.bank,
              decoration: const InputDecoration(
                labelText: 'Банк',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final bank in Bank.withSaved([
                  ...widget.controller.cards.map((card) => card.bank),
                  if (_draft.bank != null) _draft.bank!,
                ]))
                  DropdownMenuItem(value: bank, child: Text(bank.label)),
              ],
              onChanged: _saving
                  ? null
                  : (value) {
                      if (value != null) _changeBank(value);
                    },
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving ? null : _enterBank,
                icon: const Icon(Icons.add),
                label: const Text('Ввести другой банк'),
              ),
            ),
            const SizedBox(height: 12),
            if (_draft.bank != null && cards.length > 1) ...[
              const Text('У вас несколько карт этого банка. Выберите нужную.'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey('card-${_draft.bank}-${_draft.cardId}'),
                initialValue: cards.any((card) => card.id == _draft.cardId)
                    ? _draft.cardId
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Ваша карта',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final card in cards)
                    DropdownMenuItem(value: card.id, child: Text(card.name)),
                ],
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _draft.cardId = value),
              ),
            ],
            const SizedBox(height: 16),
            DropdownButtonFormField<CashbackMonth>(
              key: ValueKey('month-${_draft.year}-${_draft.month}'),
              initialValue: _draft.month == null || _draft.year == null
                  ? null
                  : importMonthChoices()
                        .where(
                          (period) =>
                              period.month == _draft.month &&
                              period.year == _draft.year,
                        )
                        .firstOrNull,
              decoration: const InputDecoration(
                labelText: 'Месяц',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final period in importMonthChoices())
                  DropdownMenuItem(
                    value: period,
                    child: Text(importMonthLabel(period)),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() {
                      _draft.month = value?.month;
                      _draft.year = value?.year;
                    }),
            ),
            if (_draft.month != null &&
                _draft.year != null &&
                !importMonthChoices().contains(
                  CashbackMonth(_draft.year!, _draft.month!),
                )) ...[
              const SizedBox(height: 8),
              const Text(
                'Месяц на скриншоте вне доступных трёх месяцев. Выберите подходящий период.',
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Категории · отмечено ${_draft.selectedRows.length}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            for (var index = 0; index < _draft.rows.length; index++) ...[
              SurfacePanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Material(
                      type: MaterialType.transparency,
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        value: _draft.rows[index].selected,
                        onChanged: _saving
                            ? null
                            : (value) => setState(
                                () => _draft.rows[index].selected =
                                    value ?? false,
                              ),
                        title: Text(_draft.rows[index].name),
                        subtitle: Text(
                          '${_draft.rows[index].isUpTo ? 'до ' : ''}${formatCashbackPercent(_draft.rows[index].percent)}% · ${_draft.rows[index].rewardLabel}',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _saving ? null : () => _editRow(index),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Исправить'),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Убрать строку из черновика',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _saving
                              ? null
                              : () =>
                                    setState(() => _draft.rows.removeAt(index)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              onPressed: _saving ? null : () => _editRow(),
              icon: const Icon(Icons.add),
              label: const Text('Добавить пропущенную категорию'),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.check),
              label: Text(_saving ? 'Сохраняем…' : 'Проверить и сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewRowDialog extends StatefulWidget {
  const _ReviewRowDialog({
    required this.defaultReward,
    required this.defaultCustomRewardName,
    required this.categorySuggestions,
    required this.notesSuggestions,
    required this.rewardSuggestions,
    this.row,
  });
  final ReviewRow? row;
  final RewardType defaultReward;
  final String defaultCustomRewardName;
  final List<String> categorySuggestions;
  final List<String> notesSuggestions;
  final List<String> rewardSuggestions;
  @override
  State<_ReviewRowDialog> createState() => _ReviewRowDialogState();
}

class _ReviewRowDialogState extends State<_ReviewRowDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.row?.name ?? '');
  late final _rate = TextEditingController(
    text: widget.row == null ? '' : formatCashbackPercent(widget.row!.percent),
  );
  late final _notes = TextEditingController(text: widget.row?.notes ?? '');
  late RewardType _reward = widget.row?.rewardType ?? widget.defaultReward;
  late final _rewardInput = TextEditingController(
    text:
        widget.row?.rewardLabel ??
        (widget.defaultReward == RewardType.custom
            ? widget.defaultCustomRewardName
            : widget.defaultReward.label),
  );
  late bool _upTo = widget.row?.isUpTo ?? false;

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    _notes.dispose();
    _rewardInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.row == null ? 'Добавить категорию' : 'Исправить категорию',
    ),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SuggestionFormField(
              controller: _name,
              suggestions: widget.categorySuggestions,
              label: 'Точное название',
              hint: 'Начните вводить или выберите подсказку',
              maxLength: 100,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Введите название'
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
            SuggestionFormField(
              controller: _rewardInput,
              suggestions: {
                RewardType.rubles.label,
                RewardType.otherPoints.label,
                RewardType.sberSpasibo.label,
                ...widget.rewardSuggestions,
              }.toList(),
              label: 'Вознаграждение',
              hint: 'Выберите вариант или введите свой',
              maxLength: 60,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Укажите вознаграждение'
                  : null,
              onChanged: _updateReward,
              onSuggestionSelected: _updateReward,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('До указанного процента'),
              value: _upTo,
              onChanged: (value) => setState(() => _upTo = value),
            ),
            SuggestionFormField(
              controller: _notes,
              suggestions: widget.notesSuggestions,
              label: 'Условия или примечание',
              hint: 'Можно начать вводить или выбрать подсказку',
              maxLength: 300,
              maxLines: 2,
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
          Navigator.pop(
            context,
            ReviewRow(
              name: _name.text.trim(),
              percent: double.parse(_rate.text.replaceAll(',', '.')),
              rewardType: _reward,
              customRewardName: _reward == RewardType.custom
                  ? _rewardInput.text.trim()
                  : '',
              isUpTo: _upTo,
              notes: _notes.text.trim(),
              // Newly entered categories are intentional user choices.
              selected: widget.row?.selected ?? true,
            ),
          );
        },
        child: const Text('Готово'),
      ),
    ],
  );

  void _updateReward(String value) {
    final normalized = value.trim().toLowerCase();
    final known = RewardType.values
        .where((type) => type != RewardType.custom)
        .where((type) => type.label.toLowerCase() == normalized)
        .firstOrNull;
    setState(() {
      _reward = known ?? RewardType.custom;
    });
  }
}
