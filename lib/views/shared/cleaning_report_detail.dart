import 'package:flutter/material.dart';

import '../../controllers/session_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/room_operations_service.dart';

/// Opens the exact cleaning-duty report referenced by a notification.
///
/// Row-level security remains authoritative: owners/caretakers can read any
/// report while a tenant can read only reports that they submitted.
class CleaningReportDetail extends StatefulWidget {
  const CleaningReportDetail({required this.reportId, super.key});

  final String reportId;

  @override
  State<CleaningReportDetail> createState() => _CleaningReportDetailState();
}

class _CleaningReportDetailState extends State<CleaningReportDetail> {
  final RoomOperationsService _service = const RoomOperationsService();
  final TextEditingController _staffNotes = TextEditingController();

  CleaningNoncomplianceReport? _report;
  String _status = 'open';
  bool _loading = true;
  bool _saving = false;
  String? _errorMessage;

  bool get _isStaff {
    final role = SessionController.instance.currentUser?.role;
    return role == UserRole.owner || role == UserRole.caretaker;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _staffNotes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
    }

    try {
      final report = await _service.getCleaningReport(widget.reportId);
      if (!mounted) return;
      setState(() {
        _report = report;
        _status = report.status;
        _staffNotes.text = report.staffNotes;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = roomOperationsError(error);
      });
    }
  }

  Future<void> _saveReview() async {
    final report = _report;
    if (report == null || !_isStaff) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      await _service.updateCleaningReport(
        report: report,
        status: _status,
        staffNotes: _staffNotes.text,
      );
      if (!mounted) return;
      showAppSnackBar(context, 'Cleaning report updated.');
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = roomOperationsError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;

    return PageFrame(
      title: 'Cleaning report',
      subtitle: report?.reportedBedLabel ?? 'Report details',
      onRefresh: _load,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_errorMessage != null) ...[
            CarmelitaCard(
              child: Row(
                children: [
                  const Icon(Icons.error_outline),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_errorMessage!)),
                  TextButton(
                      onPressed: _loading ? null : _load,
                      child: const Text('Retry')),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (!_loading && report != null) ...[
            CarmelitaCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          report.reportedBedLabel,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      StatusPill(report.status),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Report details',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  SelectableText(report.description),
                  const SizedBox(height: 12),
                  Text(
                    'Submitted ${shortDate(report.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_isStaff)
              CarmelitaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Staff review',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(value: 'open', child: Text('Open')),
                        DropdownMenuItem(
                          value: 'reviewing',
                          child: Text('Reviewing'),
                        ),
                        DropdownMenuItem(
                          value: 'resolved',
                          child: Text('Resolved'),
                        ),
                        DropdownMenuItem(
                          value: 'dismissed',
                          child: Text('Dismissed'),
                        ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _status = value);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _staffNotes,
                      enabled: !_saving,
                      maxLength: 2000,
                      minLines: 2,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        labelText: 'Staff notes',
                        hintText:
                            'Required before resolving or dismissing the report',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: _saving ? null : _saveReview,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(_saving ? 'Saving…' : 'Save review'),
                      ),
                    ),
                  ],
                ),
              )
            else if (report.staffNotes.trim().isNotEmpty)
              CarmelitaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Staff update',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(report.staffNotes),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}
