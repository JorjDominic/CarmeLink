import 'package:flutter/material.dart';
import '../../services/report_subject_service.dart';

class ReportSubjectField extends StatelessWidget {
  const ReportSubjectField(
      {super.key,
      required this.value,
      required this.onChanged,
      this.enabled = true,
      this.service = const ReportSubjectService()});
  final ReportSubject? value;
  final ValueChanged<ReportSubject?> onChanged;
  final bool enabled;
  final ReportSubjectService service;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Tenant involved (optional)',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const Text(
            'Select one tenant this concern is about. Leave blank if unknown or not applicable. Selection is an allegation for staff review.'),
        Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (value != null) Text(value!.name),
              OutlinedButton.icon(
                  icon: const Icon(Icons.person_search_outlined),
                  label: Text(value == null ? 'Find tenant' : 'Change tenant'),
                  onPressed: !enabled
                      ? null
                      : () async {
                          final selected = await showDialog<ReportSubject>(
                              context: context,
                              builder: (_) => _SubjectSearch(service: service));
                          if (selected != null && context.mounted)
                            onChanged(selected);
                        }),
              if (value != null)
                TextButton(
                    onPressed: enabled ? () => onChanged(null) : null,
                    child: const Text('Clear')),
            ]),
      ]);
}

class _SubjectSearch extends StatefulWidget {
  const _SubjectSearch({required this.service});
  final ReportSubjectService service;
  @override
  State<_SubjectSearch> createState() => _SubjectSearchState();
}

class _SubjectSearchState extends State<_SubjectSearch> {
  final query = TextEditingController();
  List<ReportSubject> results = [];
  String? error;
  bool loading = false, searched = false;
  int generation = 0, offset = 0;
  void changed(String _) {
    generation++;
    setState(() {
      results = [];
      error = null;
      loading = false;
      searched = false;
      offset = 0;
    });
  }

  Future<void> search({int pageOffset = 0}) async {
    final text = query.text.trim();
    if (text.length < 2 || text.length > 80) {
      setState(() => error = 'Enter 2 to 80 characters of the tenant name.');
      return;
    }
    final request = ++generation;
    setState(() {
      loading = true;
      error = null;
      results = [];
      searched = false;
    });
    try {
      final values = await widget.service.search(text, offset: pageOffset);
      if (mounted && request == generation)
        setState(() {
          results = values;
          offset = pageOffset;
          loading = false;
          searched = true;
        });
    } catch (_) {
      if (mounted && request == generation)
        setState(() {
          loading = false;
          error =
              'Tenant search is unavailable. Retry, or leave the tenant unspecified and describe the concern.';
        });
    }
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          scrollable: true,
          title: const Text('Select tenant involved'),
          content: SizedBox(
              width: 480,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(
                    controller: query,
                    maxLength: 80,
                    onChanged: changed,
                    onSubmitted: (_) => search(),
                    decoration: const InputDecoration(
                        labelText: 'Search by tenant name')),
                TextButton(
                    onPressed: loading ? null : search,
                    child: const Text('Search')),
                if (loading) const LinearProgressIndicator(),
                if (error != null) Text(error!),
                if (searched && results.isEmpty)
                  const Text(
                      'No matching tenants. Try another name, or leave the tenant unspecified.'),
                for (final tenant in results)
                  ListTile(
                      title: Text(tenant.name),
                      onTap: () => Navigator.pop(context, tenant)),
                if (searched)
                  Wrap(spacing: 8, children: [
                    if (offset > 0)
                      TextButton(
                          onPressed: () => search(pageOffset: offset - 20),
                          child: const Text('Previous')),
                    if (results.length == 20)
                      TextButton(
                          onPressed: () => search(pageOffset: offset + 20),
                          child: const Text('Next')),
                  ]),
                const Text(
                    'If names are ambiguous, leave the tenant unspecified and describe identifying details for staff.'),
              ])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'))
          ]);
}
