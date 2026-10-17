import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A text field with a scrollable suggestion panel placed above the keyboard.
class SuggestionFormField extends StatefulWidget {
  const SuggestionFormField({
    super.key,
    required this.controller,
    required this.suggestions,
    required this.label,
    required this.hint,
    this.focusNode,
    this.autofocus = false,
    this.maxLength,
    this.maxLines = 1,
    this.prefixIcon,
    this.suffixIcon,
    this.allowCustomEntry = true,
    this.validator,
    this.onChanged,
    this.onSuggestionSelected,
  });

  final TextEditingController controller;
  final List<String> suggestions;
  final String label;
  final String hint;
  final FocusNode? focusNode;
  final bool autofocus;
  final int? maxLength;
  final int maxLines;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool allowCustomEntry;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSuggestionSelected;

  @override
  State<SuggestionFormField> createState() => _SuggestionFormFieldState();
}

class _SuggestionFormFieldState extends State<SuggestionFormField>
    with WidgetsBindingObserver {
  final _anchorKey = GlobalKey();
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  bool _ownsFocus = false;
  OverlayEntry? _overlay;

  @override
  void initState() {
    super.initState();
    _ownsFocus = widget.focusNode == null;
    _focus.addListener(_focusChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focus.removeListener(_focusChanged);
    _removeOverlay();
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focus.hasFocus) return;
      if (MediaQuery.viewInsetsOf(context).bottom == 0) {
        _removeOverlay();
      } else if (_needsSuggestionPanel(widget.controller.text)) {
        _showOverlay();
      } else {
        _overlay?.markNeedsBuild();
      }
    });
  }

  void _focusChanged() {
    if (!_focus.hasFocus) {
      _removeOverlay();
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_focus.hasFocus) return;
      final anchor = _anchorKey.currentContext;
      if (anchor != null && anchor.mounted) {
        await Scrollable.ensureVisible(
          anchor,
          alignment: 0.04,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
      if (mounted &&
          _focus.hasFocus &&
          _needsSuggestionPanel(widget.controller.text) &&
          MediaQuery.viewInsetsOf(context).bottom > 0) {
        _showOverlay();
      }
    });
  }

  void _showOverlay() {
    if (_overlay != null) {
      _overlay!.markNeedsBuild();
      return;
    }
    _overlay = OverlayEntry(builder: _buildOverlay);
    Overlay.of(context).insert(_overlay!);
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay?.dispose();
    _overlay = null;
  }

  List<String> _matches(String query) => widget.suggestions
      .where((item) => item.trim().isNotEmpty)
      .where((item) => item.toLowerCase().contains(query.toLowerCase()))
      .toSet()
      .take(12)
      .toList();

  bool _needsSuggestionPanel(String value) {
    final query = value.trim();
    if (query.isEmpty) return false;
    final matches = _matches(query);
    final exact = widget.suggestions.any(
      (item) => item.trim().toLowerCase() == query.toLowerCase(),
    );
    if (matches.isEmpty && !widget.allowCustomEntry) return false;
    return !(exact && matches.length == 1);
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final media = MediaQuery.of(overlayContext);
    final screenHeight = media.size.height;
    final keyboardTop = screenHeight - media.viewInsets.bottom;
    final top = media.padding.top + 8;
    final available = math.max(0.0, keyboardTop - top - 8);
    if (available < 100) return const SizedBox.shrink();
    final query = widget.controller.text.trim();
    final matches = _matches(query);
    final exact = widget.suggestions.any(
      (item) => item.trim().toLowerCase() == query.toLowerCase(),
    );
    final canUseEntered = widget.allowCustomEntry && query.isNotEmpty && !exact;
    final rows = matches.length + (canUseEntered ? 1 : 0);
    if (rows == 0) return const SizedBox.shrink();
    final desiredHeight = available;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _removeOverlay,
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: top,
          height: desiredHeight,
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 16,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                ListTile(
                  title: Text('Подсказки для «$query»'),
                  trailing: IconButton(
                    tooltip: 'Скрыть подсказки',
                    onPressed: _removeOverlay,
                    icon: const Icon(Icons.close),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (final suggestion in matches)
                        ListTile(
                          title: Text(suggestion),
                          onTap: () => _choose(suggestion),
                        ),
                      if (canUseEntered)
                        ListTile(
                          leading: const Icon(Icons.add),
                          title: Text('Использовать «$query»'),
                          onTap: () => _choose(query),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
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
  Widget build(BuildContext context) => SizedBox(
    key: _anchorKey,
    child: TextFormField(
      controller: widget.controller,
      focusNode: _focus,
      autofocus: widget.autofocus,
      maxLines: widget.maxLines,
      maxLength: widget.maxLength,
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint,
        prefixIcon: widget.prefixIcon,
        suffixIcon: widget.suffixIcon,
      ),
      validator: widget.validator,
      onChanged: (value) {
        widget.onChanged?.call(value);
        if (_needsSuggestionPanel(value) &&
            _focus.hasFocus &&
            MediaQuery.viewInsetsOf(context).bottom > 0) {
          _showOverlay();
        } else {
          _removeOverlay();
        }
        _overlay?.markNeedsBuild();
      },
      onTap: () {
        if (_needsSuggestionPanel(widget.controller.text) &&
            MediaQuery.viewInsetsOf(context).bottom > 0) {
          _showOverlay();
        }
      },
    ),
  );
}
