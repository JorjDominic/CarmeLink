import 'package:flutter/material.dart';

import '../../services/dormitory_configuration_service.dart';
import '../../services/table_refresh_subscription.dart';
import 'searchable_dropdown.dart';

/// Database-backed choices. Search is opt-in for staff workflows only.
class ConfiguredChoiceField extends StatefulWidget {
  const ConfiguredChoiceField({
    super.key,
    required this.group,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.searchable = false,
    this.useLabelAsValue = false,
    this.preservedValue,
    this.preservedLabel,
  });

  final String group, label;
  final String? value, preservedValue, preservedLabel;
  final bool enabled, searchable, useLabelAsValue;
  final ValueChanged<DormitoryOption?> onChanged;

  @override
  State<ConfiguredChoiceField> createState() => _ConfiguredChoiceFieldState();
}

class _ConfiguredChoiceFieldState extends State<ConfiguredChoiceField> {
  List<DormitoryOption> _options = [];
  late final TableRefreshSubscription _subscription;
  bool _loading = true;
  String? _error;
  int _request = 0;

  String _value(DormitoryOption option) =>
      widget.useLabelAsValue ? option.label : option.code;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = TableRefreshSubscription(
      'configured-choice-${widget.group}-${identityHashCode(this)}',
      const ['dormitory_options'],
      _load,
    );
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      final options =
          await const DormitoryConfigurationService().options(widget.group);
      if (!mounted || request != _request) return;
      setState(() {
        _options = options;
        _loading = false;
        _error = null;
      });
      if (widget.value != widget.preservedValue || widget.value == null) {
        final current =
            options.where((o) => _value(o) == widget.value).firstOrNull;
        widget.onChanged(current);
      }
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        _error = 'Could not load choices.';
      });
      widget.onChanged(null);
    }
  }

  @override
  void didUpdateWidget(covariant ConfiguredChoiceField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            _loading ||
            widget.value == widget.preservedValue &&
                widget.preservedValue != null) return;
        widget.onChanged(
            _options.where((o) => _value(o) == widget.value).firstOrNull);
      });
    }
  }

  @override
  void dispose() {
    _subscription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _options
        .map((o) => DropdownMenuItem(value: _value(o), child: Text(o.label)))
        .toList();
    if (widget.preservedValue != null &&
        widget.value == widget.preservedValue &&
        !items.any((item) => item.value == widget.preservedValue)) {
      items.add(DropdownMenuItem(
          value: widget.preservedValue,
          child: Text(
              '${widget.preservedLabel ?? widget.preservedValue} (archived)')));
    }
    final selected =
        items.any((item) => item.value == widget.value) ? widget.value : null;
    void change(String? value) {
      widget.onChanged(_options.where((o) => _value(o) == value).firstOrNull);
    }

    final enabled =
        widget.enabled && !_loading && _error == null && items.isNotEmpty;
    final decoration = InputDecoration(
        labelText: widget.label,
        helperText: !_loading && items.isEmpty
            ? 'No active choices. Contact dormitory staff.'
            : null);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (_loading) const LinearProgressIndicator(),
      if (_error != null)
        Row(children: [
          Expanded(child: Text(_error!)),
          TextButton(onPressed: _load, child: const Text('Retry'))
        ]),
      if (widget.searchable)
        SearchableDropdownFormField<String>(
          key: ValueKey(selected),
          initialValue: selected,
          decoration: decoration,
          items: items,
          onChanged: enabled ? change : null,
        )
      else
        DropdownButtonFormField<String>(
          key: ValueKey(selected),
          initialValue: selected,
          isExpanded: true,
          decoration: decoration,
          items: items,
          onChanged: enabled ? change : null,
        ),
    ]);
  }
}
