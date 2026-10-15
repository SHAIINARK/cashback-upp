import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../domain/models.dart';
import '../domain/ocr_models.dart';
import '../logic/bank_screenshot_parser.dart';
import '../logic/ocr_import_controller.dart';
import '../logic/cashback_controller.dart';
import '../logic/import_period.dart';
import 'ocr_confirmation_screen.dart';
import 'widgets.dart';

class ImportReviewScreen extends StatefulWidget {
  const ImportReviewScreen({
    super.key,
    this.results = const [],
    this.controller,
  });
  final List<ScreenshotResult> results;
  final CashbackController? controller;
  @override
  State<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends State<ImportReviewScreen> {
  int _index = 0;
  final Map<int, Bank> _bankHints = {};
  final Map<int, String> _bankNames = {};
  final Set<int> _savedIndices = {};
  final Map<int, int> _monthOverrides = {};
  final Map<int, String> _cardIds = {};
  bool _saving = false;
  static const _months = [
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

  @override
  Widget build(BuildContext context) {
    if (widget.results.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Проверка импорта')),
        body: SafeArea(
          child: PageBody(
            children: [
              const EmptyState(
                icon: Icons.fact_check_outlined,
                title: 'Пока нечего проверять',
                description: 'Выберите скриншоты на экране импорта. Ни одной категории не сохранено.',
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Вернуться к импорту'),
              ),
            ],
          ),
        ),
      );
    }
    final result = widget.results[_index];
    final document = result.document;
    final detectedBank = result.draft?.bank;
    final selectedName = _bankNames[_index];
    final selectedBank = selectedName == null
        ? _bankHints[_index] ?? detectedBank
        : Bank.values.where((bank) => bank.label == selectedName).firstOrNull;
    final draft = document == null
        ? null
        : BankScreenshotParser().parse(document, bankHint: selectedBank);
    return Scaffold(
      appBar: AppBar(title: const Text('Проверка импорта')),
      body: SafeArea(
        child: PageBody(
          children: [
            Text(
              'Скриншот ${_index + 1} из ${widget.results.length}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            _ScreenshotNavigation(
              count: widget.results.length,
              selected: _index,
              onSelect: (index) => setState(() => _index = index),
            ),
            const SizedBox(height: 16),
            ExpansionTile(
              title: const Text('Посмотреть исходный скриншот'),
              children: [
                Image.file(
                  File(result.path),
                  cacheWidth: 1080,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) =>
                      const Text('Предпросмотр недоступен'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (result.error != null)
              EmptyState(
                icon: Icons.error_outline,
                title: 'Распознавание не удалось',
                description: result.error!,
              ),
            if (draft != null && document != null)
              ..._draftWidgets(
                context,
                draft,
                document,
                selectedName ?? selectedBank?.label ?? 'Выбрать банк',
                detectedBank == null && selectedName == null,
                selectedName != null && selectedBank == null,
                selectedBank,
                _monthOverrides[_index] ?? draft.month,
              ),
            const SizedBox(height: 24),
            if (_savedIndices.contains(_index))
              const Text(
                'Выбранные категории этого скриншота сохранены на телефоне.',
              )
            else
              Text(
                draft?.categories.any((item) => item.selectionUnknown) == true
                    ? 'Здесь показаны и выбранные, и предложенные категории. Нажмите «Исправить и сохранить», чтобы отметить выбранные.'
                    : 'Если всё верно, «Завершить проверку» сохранит найденные категории. Для исправлений откройте редактирование.',
              ),
            const SizedBox(height: 16),
            if (document != null && widget.controller != null) ...[
              FilledButton.icon(
                onPressed: () => _openConfirmation(result, selectedBank),
                icon: const Icon(Icons.edit_outlined),
                label: Text(
                  _savedIndices.contains(_index)
                      ? 'Проверить и сохранить снова'
                      : 'Исправить и сохранить',
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (widget.results.length > 1) ...[
              OutlinedButton.icon(
                onPressed: _index < widget.results.length - 1
                    ? () => setState(() => _index++)
                    : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Далее'),
              ),
              const SizedBox(height: 8),
            ],
            FilledButton(
              onPressed: _saving ? null : _finish,
              child: Text(_saving ? 'Сохраняем…' : 'Завершить проверку'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _saving
                  ? null
                  : () => Navigator.of(context).pop(_savedIndices.isNotEmpty),
              child: const Text('Выйти без сохранения новых категорий'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _draftWidgets(
    BuildContext context,
    ParsedScreenshot draft,
    OcrDocument document,
    String bankLabel,
    bool bankWasGuessed,
    bool unsupportedBank,
    Bank? selectedBank,
    int? selectedMonth,
  ) {
    return [
      Text(
        'Обработка: ${(document.elapsedMs / 1000).toStringAsFixed(1)} с · ${document.lines.length} строк',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: _openBankPicker,
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
        icon: const Icon(Icons.account_balance_outlined),
        label: Text(bankLabel, overflow: TextOverflow.ellipsis),
      ),
      if (bankWasGuessed) ...[
        const SizedBox(height: 8),
        const Text('Банк не распознан. Выберите его перед сохранением.'),
      ],
      if (unsupportedBank) ...[
        const SizedBox(height: 8),
        const Text(
          'Для этого банка нет отдельного распознавания. Проверьте результат вручную.',
        ),
      ],
      const SizedBox(height: 16),
      DropdownButtonFormField<int>(
        key: ValueKey('review-month-$_index-$selectedMonth'),
        initialValue: selectedMonth,
        decoration: const InputDecoration(labelText: 'Месяц'),
        items: [
          for (var month = 1; month <= 12; month++)
            DropdownMenuItem(value: month, child: Text(_months[month - 1])),
        ],
        onChanged: (month) {
          if (month != null) setState(() => _monthOverrides[_index] = month);
        },
      ),
      if (selectedBank != null &&
          (widget.controller?.cards
                      .where((card) => card.bank == selectedBank)
                      .length ??
                  0) >
              1) ...[
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('review-card-$_index-$selectedBank'),
          initialValue: _cardIds[_index],
          decoration: const InputDecoration(labelText: 'Карта этого банка'),
          items: [
            for (final card in widget.controller!.cards.where(
              (card) => card.bank == selectedBank,
            ))
              DropdownMenuItem(value: card.id, child: Text(card.name)),
          ],
          onChanged: (id) {
            if (id != null) setState(() => _cardIds[_index] = id);
          },
        ),
      ],
      const SizedBox(height: 16),
      for (final warning in draft.warnings)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(warning)),
            ],
          ),
        ),
      const SizedBox(height: 12),
      Text(
        'Найденные категории: ${draft.categories.length}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      for (final category in draft.categories)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SurfacePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.originalName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  '${category.isUpTo ? 'до ' : ''}${_rate(category.percent)}%${selectedBank == Bank.sber ? ' бонусами Спасибо' : ''}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (category.selectionUnknown) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Не подтверждено, что эта строка выбрана в банке.',
                  ),
                ],
                if (category.notes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(category.notes),
                ],
              ],
            ),
          ),
        ),
      ExpansionTile(
        title: const Text('Весь распознанный текст'),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: SelectableText(
              document.lines.map((line) => line.text).join('\n'),
            ),
          ),
        ],
      ),
    ];
  }

  Future<void> _openConfirmation(ScreenshotResult result, Bank? bank) async {
    final index = _index;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OcrConfirmationScreen(
          result: result,
          controller: widget.controller!,
          initialBank: bank,
          initialMonth: _monthOverrides[index],
          initialCardId: _cardIds[index],
        ),
      ),
    );
    if (saved == true && mounted) setState(() => _savedIndices.add(index));
  }

  Future<void> _finish() async {
    final controller = widget.controller;
    if (controller == null) {
      Navigator.of(context).pop();
      return;
    }
    final items = <QuickImportItem>[];
    for (var index = 0; index < widget.results.length; index++) {
      if (_savedIndices.contains(index)) continue;
      final result = widget.results[index];
      final document = result.document;
      if (document == null) {
        _needsCorrection(index, 'Не удалось прочитать скриншот.');
        return;
      }
      final selectedName = _bankNames[index];
      final bank = selectedName == null
          ? _bankHints[index] ?? result.draft?.bank
          : Bank.values.where((item) => item.label == selectedName).firstOrNull;
      if (bank == null) {
        _needsCorrection(index, 'Выберите банк для этого скриншота.');
        return;
      }
      final draft = BankScreenshotParser().parse(document, bankHint: bank);
      final month = _monthOverrides[index] ?? draft.month;
      if (month == null) {
        _needsCorrection(index, 'Выберите месяц для этого скриншота.');
        return;
      }
      if (draft.categories.isEmpty) {
        _needsCorrection(index, 'Категории не найдены. Исправьте результат.');
        return;
      }
      if (draft.categories.any((item) => item.selectionUnknown)) {
        _needsCorrection(
          index,
          'На этом экране есть предложения банка. Отметьте выбранные категории вручную.',
        );
        return;
      }
      final cards = controller.cards
          .where((card) => card.bank == bank)
          .toList();
      final cardId = _cardIds[index];
      if (cards.length > 1 && cardId == null) {
        _needsCorrection(index, 'Выберите карту этого банка.');
        return;
      }
      items.add(
        QuickImportItem(
          bank: bank,
          cardId: cardId,
          period: importPeriod(month, year: draft.year),
          categories: [
            for (final category in draft.categories)
              CashbackCategory(
                id: controller.newId(),
                originalName: category.originalName,
                percent: category.percent,
                rewardType: bank == Bank.sber
                    ? RewardType.sberSpasibo
                    : RewardType.rubles,
                isUpTo: category.isUpTo,
                notes: category.notes,
              ),
          ],
        ),
      );
    }
    if (items.isEmpty) {
      Navigator.of(context).pop(_savedIndices.isNotEmpty);
      return;
    }
    setState(() => _saving = true);
    try {
      await controller.saveQuickImport(items);
      if (mounted) Navigator.of(context).pop(true);
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось сохранить категории.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _needsCorrection(int index, String message) {
    setState(() => _index = index);
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openBankPicker() async {
    final index = _index;
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => const _BankPicker(),
    );
    if (!mounted || selected == null) return;
    final bank = Bank.values
        .where(
          (item) => item.label.toLowerCase() == selected.trim().toLowerCase(),
        )
        .firstOrNull;
    setState(() {
      _bankNames[index] = bank?.label ?? selected.trim();
      if (bank == null) {
        _bankHints.remove(index);
      } else {
        _bankHints[index] = bank;
      }
    });
  }

  String _rate(double value) => value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString().replaceAll('.', ',');
}

class _BankPicker extends StatefulWidget {
  const _BankPicker();

  @override
  State<_BankPicker> createState() => _BankPickerState();
}

class _BankPickerState extends State<_BankPicker> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final availableHeight = MediaQuery.sizeOf(context).height - inset - 24;
    final height = math.min(460.0, math.max(200.0, availableHeight));
    final matches = Bank.values.where(
      (bank) => bank.label.toLowerCase().contains(_query.trim().toLowerCase()),
    );
    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(bottom: inset),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Выберите банк',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Название банка',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => setState(() => _query = value),
                onSubmitted: (value) {
                  if (value.trim().isNotEmpty) {
                    Navigator.of(context).pop(value.trim());
                  }
                },
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    for (final bank in matches)
                      ListTile(
                        title: Text(bank.label),
                        onTap: () => Navigator.of(context).pop(bank.label),
                      ),
                    if (matches.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'В списке нет такого банка. Можно вписать его название.',
                        ),
                      ),
                  ],
                ),
              ),
              if (_query.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(_query.trim()),
                  child: const Text('Использовать введённое название'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScreenshotNavigation extends StatelessWidget {
  const _ScreenshotNavigation({
    required this.count,
    required this.selected,
    required this.onSelect,
  });
  final int count;
  final int selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton.filled(
        tooltip: 'Предыдущий скриншот',
        onPressed: selected > 0 ? () => onSelect(selected - 1) : null,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: .35),
          disabledForegroundColor: Colors.white,
        ),
        icon: const Icon(Icons.chevron_left),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 5,
          runSpacing: 4,
          children: [
            for (var index = 0; index < count; index++)
              SizedBox(
                width: 36,
                height: 36,
                child: OutlinedButton(
                  onPressed: () => onSelect(index),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: AppColors.primary,
                    side: BorderSide(
                      color: AppColors.primary,
                      width: selected == index ? 2 : 1,
                    ),
                    backgroundColor: selected == index
                        ? AppColors.primary.withValues(alpha: .10)
                        : Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('${index + 1}'),
                ),
              ),
          ],
        ),
      ),
      const SizedBox(width: 4),
      IconButton.filled(
        tooltip: 'Следующий скриншот',
        onPressed: selected < count - 1 ? () => onSelect(selected + 1) : null,
        style: IconButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: .35),
          disabledForegroundColor: Colors.white,
        ),
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );
}
