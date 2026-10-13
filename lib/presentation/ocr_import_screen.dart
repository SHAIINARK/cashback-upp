import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../app/theme.dart';
import '../data/native_ocr_engine.dart';
import '../logic/ocr_import_controller.dart';
import 'ocr_review_screen.dart';
import 'widgets.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key, this.picker});
  final ImagePicker? picker;
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final _controller = OcrImportController(const NativeOcrEngine());
  late final ImagePicker _picker;
  bool _selecting = false;

  @override
  void initState() {
    super.initState();
    _picker = widget.picker ?? ImagePicker();
    _recoverSelection();
  }

  Future<void> _recoverSelection() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    setState(() => _selecting = true);
    try {
      // A killed mobile process does not run dispose. Clear only our old cache
      // sessions before recovering the picker's separately owned copies.
      final cache = await getTemporaryDirectory();
      await for (final entity in cache.list(followLinks: false)) {
        if (entity is Directory &&
            entity.path
                .split(Platform.pathSeparator)
                .last
                .startsWith('cashback-import-')) {
          await entity.delete(recursive: true);
        }
      }
      if (!mounted || !Platform.isAndroid) return;
      final response = await _picker.retrieveLostData();
      if (response.files case final files? when files.isNotEmpty) {
        await _process(files);
      }
    } catch (_) {
      // Recovery is optional. A fresh selection remains available.
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  Future<void> _pick() async {
    if (_controller.busy || _selecting) return;
    setState(() => _selecting = true);
    try {
      final files = await _picker.pickMultiImage(
        limit: 10,
        requestFullMetadata: false,
      );
      if (mounted && files.isNotEmpty) await _process(files);
    } catch (_) {
      if (mounted) {
        _message('Не удалось выбрать скриншоты. Попробуйте ещё раз.');
      }
    } finally {
      if (mounted) setState(() => _selecting = false);
    }
  }

  Future<void> _process(List<XFile> files) async {
    if (files.length > 10) {
      if (mounted) _message('За один раз можно обработать до 10 скриншотов.');
      return;
    }
    Directory? directory;
    try {
      final cache = await getTemporaryDirectory();
      directory = await Directory(cache.path).createTemp('cashback-import-');
      final paths = <String>[];
      for (var i = 0; i < files.length; i++) {
        final destination = '${directory.path}/screenshot-$i';
        await files[i].saveTo(destination);
        paths.add(destination);
      }
      for (final file in files) {
        // Delete only picker copies in app cache, after making all copies.
        // Never delete an original gallery path or another app's document.
        final picked = File(file.path);
        if (picked.path.startsWith('${cache.path}${Platform.pathSeparator}') &&
            await picked.exists()) {
          try {
            await picked.delete();
          } on FileSystemException {
            // OS may already have reclaimed its cache copy.
          }
        }
      }
      await _controller.import(paths, directory);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ImportReviewScreen(results: _controller.results),
        ),
      );
      await _controller.clear();
    } catch (_) {
      if (directory != null && await directory.exists()) {
        await directory.delete(recursive: true);
      }
      if (mounted) {
        _message('Не удалось подготовить скриншоты. Попробуйте ещё раз.');
      }
    }
  }

  void _message(String message) =>
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: _controller,
    builder: (context, _) => PageBody(
      children: [
        const PageHeading(
          eyebrow: 'ОБНОВЛЕНИЕ КАТЕГОРИЙ',
          title: 'Из банка —\nв один список',
          subtitle: 'Выберите скриншоты выбранного кэшбэка. Обработка происходит на телефоне.',
        ),
        SurfacePanel(
          color: AppColors.ink,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.photo_library_outlined,
                color: AppColors.accent,
                size: 38,
              ),
              const SizedBox(height: 18),
              const Text(
                'Проверим ваши категории',
                style: TextStyle(
                  fontSize: 22,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'До 10 скриншотов за один раз. Можно несколько для одного банка. Фотографии не отправляются на сервер.',
                style: TextStyle(color: Color(0xFFD3E1DB), height: 1.5),
              ),
              const SizedBox(height: 22),
              if (_controller.busy) ...[
                LinearProgressIndicator(
                  value: _controller.total > 0
                      ? _controller.completed / _controller.total
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  'Распознаём ${_controller.completed + 1 > _controller.total ? _controller.total : _controller.completed + 1} из ${_controller.total}…',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                onPressed: _controller.busy || _selecting ? null : _pick,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accent,
                  foregroundColor: AppColors.ink,
                  disabledForegroundColor: const Color(0xFFD3E1DB),
                  disabledBackgroundColor: const Color(0xFF36514B),
                ),
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(
                  _controller.busy ? 'Обработка…' : 'Выбрать скриншоты',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SurfacePanel(
          child: Text(
            'Это первая проверка распознавания. Результат — черновик: проверьте названия, проценты и выбранные строки. Сохранение категорий появится на следующем этапе.',
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: _controller.busy
              ? null
              : () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const ImportReviewScreen(),
                  ),
                ),
          icon: const Icon(Icons.fact_check_outlined),
          label: const Text('Открыть проверку импорта'),
        ),
      ],
    ),
  );
}
