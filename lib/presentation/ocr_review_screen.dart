import 'dart:io';

import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../domain/ocr_models.dart';
import '../logic/bank_screenshot_parser.dart';
import '../logic/ocr_import_controller.dart';
import 'widgets.dart';

class ImportReviewScreen extends StatefulWidget {
  const ImportReviewScreen({super.key, this.results = const []});
  final List<ScreenshotResult> results;
  @override
  State<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends State<ImportReviewScreen> {
  int _index = 0;
  final Map<int, Bank> _bankHints = {};
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
    final draft = document == null
        ? null
        : BankScreenshotParser().parse(document, bankHint: _bankHints[_index]);
    return Scaffold(
      appBar: AppBar(title: const Text('Проверка импорта')),
      body: SafeArea(
        child: PageBody(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Предыдущий скриншот',
                  onPressed: _index > 0 ? () => setState(() => _index--) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    'Скриншот ${_index + 1} из ${widget.results.length}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Следующий скриншот',
                  onPressed: _index < widget.results.length - 1
                      ? () => setState(() => _index++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
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
              ..._draftWidgets(context, draft, document),
            const SizedBox(height: 24),
            const Text(
              'Результат пока не сохраняется. После возврата временные копии этих скриншотов будут удалены.',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Завершить проверку'),
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
  ) => [
    Text(
      'Обработка: ${(document.elapsedMs / 1000).toStringAsFixed(1)} с · ${document.lines.length} строк',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
    const SizedBox(height: 16),
    DropdownButtonFormField<Bank>(
      key: ValueKey('bank-$_index-${draft.bank}'),
      initialValue: draft.bank,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Банк — подтвердите выбор',
        border: OutlineInputBorder(),
      ),
      items: Bank.values
          .map((bank) => DropdownMenuItem(value: bank, child: Text(bank.label)))
          .toList(),
      onChanged: (bank) {
        if (bank != null) setState(() => _bankHints[_index] = bank);
      },
    ),
    const SizedBox(height: 16),
    Text(
      'Месяц: ${draft.month == null ? 'не определён' : _months[draft.month! - 1]} · Год: ${draft.year ?? 'не указан'}',
      style: Theme.of(context).textTheme.titleMedium,
    ),
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
                '${category.isUpTo ? 'до ' : ''}${_rate(category.percent)}%${draft.bank == Bank.sber ? ' бонусами Спасибо' : ''}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (category.selectionUnknown) ...[
                const SizedBox(height: 8),
                const Text('Не подтверждено, что эта строка выбрана в банке.'),
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

  String _rate(double value) => value == value.truncateToDouble()
      ? value.toInt().toString()
      : value.toString().replaceAll('.', ',');
}
