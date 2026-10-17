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
    this.showOnEmpty = true,
    this.clearOnFocus = false,
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

  /// Open the saved options when the field is focused before typing.
  final bool showOnEmpty;

  /// Start a new search when an existing value is tapped for editing.
  final bool clearOnFocus;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSuggestionSelected;

  @override
  State<SuggestionFormField> createState() => _SuggestionFormFieldState();
}

class _SuggestionFormFieldState extends State<SuggestionFormField>
    with WidgetsBindingObserver {
  final _anchorKey = GlobalKey();
  final _layerLink = LayerLink();
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  bool _ownsFocus = false;
  OverlayEntry? _overlay;

  double get _keyboardInset {
    final view = View.of(context);
    return view.viewInsets.bottom / view.devicePixelRatio;
  }

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
      if (_keyboardInset == 0) {
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
    if (widget.clearOnFocus && widget.controller.text.isNotEmpty) {
      widget.controller.clear();
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
          _keyboardInset > 0) {
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
      .toList();

  bool _needsSuggestionPanel(String value) {
    final query = value.trim();
    if (query.isEmpty) {
      return widget.showOnEmpty && widget.suggestions.isNotEmpty;
    }
    final matches = _matches(query);
    final exact = widget.suggestions.any(
      (item) => item.trim().toLowerCase() == query.toLowerCase(),
    );
    if (matches.isEmpty && !widget.allowCustomEntry) return false;
    return !(exact && matches.length == 1);
  }

  Widget _buildOverlay(BuildContext overlayContext) {
    final anchor = _anchorKey.currentContext?.findRenderObject();
    if (anchor is! RenderBox || !anchor.hasSize) {
      return const SizedBox.shrink();
    }
    final view = View.of(context);
    final screenHeight = view.physicalSize.height / view.devicePixelRatio;
    final keyboardTop = screenHeight - _keyboardInset;
    final fieldTop = anchor.localToGlobal(Offset.zero).dy;
    final below = math.max(
      0.0,
      keyboardTop - fieldTop - anchor.size.height - 12,
    );
    final above = math.max(
      0.0,
      fieldTop - MediaQuery.paddingOf(context).top - 12,
    );
    final openAbove = below < 72 && above > below;
    final available = openAbove ? above : below;
    final query = widget.controller.text.trim();
    final matches = _matches(query);
    final exact = widget.suggestions.any(
      (item) => item.trim().toLowerCase() == query.toLowerCase(),
    );
    final canUseEntered = widget.allowCustomEntry && query.isNotEmpty && !exact;
    final rows = matches.length + (canUseEntered ? 1 : 0);
    if (rows == 0 || available < 48) return const SizedBox.shrink();
    final desiredHeight = math.min(280.0, math.min(available, rows * 52.0));
    return Stack(
      children: [
        Positioned.fill(
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: openAbove ? Alignment.topLeft : Alignment.bottomLeft,
            followerAnchor: Alignment.topLeft,
            offset: Offset(0, openAbove ? -desiredHeight - 4 : 4),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: anchor.size.width,
                height: desiredHeight,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 8,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: rows,
                    itemBuilder: (context, index) {
                      if (index == matches.length) {
                        return ListTile(
                          dense: true,
                          leading: const Icon(Icons.add),
                          title: Text('Использовать «$query»'),
                          onTap: () => _choose(query),
                        );
                      }
                      final suggestion = matches[index];
                      return ListTile(
                        dense: true,
                        title: Text(suggestion),
                        onTap: () => _choose(suggestion),
                      );
                    },
                  ),
                ),
              ),
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
  Widget build(BuildContext context) => CompositedTransformTarget(
    link: _layerLink,
    child: SizedBox(
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
              _keyboardInset > 0) {
            _showOverlay();
          } else {
            _removeOverlay();
          }
          _overlay?.markNeedsBuild();
        },
        onTap: () {
          if (_needsSuggestionPanel(widget.controller.text) &&
              _keyboardInset > 0) {
            _showOverlay();
          }
        },
      ),
    ),
  );
}
