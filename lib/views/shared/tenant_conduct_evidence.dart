import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/utils/database_write_outcome.dart';
import '../../services/tenant_conduct_evidence_service.dart';

class TenantConductSubmissionDialog extends StatefulWidget {
  const TenantConductSubmissionDialog(
      {super.key,
      required this.caseId,
      required this.appeal,
      this.service = const TenantConductEvidenceService()});
  final String caseId;
  final bool appeal;
  final TenantConductEvidenceService service;
  @override
  State<TenantConductSubmissionDialog> createState() =>
      _TenantConductSubmissionDialogState();
}

class _TenantConductSubmissionDialogState
    extends State<TenantConductSubmissionDialog> {
  final statement = TextEditingController(), support = TextEditingController();
  final id = TenantConductEvidenceService.requestId();
  final photos = <TenantEvidenceDraft>[];
  final uploaded = <String>{};
  bool busy = false, uncertain = false, saved = false;
  String? error;
  @override
  void dispose() {
    statement.dispose();
    support.dispose();
    if (!saved && !uncertain) {
      for (final path in uploaded) {
        unawaited(widget.service.cleanup(path).catchError((_) {}));
      }
    }
    super.dispose();
  }

  Future<void> pick() async {
    setState(() => busy = true);
    try {
      final photo = await widget.service.pickPhoto();
      if (photo != null && mounted) setState(() => photos.add(photo));
    } catch (_) {
      if (mounted)
        setState(() => error =
            'Could not select the photo. Choose a JPG, PNG or WebP up to 5 MB.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submit() async {
    if (busy) return;
    final min = widget.appeal ? 10 : 5;
    if (statement.text.trim().length < min) {
      setState(
          () => error = 'Enter at least $min characters in your statement.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final attachments = <Map<String, dynamic>>[];
      for (final photo in photos) {
        final path = await widget.service.upload(widget.caseId, id, photo);
        uploaded.add(path);
        attachments.add({
          'storage_path': path,
          'original_name': photo.name,
          'content_type': photo.mime,
          'size_bytes': photo.bytes.length,
          'caption': photo.caption.trim()
        });
      }
      uncertain = true;
      await widget.service.submit(
          id: id,
          caseId: widget.caseId,
          kind: widget.appeal ? 'appeal' : 'response',
          statement: statement.text,
          support: widget.appeal ? support.text : '',
          photos: attachments);
      saved = true;
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (isConfirmedDatabaseRejection(e)) uncertain = false;
      if (mounted)
        setState(() => error = uncertain
            ? 'Could not confirm submission. Retry with these same details, or close and reload the case before submitting again.'
            : 'Submission was not saved. Check your connection and whether responses or appeals are still open, then try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: AlertDialog(
        scrollable: true,
        title:
            Text(widget.appeal ? 'Submit conduct appeal' : 'Submit response'),
        content: SizedBox(
            width: 560,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Explain your side and optionally attach up to five photos. Your statement and photos are shared with authorized staff; submitting them does not decide the case.'),
                  TextField(
                      controller: statement,
                      enabled: !busy && !uncertain,
                      minLines: 4,
                      maxLines: 7,
                      maxLength: 4000,
                      decoration: InputDecoration(
                          labelText: widget.appeal
                              ? 'Appeal statement'
                              : 'Your response')),
                  if (widget.appeal)
                    TextField(
                        controller: support,
                        enabled: !busy && !uncertain,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 4000,
                        decoration: const InputDecoration(
                            labelText: 'Supporting information (optional)')),
                  for (final photo in photos)
                    Padding(
                        key: ValueKey(photo.fileId),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Image.memory(photo.bytes,
                                  height: 100,
                                  errorBuilder: (_, e, s) =>
                                      const Text('Photo preview unavailable')),
                              Text(photo.name),
                              TextFormField(
                                  initialValue: photo.caption,
                                  enabled: !busy && !uncertain,
                                  maxLength: 1000,
                                  onChanged: (v) => photo.caption = v,
                                  decoration: const InputDecoration(
                                      labelText: 'Photo caption (optional)')),
                              TextButton(
                                  onPressed: busy || uncertain
                                      ? null
                                      : () =>
                                          setState(() => photos.remove(photo)),
                                  child: const Text('Remove photo')),
                            ])),
                  if (photos.length < 5)
                    OutlinedButton.icon(
                        onPressed: busy || uncertain ? null : pick,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Attach evidence photo')),
                  if (error != null) Text(error!),
                ])),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context, false),
              child: const Text('Close')),
          FilledButton(
              onPressed: busy ? null : submit,
              child: Text(busy
                  ? 'Submitting…'
                  : uncertain
                      ? 'Retry submission'
                      : widget.appeal
                          ? 'Submit appeal'
                          : 'Submit response'))
        ],
      ));
}

class TenantConductEvidencePanel extends StatefulWidget {
  const TenantConductEvidencePanel(
      {super.key,
      required this.caseId,
      this.responseId,
      this.appealId,
      this.service = const TenantConductEvidenceService()});
  final String caseId;
  final String? responseId, appealId;
  final TenantConductEvidenceService service;
  @override
  State<TenantConductEvidencePanel> createState() =>
      _TenantConductEvidencePanelState();
}

class _TenantConductEvidencePanelState
    extends State<TenantConductEvidencePanel> {
  late Future<List<Map<String, dynamic>>> rows = load();
  String? error;
  Future<List<Map<String, dynamic>>> load() => widget.service.list(
      caseId: widget.caseId,
      responseId: widget.responseId,
      appealId: widget.appealId);
  Future<void> open(Map<String, dynamic> row) async {
    try {
      final url = await widget.service.preview(row['storage_path'] as String);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                  title: const Text('Tenant evidence photo'),
                  content: SizedBox(
                      width: 600,
                      height: 450,
                      child: InteractiveViewer(
                          child: Image.network(url,
                              errorBuilder: (_, e, s) => const Text(
                                  'Could not load photo. Close and try again.')))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'))
                  ]));
    } catch (_) {
      if (mounted)
        setState(() => error = 'Could not open the photo. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
          future: rows,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return TextButton(
                  onPressed: () => setState(() => rows = load()),
                  child: const Text('Could not load evidence. Retry'));
            if (!snapshot.hasData) return const LinearProgressIndicator();
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (error != null) Text(error!),
                  for (final row in snapshot.data!)
                    ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.image_outlined),
                        title: Text(row['caption'] as String? ?? ''),
                        subtitle: Text(
                            'Tenant evidence · ${row['original_name']} · ${row['created_at']}'),
                        trailing: IconButton(
                            tooltip: 'View evidence photo',
                            onPressed: () => open(row),
                            icon: const Icon(Icons.open_in_new))),
                ]);
          });
}
