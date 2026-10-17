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
        .push<({Bank bank, String name, RewardType rewardType})>(
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
  late final _customName = TextEditingController(
    text: _modeFor(widget.card?.name) == _CardNameMode.custom
        ? widget.card!.name
        : '',
  );
  late Bank _bank = widget.card?.bank ?? Bank.alfa;
  late RewardType _reward = widget.card?.rewardType ?? RewardType.rubles;
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
      } else if (_reward == RewardType.sberSpasibo) {
        _reward = RewardType.rubles;
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

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.pop(context, (
      bank: _bank,
      name: _resolvedName(),
      rewardType: _reward,
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
              DropdownButtonFormField<_CardNameMode>(
                key: ValueKey(_nameMode),
                initialValue: _nameMode,
                decoration: const InputDecoration(
                  labelText: 'Название карты (необязательно)',
                ),
                items: [
                  for (final mode in _CardNameMode.values)
                    DropdownMenuItem(value: mode, child: Text(mode.label)),
                ],
                onChanged: (mode) {
                  if (mode != null) setState(() => _nameMode = mode);
                },
              ),
              if (_nameMode == _CardNameMode.custom) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customName,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Своё название',
                    hintText: 'Например, карта для покупок',
                  ),
                  validator: (value) {
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
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<RewardType>(
                key: ValueKey(_reward),
                initialValue: _reward,
                decoration: const InputDecoration(labelText: 'Вознаграждение'),
                items: [
                  for (final type in RewardType.values)
                    DropdownMenuItem(value: type, child: Text(type.label)),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _reward = value);
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
