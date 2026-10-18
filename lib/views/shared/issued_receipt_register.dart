import '../../core/widgets/record_details.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../controllers/session_controller.dart';
import '../../core/utils/database_write_outcome.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/models.dart';
import '../../services/issued_receipt_service.dart';
import '../../services/receipt_print_service.dart';
import '../../services/secure_media_service.dart';

class IssuedReceiptRegister extends StatefulWidget {
  const IssuedReceiptRegister(
      {super.key,
      required this.receipt,
      this.canManage,
      this.service = const IssuedReceiptService()});
  final bool? canManage;
  final PaymentReceipt receipt;
  final IssuedReceiptService service;
  @override
  State<IssuedReceiptRegister> createState() => _IssuedReceiptRegisterState();
}

class _IssuedReceiptRegisterState extends State<IssuedReceiptRegister> {
  late Future<List<Map<String, dynamic>>> rows =
      widget.service.list(widget.receipt.id);
  bool busy = false;
  String? error;
  bool get staff =>
      widget.canManage ??
      [UserRole.owner, UserRole.caretaker]
          .contains(SessionController.instance.currentUser?.role);
  void reload() => setState(() {
        rows = widget.service.list(widget.receipt.id);
      });

  Future<void> attachment(String reference) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final url =
          await const SecureMediaService().createAuthorizedUrl(reference);
      if (url == null) throw StateError('Unavailable');
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                  scrollable: true,
                  title: const Text('Issued receipt photo'),
                  content: SizedBox(
                      width: 600,
                      height: 450,
                      child: InteractiveViewer(
                          child: Image.network(url,
                              errorBuilder: (_, error, stack) => const Text(
                                  'Could not load the photo. Close and try again.')))),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'))
                  ]));
    } catch (_) {
      if (mounted)
        setState(() => error = 'Could not open the receipt photo. Try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> voidReceipt(Map<String, dynamic> row) async {
    var reason = '';
    final result = await showDialog<String>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, update) => AlertDialog(
                    scrollable: true,
                    title: Text('Void receipt ${row['receipt_number']}?'),
                    content: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Text(
                          'The payment stays verified. This receipt remains in history; you can record its replacement afterward.'),
                      TextField(
                          maxLength: 500,
                          maxLines: 3,
                          decoration:
                              const InputDecoration(labelText: 'Reason'),
                          onChanged: (value) => update(() => reason = value)),
                    ]),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel')),
                      FilledButton(
                          onPressed: reason.trim().length < 3
                              ? null
                              : () => Navigator.pop(context, reason.trim()),
                          child: const Text('Void receipt'))
                    ])));

    if (result == null || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.service.voidReceipt(row['id'] as String, result);
      reload();
    } catch (_) {
      if (mounted)
        setState(() => error =
            'Could not confirm voiding. Reload or retry before recording a replacement.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<
          List<Map<String, dynamic>>>(
      future: rows,
      builder: (context, snapshot) {
        if (snapshot.hasError)
          return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Could not load issued receipt records.'),
                TextButton(
                    onPressed: busy ? null : reload,
                    child: const Text('Reload issued receipts'))
              ]);
        if (!snapshot.hasData) return const LinearProgressIndicator();
        final records = snapshot.data!;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Divider(),
          const Text('Issued receipt records',
              style: TextStyle(fontWeight: FontWeight.bold)),
          if (records.isEmpty) const Text('No issued receipt number recorded.'),
          if (error != null) Text(error!),
          for (final row in records)
            Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SelectableText(
                          '${row['receipt_number']}${row['environment'] == 'test' ? ' (TEST)' : ''} · ${row['status']}'),
                      const SizedBox(height: 8),
                      RecordFacts(items: [
                        ('Issued', row['issued_on'].toString()),
                        ('Recorded', row['created_at'].toString())
                      ]),
                      if (row['replaces_id'] != null)
                        const Text('Replacement receipt'),
                      if (row['void_reason'] != null)
                        Text(
                            'Void reason: ${row['void_reason']} · ${row['voided_at']}'),
                      Wrap(spacing: 8, children: [
                        if (row['photo_path'] != null)
                          TextButton(
                              onPressed: busy
                                  ? null
                                  : () =>
                                      attachment(row['photo_path'] as String),
                              child: const Text('View receipt photo')),
                        if (staff && row['status'] == 'issued')
                          TextButton(
                              onPressed: busy ? null : () => voidReceipt(row),
                              child: const Text('Void receipt')),
                      ]),
                    ])),
          if (staff && !records.any((r) => r['status'] == 'issued'))
            OutlinedButton(
                onPressed: busy
                    ? null
                    : () async {
                        await showDialog<bool>(
                            context: context,
                            barrierDismissible: false,
                            builder: (_) => _RecordReceiptDialog(
                                receipt: widget.receipt,
                                service: widget.service));
                        if (mounted) reload();
                      },
                child: const Text('Record issued receipt')),
        ]);
      });
}

class _RecordReceiptDialog extends StatefulWidget {
  const _RecordReceiptDialog({required this.receipt, required this.service});
  final PaymentReceipt receipt;
  final IssuedReceiptService service;
  @override
  State<_RecordReceiptDialog> createState() => _RecordReceiptDialogState();
}

class _RecordReceiptDialogState extends State<_RecordReceiptDialog> {
  final number = TextEditingController();
  String id = IssuedReceiptService.requestId();
  DateTime date = DateTime.now();
  XFile? photo;
  String? uploaded, error;
  bool busy = false, submitted = false;
  @override
  void dispose() {
    number.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (number.text.trim().isEmpty || busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (photo != null && uploaded == null) {
        final bytes = await photo!.readAsBytes();
        if (bytes.length > 5 * 1024 * 1024)
          throw StateError('Choose a photo smaller than 5 MB.');
        final name = photo!.name.toLowerCase();
        final mime = name.endsWith('.png')
            ? 'image/png'
            : name.endsWith('.webp')
                ? 'image/webp'
                : 'image/jpeg';
        uploaded = await const SecureMediaService().uploadImage(
            kind: 'payment',
            recordId: widget.receipt.chargeId,
            bytes: bytes,
            mimeType: mime);
      }
      // Freeze the payload after submission: a lost response must retry the same request.
      submitted = true;
      await widget.service.record(
          id: id,
          transactionId: widget.receipt.id,
          number: number.text.trim(),
          date: date.toIso8601String().substring(0, 10),
          photo: uploaded);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (isConfirmedDatabaseRejection(e)) {
        submitted = false;
        id = IssuedReceiptService.requestId();
        if (mounted)
          setState(() => error = e is PostgrestException && e.code == '23505'
              ? 'This receipt number or payment already has an issued receipt. Check the number or reload the history.'
              : 'Receipt was not saved. Check the number, date and payment status, then try again.');
        return;
      }
      if (mounted)
        setState(() => error = submitted
            ? 'Could not confirm saving. Retry with these same details. If the number is already in use, close and reload the receipt history.'
            : 'Could not upload the photo. Use a JPG, PNG or WebP under 5 MB and try again.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
      canPop: !busy,
      child: AlertDialog(
        scrollable: true,
        title: Text(
            'Record issued receipt${widget.receipt.isTest ? ' (TEST)' : ''}'),
        content: SizedBox(
            width: 440,
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                      'Enter the number from the receipt issued by management. This links it to the verified payment.'),
                  TextField(
                      controller: number,
                      enabled: !busy && !submitted,
                      maxLength: 80,
                      decoration: const InputDecoration(
                          labelText: 'Actual receipt number'),
                      onChanged: (_) => setState(() {})),
                  TextButton(
                      onPressed: busy || submitted
                          ? null
                          : () async {
                              final earliest =
                                  widget.receipt.receivedAt.toLocal();
                              final picked = await showDatePicker(
                                  context: context,
                                  initialDate: date,
                                  firstDate: DateTime(earliest.year,
                                      earliest.month, earliest.day),
                                  lastDate: DateTime.now());
                              if (picked != null && mounted)
                                setState(() => date = picked);
                            },
                      child: Text(
                          'Issued date: ${date.toIso8601String().substring(0, 10)}')),
                  TextButton.icon(
                      onPressed: busy || submitted
                          ? null
                          : () async {
                              try {
                                final picked = await ImagePicker()
                                    .pickImage(source: ImageSource.gallery);
                                if (picked != null && mounted)
                                  setState(() {
                                    photo = picked;
                                    uploaded = null;
                                  });
                              } catch (_) {
                                if (mounted)
                                  setState(() => error =
                                      'Could not select a photo. Try again.');
                              }
                            },
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                          photo?.name ?? 'Attach receipt photo (optional)')),
                  if (error != null) Text(error!),
                ])),
        actions: [
          TextButton(
              onPressed: busy ? null : () => Navigator.pop(context),
              child: const Text('Close')),
          FilledButton(
              onPressed: busy || number.text.trim().isEmpty ? null : save,
              child: Text(busy
                  ? 'Saving…'
                  : submitted
                      ? 'Retry saving'
                      : 'Save receipt'))
        ],
      ));
}
