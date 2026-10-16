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

class _ImportReviewScreenState extends State<ImportReviewScreen>
    with WidgetsBindingObserver {
  int _index = 0;
  final Map<int, Bank> _bankHints = {};
  final Map<int, String> _bankNames = {};
  final Set<int> _savedIndices = {};
  final Map<int, CashbackMonth> _monthOverrides = {};
  final Map<int, String> _cardIds = {};
  final LayerLink _bankLayer = LayerLink();
  final GlobalKey _bankAnchorKey = GlobalKey();
  final TextEditingController _bankSearch = TextEditingController();
  final FocusNode _bankSearchFocus = FocusNode();
  OverlayEntry? _bankOverlay;
  bool _bankPickerOpen = false;
  bool _keyboardWasVisible = false;
  bool _saving = false;
  OcrDocument? _cachedDocument;
  Bank? _cachedBank;
  ParsedScreenshot? _cachedDraft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _bankOverlay?.remove();
    _bankOverlay?.dispose();
    _bankSearch.dispose();
    _bankSearchFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_bankPickerOpen) return;
      final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
      if (_keyboardWasVisible && !keyboardVisible) {
        _closeBankPicker();
      } else {
        _keyboardWasVisible = keyboardVisible;
        _bankOverlay?.markNeedsBuild();
      }
    });
  }

  CashbackMonth? _periodFor(ParsedScreenshot draft) =>
      draft.month == null ? null : importPeriod(draft.month!, year: draft.year);

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
    ParsedScreenshot? draft;
    if (document != null) {
      if (!identical(document, _cachedDocument) || selectedBank != _cachedBank) {
        _cachedDocument = document;
        _cachedBank = selectedBank;
        _cachedDraft = BankScreenshotParser().parse(
          document,
          bankHint: selectedBank,
        );
      }
      draft = _cachedDraft;
    }
    return PopScope(
      canPop: !_bankPickerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _bankPickerOpen) _closeBankPicker();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
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
                onSelect: _selectScreenshot,
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
                  result.draft?.bankIsGuess == true && selectedName == null,
                  selectedName != null && selectedBank == null,
                  selectedBank,
                  _monthOverrides[_index] ?? _periodFor(draft),
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
                      ? () => _selectScreenshot(_index + 1)
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
              if (_bankPickerOpen)
                SizedBox(height: MediaQuery.sizeOf(context).height),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _draftWidgets(
    BuildContext context,
    ParsedScreenshot draft,
    OcrDocument document,
    String bankLabel,
    bool bankNeedsSelection,
    bool bankIsGuess,
    bool unsupportedBank,
    Bank? selectedBank,
    CashbackMonth? selectedPeriod,
  ) {
    final periods = importMonthChoices();
    final periodAllowed =
        selectedPeriod == null || periods.contains(selectedPeriod);
    return [
      Text(
        'Обработка: ${(document.elapsedMs / 1000).toStringAsFixed(1)} с · ${document.lines.length} строк',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      const SizedBox(height: 16),
      CompositedTransformTarget(
        link: _bankLayer,
        child: OutlinedButton.icon(
          key: _bankAnchorKey,
          onPressed: _openBankPicker,
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          icon: const Icon(Icons.account_balance_outlined),
          label: Text(bankLabel, overflow: TextOverflow.ellipsis),
        ),
      ),
      if (bankNeedsSelection) ...[
        const SizedBox(height: 8),
        const Text('Банк не распознан. Выберите его перед сохранением.'),
      ],
      if (bankIsGuess) ...[
        const SizedBox(height: 8),
        const Text(
          'Банк указан предположительно. Проверьте его перед сохранением.',
        ),
      ],
      if (unsupportedBank) ...[
        const SizedBox(height: 8),
        const Text(
          'Для этого банка нет отдельного распознавания. Проверьте результат вручную.',
        ),
      ],
      const SizedBox(height: 16),
      DropdownButtonFormField<CashbackMonth>(
        key: ValueKey(
          'review-month-$_index-${selectedPeriod?.year}-${selectedPeriod?.month}',
        ),
        initialValue: periodAllowed ? selectedPeriod : null,
        decoration: const InputDecoration(labelText: 'Месяц'),
        items: [
          for (final period in periods)
            DropdownMenuItem(
              value: period,
              child: Text(importMonthLabel(period)),
            ),
        ],
        onChanged: (period) {
          if (period != null) setState(() => _monthOverrides[_index] = period);
        },
      ),
      if (!periodAllowed) ...[
        const SizedBox(height: 8),
        const Text(
          'Месяц на скриншоте вне доступных трёх месяцев. Проверьте изображение и выберите подходящий период.',
        ),
      ],
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
          initialPeriod: _monthOverrides[index],
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
    final guessedBanks = <String>[];
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
      if (result.draft?.bankIsGuess == true && selectedName == null) {
        guessedBanks.add('Скриншот ${index + 1}: ${bank.label}');
      }
      final draft = BankScreenshotParser().parse(document, bankHint: bank);
      final period = _monthOverrides[index] ?? _periodFor(draft);
      if (period == null) {
        _needsCorrection(index, 'Выберите месяц для этого скриншота.');
        return;
      }
      if (!importMonthChoices().contains(period)) {
        _needsCorrection(
          index,
          'Месяц на скриншоте вне доступных трёх месяцев.',
        );
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
          period: period,
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
    if (guessedBanks.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Проверьте банк'),
          content: Text(
            'Банк определён предположительно:\n${guessedBanks.join('\n')}\n\nЕсли банк неверный, выберите его на экране проверки.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Проверить ещё раз'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Банк верный, сохранить'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
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

  void _selectScreenshot(int index) {
    if (index == _index) return;
    if (_bankPickerOpen) _closeBankPicker();
    setState(() => _index = index);
  }

  Future<void> _openBankPicker() async {
    if (_bankPickerOpen) {
      _closeBankPicker();
      return;
    }
    _bankSearch.clear();
    _keyboardWasVisible = false;
    setState(() => _bankPickerOpen = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_bankPickerOpen) return;
    final anchor = _bankAnchorKey.currentContext;
    if (anchor == null || !anchor.mounted) return;
    await Scrollable.ensureVisible(
      anchor,
      alignment: 0,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
    if (!mounted || !_bankPickerOpen) return;
    _bankOverlay = OverlayEntry(builder: _buildBankOverlay);
    Overlay.of(context).insert(_bankOverlay!);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _bankPickerOpen) _bankSearchFocus.requestFocus();
    });
  }

  Widget _buildBankOverlay(BuildContext overlayContext) {
    final anchorBox =
        _bankAnchorKey.currentContext?.findRenderObject() as RenderBox?;
    final anchorHeight = anchorBox?.size.height ?? 56.0;
    final anchorWidth =
        anchorBox?.size.width ?? MediaQuery.sizeOf(context).width - 48;
    final anchorBottom = anchorBox == null
        ? 0.0
        : anchorBox.localToGlobal(Offset(0, anchorHeight)).dy;
    final keyboardTop =
        MediaQuery.sizeOf(overlayContext).height -
        MediaQuery.viewInsetsOf(overlayContext).bottom;
    final available = math.max(0.0, keyboardTop - anchorBottom - 8);
    final query = _bankSearch.text.trim().toLowerCase();
    final matches = Bank.values
        .where((bank) => bank.label.toLowerCase().contains(query))
        .toList();
    final listHeight = math.min(
      available,
      math.max(56.0, matches.length * 56.0),
    );
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closeBankPicker,
          ),
        ),
        CompositedTransformFollower(
          link: _bankLayer,
          showWhenUnlinked: false,
          child: Material(
            color: Colors.transparent,
            child: SizedBox(
              width: anchorWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: anchorHeight,
                    child: TextField(
                      controller: _bankSearch,
                      focusNode: _bankSearchFocus,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Название банка',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          tooltip: 'Закрыть выбор банка',
                          icon: const Icon(Icons.close),
                          onPressed: _closeBankPicker,
                        ),
                        filled: true,
                        fillColor: Theme.of(context).scaffoldBackgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(32),
                        ),
                      ),
                      onChanged: (_) => _bankOverlay?.markNeedsBuild(),
                      onSubmitted: (_) {
                        if (matches.length == 1) _chooseBank(matches.single);
                      },
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (listHeight > 0)
                    SizedBox(
                      height: listHeight,
                      child: Material(
                        color: Theme.of(context).colorScheme.surface,
                        elevation: 8,
                        borderRadius: BorderRadius.circular(16),
                        clipBehavior: Clip.antiAlias,
                        child: matches.isEmpty
                            ? const Center(child: Text('Банк не найден'))
                            : ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: matches.length,
                                itemBuilder: (context, index) => SizedBox(
                                  height: 56,
                                  child: ListTile(
                                    title: Text(matches[index].label),
                                    onTap: () => _chooseBank(matches[index]),
                                  ),
                                ),
                              ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _chooseBank(Bank bank) {
    final index = _index;
    _closeBankPicker();
    setState(() {
      _bankNames[index] = bank.label;
      _bankHints[index] = bank;
    });
  }

  void _closeBankPicker() {
    if (!_bankPickerOpen) return;
    _bankOverlay?.remove();
    _bankOverlay?.dispose();
    _bankOverlay = null;
    _bankSearchFocus.unfocus();
    if (mounted) setState(() => _bankPickerOpen = false);
  }

  String _rate(double value) => value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString().replaceAll('.', ',');
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
