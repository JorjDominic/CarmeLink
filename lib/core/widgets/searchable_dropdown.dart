import 'package:flutter/material.dart';

/// A list search box with an accessible clear action.
class ChoiceSearchField extends StatefulWidget {
  const ChoiceSearchField({
    super.key,
    required this.hintText,
    required this.onChanged,
  });

  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  State<ChoiceSearchField> createState() => _ChoiceSearchFieldState();
}

class _ChoiceSearchFieldState extends State<ChoiceSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _controller,
        decoration: InputDecoration(
          hintText: widget.hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    setState(_controller.clear);
                    widget.onChanged('');
                  },
                ),
        ),
        onChanged: (value) {
          setState(() {});
          widget.onChanged(value.trim().toLowerCase());
        },
      );
}

/// A form selector with a separate search query, so typing never changes the
/// saved value. Text menu items are searchable by their visible labels; callers
/// with richer children must supply [itemLabel].
class SearchableDropdownFormField<T> extends FormField<T> {
  SearchableDropdownFormField({
    super.key,
    super.initialValue,
    required this.items,
    required this.onChanged,
    this.decoration = const InputDecoration(),
    this.hint,
    this.itemLabel,
    super.validator,
    super.onSaved,
    super.autovalidateMode,
  })  : assert(itemLabel != null || items.every((item) => item.child is Text)),
        super(
          enabled: onChanged != null,
          builder: (state) =>
              (state as _SearchableDropdownFormFieldState<T>)._build(),
        );

  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final InputDecoration decoration;
  final Widget? hint;
  final String Function(T value)? itemLabel;

  String labelFor(DropdownMenuItem<T> item) {
    if (itemLabel != null && item.value != null)
      return itemLabel!(item.value as T);
    final text = item.child as Text;
    return text.data ?? text.textSpan?.toPlainText() ?? '';
  }

  @override
  FormFieldState<T> createState() => _SearchableDropdownFormFieldState<T>();
}

class _SearchableDropdownFormFieldState<T> extends FormFieldState<T> {
  @override
  SearchableDropdownFormField<T> get widget =>
      super.widget as SearchableDropdownFormField<T>;

  bool _open = false;
  late final _liveItems = ValueNotifier(widget.items);

  @override
  void dispose() {
    _liveItems.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant SearchableDropdownFormField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _liveItems.value = widget.items;
    });
    if (oldWidget.initialValue != widget.initialValue) {
      setValue(widget.initialValue);
    }
    if (value != null &&
        !widget.items.any((item) => item.value == value && item.enabled)) {
      setValue(null);
      // Parent forms hold dependent IDs too. Notify outside their build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && value == null) widget.onChanged?.call(null);
      });
    }
  }

  Future<void> _select() async {
    if (_open || widget.onChanged == null) return;
    _open = true;
    _liveItems.value = widget.items;
    try {
      final picked = await showDialog<T>(
        context: context,
        builder: (_) => ValueListenableBuilder<List<DropdownMenuItem<T>>>(
          valueListenable: _liveItems,
          builder: (_, items, child) => _SearchDialog<T>(
            title: widget.decoration.labelText ?? 'Choose an option',
            items: items,
            labelFor: widget.labelFor,
            selected: value,
          ),
        ),
      );
      if (!mounted || picked == null || widget.onChanged == null) return;
      // Options may have refreshed while the picker was open.
      if (!widget.items.any((item) => item.value == picked && item.enabled)) {
        return;
      }
      didChange(picked);
      widget.onChanged!(picked);
    } finally {
      _open = false;
    }
  }

  Widget _build() {
    final selected =
        widget.items.where((item) => item.value == value).firstOrNull;
    final enabled = widget.onChanged != null && widget.items.isNotEmpty;
    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: enabled ? _select : null,
        child: InputDecorator(
          decoration: widget.decoration.copyWith(
            enabled: enabled,
            errorText: errorText ?? widget.decoration.errorText,
          ),
          isEmpty: selected == null && widget.hint == null,
          child: Row(
            children: [
              Expanded(
                child: selected == null
                    ? widget.hint ?? const Text('')
                    : Text(widget.labelFor(selected),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const Icon(Icons.search, size: 20),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchDialog<T> extends StatefulWidget {
  const _SearchDialog({
    required this.title,
    required this.items,
    required this.labelFor,
    required this.selected,
  });

  final String title;
  final List<DropdownMenuItem<T>> items;
  final String Function(DropdownMenuItem<T>) labelFor;
  final T? selected;

  @override
  State<_SearchDialog<T>> createState() => _SearchDialogState<T>();
}

class _SearchDialogState<T> extends State<_SearchDialog<T>> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final matches = widget.items
        .where((item) => widget.labelFor(item).toLowerCase().contains(query))
        .toList();
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Search options',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () => setState(_search.clear),
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (matches.length == 1 && matches.single.enabled) {
                    Navigator.pop(context, matches.single.value);
                  }
                },
              ),
              const SizedBox(height: 8),
              Flexible(
                child: matches.isEmpty
                    ? const SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('No matches. Try another search.'),
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: matches.length,
                        itemBuilder: (context, index) {
                          final item = matches[index];
                          return ListTile(
                            title: Text(widget.labelFor(item)),
                            enabled: item.enabled,
                            selected: item.value == widget.selected,
                            trailing: item.value == widget.selected
                                ? const Icon(Icons.check)
                                : null,
                            onTap: item.enabled
                                ? () => Navigator.pop(context, item.value)
                                : null,
                          );
                        },
                      ),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
