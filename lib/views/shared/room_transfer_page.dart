import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../controllers/session_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/room_transfer_service.dart';
import '../../services/table_refresh_subscription.dart';
import '../../services/tenant_service.dart';
import 'signature_pad_dialog.dart';

class RoomTransferPage extends StatefulWidget {
  const RoomTransferPage(
      {super.key, this.tenantId, this.service = const RoomTransferService()});
  final String? tenantId;
  final RoomTransferService service;
  @override
  State<RoomTransferPage> createState() => _RoomTransferPageState();
}

class _RoomTransferPageState extends State<RoomTransferPage> {
  List<RoomTransfer> _items = [];
  String? _error;
  bool _loading = true, _busy = false;
  final _viewed = <String>{};
  late final TableRefreshSubscription _subscription;
  bool get _owner =>
      SessionController.instance.currentUser?.role == UserRole.owner;

  @override
  void initState() {
    super.initState();
    _load();
    _subscription = TableRefreshSubscription(
        'room-transfers', ['room_transfers', 'room_transfer_signers'], _load);
  }

  @override
  void dispose() {
    _subscription.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final rows = await widget.service.list(tenantId: widget.tenantId);
      if (mounted)
        setState(() {
          _items = rows;
          _loading = false;
          _error = null;
        });
    } catch (error) {
      if (mounted)
        setState(() {
          _error = _message(error);
          _loading = false;
        });
    }
  }

  String _message(Object error) =>
      error is PostgrestException ? error.message : error.toString();
  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } catch (error) {
      await _load();
      if (mounted) showAppSnackBar(context, _message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _note(String title,
      {String label = 'Reason / note', int minLength = 3}) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text(title),
                content: TextField(
                    controller: controller,
                    maxLength: 1500,
                    minLines: 2,
                    maxLines: 4,
                    decoration: InputDecoration(labelText: label)),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () {
                        if (controller.text.trim().length >= minLength)
                          Navigator.pop(context, controller.text.trim());
                      },
                      child: const Text('Confirm'))
                ]));
    controller.dispose();
    return result;
  }

  Future<void> _propose() async {
    if (widget.tenantId == null) return;
    await _run(() async {
      final rooms =
          await const TenantService().loadAvailableBedsGroupedByRoom();
      if (!mounted) return;
      final beds = rooms.expand((room) => room.beds).toList();
      if (beds.isEmpty) {
        showAppSnackBar(context, 'No available destination beds.');
        return;
      }
      final draft = await showDialog<RoomTransferDraft>(
          context: context,
          builder: (_) => RoomTransferProposalDialog(beds: beds));
      if (draft == null) return;
      final transfer = await widget.service.propose(
          tenantId: widget.tenantId!,
          bedId: draft.bedId,
          effectiveOn: draft.effectiveOn,
          reason: draft.reason);
      await _load();
      await widget.service.publish(transfer);
      if (mounted)
        showAppSnackBar(context,
            'Notice sent. The destination is reserved; the current room stays active.');
    });
  }

  Future<void> _openDocument(RoomTransfer transfer) async {
    await _run(() async {
      if (transfer.documentPath == null) return;
      final bytes = await widget.service.downloadAmendment(transfer);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => Scaffold(
              appBar: AppBar(title: const Text('Room transfer amendment')),
              body: PdfPreview(
                  build: (_) async => bytes,
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  pdfFileName:
                      '${transfer.contractNumber}-room-amendment.pdf'))));
      if (mounted) setState(() => _viewed.add(transfer.documentHash!));
    });
  }

  Future<void> _sign(RoomTransfer transfer, RoomTransferSigner signer) async {
    if (!_viewed.contains(transfer.documentHash)) {
      showAppSnackBar(
          context, 'Open and review the amendment PDF before signing.');
      return;
    }
    final user = SessionController.instance.currentUser;
    if (user == null) return;
    final bytes = await showSignaturePadDialog(context,
        signerName: user.name,
        contractNumber: '${transfer.contractNumber} / room amendment',
        agreementText:
            'I have reviewed this room transfer amendment and agree to the stated room, bed, effective date, and unchanged rent and deposit. This is my own signature.');
    if (bytes != null)
      await _run(() => widget.service.sign(transfer, signer.role, bytes));
  }

  Future<void> _recordSignedCopy(
      RoomTransfer transfer, RoomTransferSigner signer) async {
    if (!_viewed.contains(transfer.documentHash)) {
      showAppSnackBar(context,
          'Review the amendment PDF before recording its signed copy.');
      return;
    }
    final name = await _note('Record the actual ${signer.role} signature',
        label: 'Signer name (upload their signed copy next)', minLength: 2);
    if (name == null || !mounted) return;
    final file = await FilePicker.pickFile(
        type: FileType.custom, allowedExtensions: const ['png', 'jpg', 'jpeg']);
    if (file == null) return;
    await _run(() async => widget.service.sign(
        transfer, signer.role, await file.readAsBytes(),
        signerName: name,
        mimeType: file.extension?.toLowerCase() == 'png'
            ? 'image/png'
            : 'image/jpeg'));
  }

  Future<void> _viewSignature(RoomTransferSigner signer) async {
    await _run(() async {
      final bytes = await widget.service.download(signer.path!);
      if (!mounted) return;
      await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
                  title: Text('${signer.role} signature'),
                  content: SizedBox(
                      width: 400, height: 220, child: Image.memory(bytes)),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close'))
                  ]));
    });
  }

  Future<void> _review(RoomTransferSigner signer, bool approved) async {
    final note = await _note(
        approved ? 'Verify this signature' : 'Reject this signature');
    if (note != null)
      await _run(() => widget.service.review(signer.id, approved, note));
  }

  Future<void> _complete(RoomTransfer transfer) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Confirm room move'),
                content: Text(
                    'Confirm that ${transfer.tenantName} is moving from ${transfer.source} to ${transfer.destination}. The old bed will be released. Rent and deposit stay unchanged.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Confirm move'))
                ]));
    if (confirm == true) await _run(() => widget.service.complete(transfer.id));
  }

  @override
  Widget build(BuildContext context) => PageFrame(
      title: 'Room transfers',
      subtitle: 'Notice → signed amendment → owner confirms the move',
      maxWidth: 900,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text(
            'Your current room stays active while the destination bed is reserved. Original contract dates, rent, and security deposit remain unchanged.'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, children: [
          OutlinedButton.icon(
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh')),
          if (_owner && widget.tenantId != null)
            FilledButton.icon(
                key: const Key('propose-room-transfer'),
                onPressed:
                    _busy || _items.any((t) => t.pending) ? null : _propose,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Propose room transfer'))
        ]),
        if (_busy || _loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(padding: const EdgeInsets.all(12), child: Text(_error!)),
        if (!_loading && _error == null && _items.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                  'No room transfers yet. The owner can propose one from the tenant’s occupied bed in Room management.')),
        for (final transfer in _items) _card(transfer),
      ]));
  Widget _card(RoomTransfer t) {
    final user = SessionController.instance.currentUser;
    final today = DateUtils.dateOnly(DateTime.now());
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.tenantName,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text('${t.source} → ${t.destination}'),
                  Text(
                      'Effective: ${t.effectiveOn.toIso8601String().split('T').first} · ${t.status.replaceAll('_', ' ')}'),
                  Text('Reason: ${t.reason}'),
                  Text(
                      'Monthly rent: ₱${t.monthlyRent.toStringAsFixed(2)} · Deposit: ₱${t.securityDeposit.toStringAsFixed(2)} (unchanged)'),
                  if (t.row['cancellation_reason'] != null)
                    Text('Cancelled: ${t.row['cancellation_reason']}'),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, children: [
                    if (t.documentPath != null)
                      OutlinedButton.icon(
                          onPressed: _busy ? null : () => _openDocument(t),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text('Review amendment PDF')),
                    if (_owner && t.status == 'draft')
                      FilledButton(
                          onPressed: _busy
                              ? null
                              : () => _run(() => widget.service.publish(t)),
                          child:
                              const Text('Generate amendment & send notice')),
                  ]),
                  for (final signer in t.signers)
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                  '${signer.role.toUpperCase()}: ${signer.status}${signer.name == null ? '' : ' · ${signer.name}'}'),
                              if (signer.reviewNote != null)
                                Text(signer.reviewNote!),
                              Wrap(spacing: 8, children: [
                                if (signer.path != null)
                                  TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _viewSignature(signer),
                                      child: const Text('View signature')),
                                if (t.status == 'awaiting_signatures' &&
                                    signer.canSign &&
                                    ((_owner && signer.role == 'lessor') ||
                                        (signer.userId == user?.id &&
                                            signer.role != 'lessor')))
                                  FilledButton(
                                      onPressed:
                                          _busy ? null : () => _sign(t, signer),
                                      child: Text('Sign as ${signer.role}')),
                                if (_owner &&
                                    t.status == 'awaiting_signatures' &&
                                    signer.canSign &&
                                    ['guardian', 'witness']
                                        .contains(signer.role))
                                  OutlinedButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _recordSignedCopy(t, signer),
                                      child: Text(
                                          'Record ${signer.role} signed copy')),
                                if (_owner &&
                                    t.status == 'awaiting_signatures' &&
                                    signer.status == 'signed') ...[
                                  TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _review(signer, true),
                                      child: const Text('Verify')),
                                  TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => _review(signer, false),
                                      child: const Text('Reject')),
                                ],
                              ]),
                            ])),
                  if (_owner && t.pending)
                    Wrap(spacing: 8, children: [
                      FilledButton(
                          key: ValueKey('complete-room-transfer-${t.id}'),
                          onPressed: _busy ||
                                  !t.allVerified ||
                                  today.isBefore(t.effectiveOn)
                              ? null
                              : () => _complete(t),
                          child: const Text('Confirm room move')),
                      TextButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  final reason =
                                      await _note('Cancel room transfer');
                                  if (reason != null)
                                    await _run(() =>
                                        widget.service.cancel(t.id, reason));
                                },
                          child: const Text('Cancel transfer')),
                    ]),
                  if (t.pending &&
                      t.allVerified &&
                      today.isBefore(t.effectiveOn))
                    const Text(
                        'Signatures are verified. Confirmation opens on the agreed date.'),
                ])));
  }
}

class RoomTransferDraft {
  const RoomTransferDraft(this.bedId, this.effectiveOn, this.reason);
  final String bedId, reason;
  final DateTime effectiveOn;
}

class RoomTransferProposalDialog extends StatefulWidget {
  const RoomTransferProposalDialog({super.key, required this.beds});
  final List<AvailableBed> beds;
  @override
  State<RoomTransferProposalDialog> createState() =>
      _RoomTransferProposalDialogState();
}

class _RoomTransferProposalDialogState
    extends State<RoomTransferProposalDialog> {
  String? _bedId;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  final _reason = TextEditingController();
  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
          title: const Text('Propose room transfer'),
          content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Destination bed'),
                    items: widget.beds
                        .map((b) => DropdownMenuItem(
                            value: b.id,
                            child: Text('Room ${b.room} / ${b.label}',
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (value) => setState(() => _bedId = value)),
                TextButton(
                    onPressed: () async {
                      final selected = await showDatePicker(
                          context: context,
                          initialDate: _date,
                          firstDate: DateUtils.dateOnly(DateTime.now()),
                          lastDate: DateTime(2100));
                      if (selected != null && mounted)
                        setState(() => _date = selected);
                    },
                    child: Text(
                        'Effective date: ${_date.toIso8601String().split('T').first}')),
                TextField(
                    controller: _reason,
                    minLines: 2,
                    maxLines: 4,
                    maxLength: 1500,
                    decoration: const InputDecoration(
                        labelText: 'Reason / notice to tenant')),
                const Text(
                    'The destination will be reserved. Rent, deposit, and contract dates remain unchanged. The tenant must sign before the owner confirms the move.'),
              ]))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (_bedId == null || _reason.text.trim().length < 3) {
                    showAppSnackBar(context,
                        'Choose a destination and document the reason.');
                    return;
                  }
                  Navigator.pop(context,
                      RoomTransferDraft(_bedId!, _date, _reason.text.trim()));
                },
                child: const Text('Prepare amendment'))
          ]);
}
