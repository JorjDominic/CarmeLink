import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../controllers/owner_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/widgets/role_guard.dart';
import '../../core/widgets/searchable_dropdown.dart';
import '../../models/models.dart';
import '../../services/payment_service.dart';
import '../../services/receipt_print_service.dart';

Future<void> showStaffPaymentReceived(BuildContext context) async {
  await OwnerController.instance.loadPayments(force: true);
  if (!context.mounted) return;
  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RoleGuard(
      allowedRoles: const {UserRole.owner, UserRole.caretaker},
      child: StaffPaymentReceivedDialog(
        payments: OwnerController.instance.payments,
      ),
    ),
  );
  if (saved == true) {
    await OwnerController.instance.loadPayments(force: true);
    if (context.mounted) {
      showAppSnackBar(context, 'Payment recorded. Tenant balance updated.');
    }
  }
}

class StaffPaymentReceivedDialog extends StatefulWidget {
  const StaffPaymentReceivedDialog({super.key, required this.payments});
  final List<Payment> payments;

  @override
  State<StaffPaymentReceivedDialog> createState() =>
      _StaffPaymentReceivedDialogState();
}

class _StaffPaymentReceivedDialogState
    extends State<StaffPaymentReceivedDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  final _picker = ImagePicker();
  late final String _requestId;
  Payment? _bill;
  String _billGroup = 'overdue';
  DateTime _receivedOn = DateTime.now();
  Uint8List? _photo;
  String? _filename, _mimeType, _error;
  bool _saving = false;
  bool _picking = false;
  bool _submitted = false;

  List<Payment> get _eligible => widget.payments
      .where((p) =>
          !p.isDeposit &&
          !p.isVoided &&
          !p.isPending &&
          p.outstandingAmount > 0)
      .toList();

  List<Payment> get _visibleBills => _eligible.where((p) {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final due = DateTime(p.dueDate.year, p.dueDate.month, p.dueDate.day);
        return _billGroup == 'overdue'
            ? due.isBefore(today)
            : !due.isBefore(today);
      }).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  @override
  void initState() {
    super.initState();
    final random = Random.secure();
    final bytes = List.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 15) | 64;
    bytes[8] = (bytes[8] & 63) | 128;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    _requestId = '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
    _reference.text = 'F2F-${_requestId.toUpperCase()}';
    if (_visibleBills.isEmpty) _billGroup = 'upcoming';
  }

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    setState(() => _picking = true);
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
        throw Exception('Choose a receipt photo between 1 byte and 5 MB.');
      }
      if (mounted)
        setState(() {
          _photo = bytes;
          _filename = file.name;
          _mimeType = file.mimeType;
          _error = null;
        });
    } catch (error) {
      if (mounted) setState(() => _error = 'Could not attach photo: $error');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    if (_photo == null) {
      setState(() => _error = 'Attach a receipt photo.');
      return;
    }
    setState(() {
      _saving = true;
      _submitted = true;
      _error = null;
    });
    try {
      final payment = await const PaymentService().recordReceivedPayment(
        requestId: _requestId,
        paymentId: _bill!.id,
        amount: double.parse(_amount.text.trim()),
        method: 'f2f',
        receivedOn: _receivedOn,
        receiptBytes: _photo!,
        fileName: _filename!,
        mimeType: _mimeType,
        referenceNumber: _reference.text,
        notes: _notes.text,
      );
      if (mounted) {
        await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
                  title: const Text('Payment receipt'),
                  content: Text('Receipt ${_reference.text} saved.'),
                  actions: [
                    TextButton(
                        onPressed: () async {
                          try {
                            await const ReceiptPrintService().printPayment(
                                payment,
                                amount: double.parse(_amount.text),
                                reference: _reference.text,
                                receivedOn: _receivedOn);
                          } catch (error) {
                            if (context.mounted)
                              showAppSnackBar(
                                  context, 'Could not print receipt: $error');
                          }
                        },
                        child: const Text('Print receipt')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Done')),
                  ],
                ));
        if (mounted) Navigator.pop(this.context, true);
      }
    } catch (error) {
      if (mounted)
        setState(() => _error =
            'Could not confirm the payment: $error. Retry with the same details. '
                'If this bill changed, close and refresh Payments before starting again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editable = !_saving && !_submitted && !_picking;
    return PopScope(
      canPop: !_saving && !_picking,
      child: AlertDialog(
        title: const Text('Record payment received'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Form(
              key: _form,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Record money already received. Saving verifies the '
                    'transaction and reduces the selected bill balance.'),
                const SizedBox(height: 16),
                if (_eligible.isEmpty)
                  const Text('No eligible unpaid bills. Review pending proofs '
                      'first. Security deposits are recorded separately.'),
                DropdownButtonFormField<String>(
                  initialValue: _billGroup,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Bill group'),
                  items: const [
                    DropdownMenuItem(value: 'overdue', child: Text('Overdue')),
                    DropdownMenuItem(
                        value: 'upcoming',
                        child: Text('Upcoming / due today',
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: !editable
                      ? null
                      : (value) => setState(() {
                            _billGroup = value!;
                            _bill = null;
                            _amount.clear();
                          }),
                ),
                const SizedBox(height: 12),
                SearchableDropdownFormField<String>(
                  initialValue: _bill?.id,
                  decoration:
                      const InputDecoration(labelText: 'Tenant and bill'),
                  items: _visibleBills
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(
                                '${p.tenantName ?? p.tenantId} — ${p.label} '
                                '(₱${p.outstandingAmount.toStringAsFixed(2)} remaining)'),
                          ))
                      .toList(),
                  onChanged: !editable
                      ? null
                      : (id) => setState(() {
                            _bill =
                                _eligible.where((p) => p.id == id).firstOrNull;
                            _amount.text =
                                _bill?.outstandingAmount.toStringAsFixed(2) ??
                                    '';
                          }),
                  validator: (id) =>
                      id == null ? 'Select an unpaid bill' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  enabled: editable,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'Amount received', prefixText: '₱ '),
                  validator: (value) {
                    final amount = double.tryParse(value?.trim() ?? '');
                    if (!RegExp(r'^\d+(\.\d{1,2})?$')
                            .hasMatch(value?.trim() ?? '') ||
                        amount == null ||
                        !amount.isFinite ||
                        amount <= 0) {
                      return 'Enter a positive amount with at most two decimals';
                    }
                    if (_bill != null && amount > _bill!.outstandingAmount) {
                      return 'Amount exceeds the remaining balance';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                const Text('Payment method: Face-to-face receipt'),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Date received'),
                  subtitle:
                      Text(_receivedOn.toIso8601String().substring(0, 10)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: !editable
                      ? null
                      : () async {
                          final date = await showDatePicker(
                              context: context,
                              initialDate: _receivedOn,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now());
                          if (date != null && mounted)
                            setState(() => _receivedOn = date);
                        },
                ),
                TextFormField(
                    controller: _reference,
                    readOnly: true,
                    decoration: const InputDecoration(
                        labelText: 'Receipt / reference number (generated)')),
                const SizedBox(height: 12),
                TextFormField(
                    controller: _notes,
                    enabled: editable,
                    maxLines: 2,
                    decoration:
                        const InputDecoration(labelText: 'Notes (optional)')),
                const SizedBox(height: 12),
                const Text(
                    'Receipt photo required · JPG, PNG or WEBP · up to 5 MB'),
                Wrap(spacing: 8, children: [
                  TextButton.icon(
                      onPressed:
                          !editable ? null : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Attach photo')),
                  TextButton.icon(
                      onPressed:
                          !editable ? null : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('Take photo')),
                ]),
                if (_picking) const LinearProgressIndicator(),
                if (_photo != null)
                  Image.memory(_photo!, height: 150, fit: BoxFit.contain),
                if (_error != null)
                  Text(_error!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
              ]),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed:
                  _saving || _picking ? null : () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed:
                  _saving || _picking || _eligible.isEmpty ? null : _save,
              child: Text(_saving
                  ? 'Recording…'
                  : _submitted
                      ? 'Retry recording'
                      : 'Record payment')),
        ],
      ),
    );
  }
}
