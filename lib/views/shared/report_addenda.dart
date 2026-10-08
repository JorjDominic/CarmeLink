import 'package:flutter/material.dart';

import '../../core/widgets/common_widgets.dart';
import '../../services/confidential_report_service.dart';

class ReportAddenda extends StatefulWidget {
  const ReportAddenda({required this.reportId, super.key});

  final String reportId;

  @override
  State<ReportAddenda> createState() => _ReportAddendaState();
}

class _ReportAddendaState extends State<ReportAddenda> {
  static const _service = ConfidentialReportService();

  final _text = TextEditingController();
  late Future<List<ConfidentialReportAddendum>> _entries;
  bool _saving = false;
  String? _error;
  String? _pendingRequestId;
  String? _pendingRequestBody;

  @override
  void initState() {
    super.initState();
    _entries = _service.listAddenda(widget.reportId);
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _resetPendingRequest() {
    _pendingRequestId = null;
    _pendingRequestBody = null;
  }

  String _requestIdFor(String body) {
    if (_pendingRequestId != null && _pendingRequestBody == body) {
      return _pendingRequestId!;
    }
    _pendingRequestBody = body;
    _pendingRequestId = _service.createCorrectionRequestId();
    return _pendingRequestId!;
  }

  Future<bool> _confirmAddendum(String body) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm report addendum'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This will permanently append the correction or additional details to the report. '
              'The original report remains unchanged.',
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    Theme.of(dialogContext).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(body),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm and add'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _refreshAfterSave() async {
    final latest = await _service.listAddenda(widget.reportId);
    if (!mounted) return;
    setState(() {
      _entries = Future.value(latest);
    });
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() {
      _entries = _service.listAddenda(widget.reportId);
    });
  }

  Future<void> _save() async {
    if (_saving) return;

    final body = _text.text.trim();
    if (body.length < 5) {
      setState(() => _error = 'Enter at least 5 characters.');
      return;
    }

    final confirmed = await _confirmAddendum(body);
    if (!confirmed || !mounted) return;

    final requestId = _requestIdFor(body);

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await _service.addCorrection(
        widget.reportId,
        body,
        requestId: requestId,
      );

      if (!mounted) return;

      _text.clear();
      _resetPendingRequest();

      var refreshSucceeded = true;
      try {
        await _refreshAfterSave();
      } catch (_) {
        refreshSucceeded = false;
      }

      if (!mounted) return;
      showAppSnackBar(
        context,
        refreshSucceeded
            ? 'Correction added to the report.'
            : 'Correction saved. Refresh to load the latest report history.',
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not save the correction. Please retry.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      initiallyExpanded: true,
      tilePadding: EdgeInsets.zero,
      title: const Text('Messages and additional details'),
      subtitle: const Text('The original report is preserved.'),
      children: [
        FutureBuilder<List<ConfidentialReportAddendum>>(
          future: _entries,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _reload,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry loading corrections'),
                ),
              );
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final entries = snapshot.data!;
            if (entries.isEmpty) {
              return const Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No corrections or addenda have been recorded.'),
                ),
              );
            }
            return Column(
              children: [
                for (final entry in entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history_edu_outlined),
                    title: SelectableText(entry.body),
                    subtitle: Text(
                      '${entry.authorName} • ${entry.authorRole} • ${shortDate(entry.createdAt)} ${timeText(entry.createdAt)}',
                    ),
                  ),
              ],
            );
          },
        ),
        TextField(
          controller: _text,
          enabled: !_saving,
          onChanged: (value) {
            if (value.trim() != _pendingRequestBody) {
              _resetPendingRequest();
            }
            if (_error != null) {
              setState(() => _error = null);
            }
          },
          maxLength: 2000,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(
            labelText: 'Message, correction or additional details',
            helperText: 'Add a follow-up message or correction to this report.',
            errorText: _error,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_comment_outlined),
            label: Text(_saving ? 'Saving...' : 'Add to report'),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
