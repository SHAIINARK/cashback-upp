import 'dart:math' as math;

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
    final result = await Navigator.of(context)
        .push<
          ({
            Bank bank,
            String name,
            RewardType rewardType,
            String customRewardName,
          })
        >(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) =>
                _CardDialog(card: card, cards: widget.controller.cards),
          ),
        );
    if (result == null) return;
    await _run(
      () => widget.controller.saveCard(
        BankCard(
          id: card?.id ?? widget.controller.newId(),
          bank: result.bank,
          name: result.name,
          rewardType: result.rewardType,
          customRewardName: result.customRewardName,
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
            String customRewardName,
            bool isUpTo,
            String notes,
          })
        >(
          context: context,
          builder: (_) => _CategoryDialog(
            card: card,
            period: period ?? widget.controller.month,
            category: category,
            categorySuggestions: widget.controller.allSets
                .where((set) => set.cardId == card.id)
                .expand((set) => set.categories)
                .map((item) => item.originalName)
                .toSet()
                .toList(),
            rewardSuggestions: widget.controller.allSets
                .where((set) => set.cardId == card.id)
                .expand((set) => set.categories)
                .map((item) => item.rewardLabel)
                .toSet()
                .toList(),
            notesSuggestions: widget.controller.allSets
                .where((set) => set.cardId == card.id)
                .expand((set) => set.categories)
                .map((item) => item.notes)
                .where((item) => item.trim().isNotEmpty)
                .toSet()
                .toList(),
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
          customRewardName: result.customRewardName,
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
                              '${card.bank.label}${cards.where((item) => item.bank == card.bank).length > 1 || !card.hasAutomaticName ? ' · ${card.name}' : ''}',
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
                      Text(card.rewardLabel),
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
                                '${category.isUpTo ? 'До ' : ''}${category.percent}% · ${category.rewardLabel}${category.notes.isEmpty ? '' : '\n${category.notes}'}',
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

enum _CardNameMode {
  automatic('Не указывать'),
  debit('Дебетовая'),
  credit('Кредитная'),
  custom('Своё название');

  const _CardNameMode(this.label);
  final String label;
}

class _CardDialog extends StatefulWidget {
  const _CardDialog({this.card, required this.cards});
  final BankCard? card;
  final List<BankCard> cards;
  @override
  State<_CardDialog> createState() => _CardDialogState();
}

class _CardDialogState extends State<_CardDialog> with WidgetsBindingObserver {
  final _form = GlobalKey<FormState>();
  final _bankLayer = LayerLink();
  final _bankAnchorKey = GlobalKey();
  final _bankSearch = TextEditingController();
  final _bankFocus = FocusNode();
  final _customNameFocus = FocusNode();
  late final _rewardInput = TextEditingController(
    text: widget.card?.rewardLabel ?? RewardType.rubles.label,
  );
  late final _customName = TextEditingController(
    text: _modeFor(widget.card?.name) == _CardNameMode.custom
        ? widget.card!.name
        : '',
  );
  late Bank _bank = widget.card?.bank ?? Bank.alfa;
  late RewardType _reward = widget.card?.rewardType ?? RewardType.rubles;
  late String _customRewardName = widget.card?.customRewardName ?? '';
  late _CardNameMode _nameMode = _modeFor(widget.card?.name);
  OverlayEntry? _bankOverlay;
  bool _bankPickerOpen = false;
  bool _keyboardWasVisible = false;

  static _CardNameMode _modeFor(String? name) {
    if (name == null || RegExp(r'^Карта \d+$').hasMatch(name)) {
      return _CardNameMode.automatic;
    }
    if (name == 'Дебетовая' || RegExp(r'^Дебетовая \d+$').hasMatch(name)) {
      return _CardNameMode.debit;
    }
    if (name == 'Кредитная' || RegExp(r'^Кредитная \d+$').hasMatch(name)) {
      return _CardNameMode.credit;
    }
    return _CardNameMode.custom;
  }

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
    _bankFocus.dispose();
    _customName.dispose();
    _customNameFocus.dispose();
    _rewardInput.dispose();
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

  Future<void> _openBankPicker() async {
    if (_bankPickerOpen) return;
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
      if (mounted && _bankPickerOpen) _bankFocus.requestFocus();
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
    final options = Bank.withSaved([
      ...widget.cards.map((card) => card.bank),
      _bank,
    ]);
    final matches = options
        .where((bank) => bank.label.toLowerCase().contains(query))
        .toList();
    final canAdd =
        query.isNotEmpty &&
        !options.any((bank) => bank.label.toLowerCase() == query);
    final listHeight = math.min(
      available,
      math.max(56.0, (matches.length + (canAdd ? 1 : 0)) * 56.0),
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
                      focusNode: _bankFocus,
                      maxLength: 60,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'Название банка',
                        counterText: '',
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
                        final exact = options
                            .where((bank) => bank.label.toLowerCase() == query)
                            .firstOrNull;
                        if (exact != null) {
                          _chooseBank(exact);
                        } else if (canAdd) {
                          _chooseBank(Bank.named(_bankSearch.text));
                        }
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
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: matches.length + (canAdd ? 1 : 0),
                          itemBuilder: (context, index) => SizedBox(
                            height: 56,
                            child: ListTile(
                              title: Text(
                                index < matches.length
                                    ? matches[index].label
                                    : 'Добавить банк «${_bankSearch.text.trim()}»',
                              ),
                              leading: index < matches.length
                                  ? null
                                  : const Icon(Icons.add),
                              onTap: () => _chooseBank(
                                index < matches.length
                                    ? matches[index]
                                    : Bank.named(_bankSearch.text),
                              ),
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
    _closeBankPicker();
    setState(() {
      _bank = bank;
      if (bank == Bank.sber) {
        _reward = RewardType.sberSpasibo;
        _customRewardName = '';
        _rewardInput.text = _reward.label;
      } else if (_reward == RewardType.sberSpasibo) {
        _reward = RewardType.rubles;
        _customRewardName = '';
        _rewardInput.text = _reward.label;
      }
    });
  }

  void _closeBankPicker() {
    if (!_bankPickerOpen) return;
    _bankOverlay?.remove();
    _bankOverlay?.dispose();
    _bankOverlay = null;
    _bankFocus.unfocus();
    if (mounted) setState(() => _bankPickerOpen = false);
  }

  String _resolvedName() {
    if (_nameMode == _CardNameMode.custom) return _customName.text.trim();
    final base = switch (_nameMode) {
      _CardNameMode.automatic => 'Карта',
      _CardNameMode.debit => 'Дебетовая',
      _CardNameMode.credit => 'Кредитная',
      _CardNameMode.custom => throw StateError('Неизвестный тип названия'),
    };
    final current = widget.card;
    if (current != null &&
        current.bank == _bank &&
        _modeFor(current.name) == _nameMode) {
      return current.name;
    }
    final used = widget.cards
        .where((card) => card.bank == _bank && card.id != current?.id)
        .map((card) => card.name.toLowerCase())
        .toSet();
    if (_nameMode != _CardNameMode.automatic &&
        !used.contains(base.toLowerCase())) {
      return base;
    }
    for (
      var index = _nameMode == _CardNameMode.automatic ? 1 : 2;
      index < 10000;
      index++
    ) {
      final name = '$base $index';
      if (!used.contains(name.toLowerCase())) return name;
    }
    throw StateError('Не удалось создать название карты');
  }

  List<String> get _rewardSuggestions => {
    ...RewardType.values
        .where((type) => type != RewardType.custom)
        .map((type) => type.label),
    ...widget.cards.map((card) => card.rewardLabel),
  }.toList();

  void _selectReward(String value) {
    final known = RewardType.values
        .where((type) => type != RewardType.custom)
        .where((type) => type.label == value)
        .firstOrNull;
    setState(() {
      _rewardInput.text = value;
      _customRewardName = known == null ? value : '';
      _reward = known ?? RewardType.custom;
    });
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, (
      bank: _bank,
      name: _resolvedName(),
      rewardType: _reward,
      customRewardName: _customRewardName,
    ));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_bankPickerOpen,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop && _bankPickerOpen) _closeBankPicker();
    },
    child: Scaffold(
      resizeToAvoidBottomInset: !_bankPickerOpen,
      appBar: AppBar(
        title: Text(widget.card == null ? 'Добавить карту' : 'Изменить карту'),
      ),
      body: SafeArea(
        child: Form(
          key: _form,
          child: PageBody(
            children: [
              const Text(
                'Выберите банк. Название карты можно не указывать, если она у вас одна.',
              ),
              const SizedBox(height: 20),
              CompositedTransformTarget(
                link: _bankLayer,
                child: OutlinedButton.icon(
                  key: _bankAnchorKey,
                  onPressed: _openBankPicker,
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  icon: const Icon(Icons.account_balance_outlined),
                  label: Text(_bank.label, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(height: 20),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Название карты (необязательно)',
                  border: InputBorder.none,
                ),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final mode in [
                      _CardNameMode.automatic,
                      _CardNameMode.debit,
                      _CardNameMode.credit,
                    ])
                      ChoiceChip(
                        label: Text(mode.label),
                        selected: _nameMode == mode,
                        onSelected: (_) {
                          setState(() {
                            _nameMode = mode;
                            _customName.clear();
                          });
                          if (mode == _CardNameMode.automatic) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted) {
                                FocusScope.of(context)
                                    .requestFocus(_customNameFocus);
                              }
                            });
                          } else {
                            _customNameFocus.unfocus();
                          }
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              _SuggestionFormField(
                controller: _customName,
                focusNode: _customNameFocus,
                suggestions: widget.cards
                    .where((card) => card.bank == _bank)
                    .map((card) => card.name)
                    .where((name) => name != widget.card?.name)
                    .toSet()
                    .toList(),
                label: 'Своё название',
                hint: 'Оставьте пустым или начните вводить',
                maxLength: 60,
                onChanged: (value) => setState(() {
                  if (value.trim().isNotEmpty) {
                    _nameMode = _CardNameMode.custom;
                  } else if (_nameMode == _CardNameMode.custom) {
                    _nameMode = _CardNameMode.automatic;
                  }
                }),
                validator: (value) {
                  if (_nameMode != _CardNameMode.custom) return null;
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return 'Введите название карты';
                  if (widget.cards.any(
                    (card) =>
                        card.bank == _bank &&
                        card.id != widget.card?.id &&
                        card.name.toLowerCase() == name.toLowerCase(),
                  )) {
                    return 'У этого банка уже есть карта с таким названием';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _SuggestionFormField(
                controller: _rewardInput,
                suggestions: _rewardSuggestions,
                label: 'Вознаграждение',
                hint: 'Начните вводить или выберите подсказку',
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Введите вид вознаграждения'
                    : null,
                onSuggestionSelected: _selectReward,
                onChanged: (value) {
                  final known = RewardType.values
                      .where((type) => type != RewardType.custom)
                      .where((type) => type.label == value.trim())
                      .firstOrNull;
                  setState(() {
                    _reward = known ?? RewardType.custom;
                    _customRewardName = known == null ? value.trim() : '';
                  });
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                child: Text(widget.card == null ? 'Добавить' : 'Сохранить'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена'),
              ),
              if (_bankPickerOpen)
                SizedBox(height: MediaQuery.sizeOf(context).height),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({
    required this.card,
    required this.period,
    required this.categorySuggestions,
    required this.rewardSuggestions,
    required this.notesSuggestions,
    this.category,
  });
  final BankCard card;
  final CashbackMonth period;
  final List<String> categorySuggestions;
  final List<String> rewardSuggestions;
  final List<String> notesSuggestions;
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
  late String _customRewardName = widget.category?.customRewardName ?? '';
  late final _rewardInput = TextEditingController(
    text: widget.category?.rewardLabel ?? widget.card.rewardLabel,
  );
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
            _SuggestionFormField(
              controller: _name,
              suggestions: widget.categorySuggestions,
              label: 'Точное название',
              hint: 'Начните вводить или выберите подсказку',
              maxLength: 100,
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
            _SuggestionFormField(
              controller: _notes,
              suggestions: widget.notesSuggestions,
              label: 'Условия или примечание',
              hint: 'Можно начать вводить или выбрать подсказку',
              maxLines: 2,
              maxLength: 300,
            ),
            _SuggestionFormField(
              controller: _rewardInput,
              suggestions: {
                ...RewardType.values
                    .where((type) => type != RewardType.custom)
                    .map((type) => type.label),
                ...widget.rewardSuggestions,
              }.toList(),
              label: 'Вознаграждение',
              hint: 'Начните вводить или выберите подсказку',
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Введите вид вознаграждения'
                  : null,
              onSuggestionSelected: (value) {
                final known = RewardType.values
                    .where((type) => type != RewardType.custom)
                    .where((type) => type.label == value)
                    .firstOrNull;
                setState(() {
                  _reward = known ?? RewardType.custom;
                  _customRewardName = known == null ? value : '';
                });
              },
              onChanged: (value) {
                final known = RewardType.values
                    .where((type) => type != RewardType.custom)
                    .where((type) => type.label == value.trim())
                    .firstOrNull;
                setState(() {
                  _reward = known ?? RewardType.custom;
                  _customRewardName = known == null ? value.trim() : '';
                });
              },
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
            customRewardName: _customRewardName,
            isUpTo: _upTo,
            notes: _notes.text.trim(),
          ));
        },
        child: const Text('Сохранить'),
      ),
    ],
  );
}

class _SuggestionFormField extends StatefulWidget {
  const _SuggestionFormField({
    required this.controller,
    required this.suggestions,
    required this.label,
    required this.hint,
    this.focusNode,
    this.maxLength,
    this.maxLines = 1,
    this.validator,
    this.onChanged,
    this.onSuggestionSelected,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final String label;
  final String hint;
  final FocusNode? focusNode;
  final int? maxLength;
  final int maxLines;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSuggestionSelected;

  @override
  State<_SuggestionFormField> createState() => _SuggestionFormFieldState();
}

class _SuggestionFormFieldState extends State<_SuggestionFormField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  bool _ownsFocus = false;

  @override
  void initState() {
    super.initState();
    _ownsFocus = widget.focusNode == null;
    _focus.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChanged);
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _choose(String value) {
    widget.controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    widget.onSuggestionSelected?.call(value);
    widget.onChanged?.call(value);
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.controller.text.trim();
    final lower = query.toLowerCase();
    final matches = query.isEmpty
        ? <String>[]
        : widget.suggestions
              .where((item) => item.toLowerCase().contains(lower))
              .toSet()
              .take(5)
              .toList();
    final hasExact = widget.suggestions.any(
      (item) => item.toLowerCase() == lower,
    );
    final showOptions = _focus.hasFocus && query.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextFormField(
          controller: widget.controller,
          focusNode: _focus,
          maxLines: widget.maxLines,
          maxLength: widget.maxLength,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
          ),
          validator: widget.validator,
          onChanged: (value) {
            setState(() {});
            widget.onChanged?.call(value);
          },
        ),
        if (showOptions && (matches.isNotEmpty || !hasExact))
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 180),
            child: Card(
              margin: const EdgeInsets.only(top: 2),
              clipBehavior: Clip.antiAlias,
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final suggestion in matches)
                    ListTile(
                      dense: true,
                      title: Text(suggestion),
                      onTap: () => _choose(suggestion),
                    ),
                  if (!hasExact)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.add),
                      title: Text('Использовать «$query»'),
                      onTap: () => _choose(query),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
