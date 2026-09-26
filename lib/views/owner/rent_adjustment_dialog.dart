import 'package:flutter/material.dart';

import '../../controllers/owner_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';

Future<void> showRentAdjustmentDialog(
  BuildContext context,
  TenantContract contract,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _RentAdjustmentDialog(contract: contract),
  );
}

class _RentAdjustmentDialog extends StatefulWidget {
  const _RentAdjustmentDialog({required this.contract});
  final TenantContract contract;

  @override
  State<_RentAdjustmentDialog> createState() => _RentAdjustmentDialogState();
}

class _RentAdjustmentDialogState extends State<_RentAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _reason = TextEditingController();
  late DateTime _effectiveDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amount.text = widget.contract.monthlyRent.toStringAsFixed(2);
    final now = DateTime.now();
    _effectiveDate = DateTime(now.year, now.month + 1, 1);
  }

  @override
  void dispose() {
    _amount.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveDate,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: widget.contract.endsOn,
    );
    if (picked != null && mounted) setState(() => _effectiveDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final count = await OwnerController.instance.applyRentRateOverride(
        tenantId: widget.contract.tenantId,
        newMonthlyRent: double.parse(_amount.text.trim()),
        effectiveDate: _effectiveDate,
        reason: _reason.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context);
      showAppSnackBar(
        context,
        'Contract rent adjustment applied to $count future bill${count == 1 ? '' : 's'}.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      showAppSnackBar(context, 'Could not adjust future rent: $error');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Adjust future contract rent'),
        content: SizedBox(
          width: 430,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.contract.tenantName,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text(
                    'This creates an audited adjustment for unpaid future rent bills. It does not rewrite the signed contract or paid history.',
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _amount,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'New monthly rent',
                      prefixText: '₱ ',
                    ),
                    validator: (value) {
                      final amount = double.tryParse(value?.trim() ?? '');
                      if (amount == null || amount <= 0) {
                        return 'Enter a valid rent amount';
                      }
                      if (amount == widget.contract.monthlyRent) {
                        return 'Enter an amount different from the contract rent';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _saving ? null : _pickDate,
                    child: InputDecorator(
                      decoration:
                          const InputDecoration(labelText: 'Effective date'),
                      child: Text(
                        '${_effectiveDate.year}-${_effectiveDate.month.toString().padLeft(2, '0')}-${_effectiveDate.day.toString().padLeft(2, '0')}',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _reason,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Amendment or approval reason',
                    ),
                    validator: (value) => (value?.trim().length ?? 0) < 3
                        ? 'Enter a reason'
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: Text(_saving ? 'Applying…' : 'Apply adjustment'),
          ),
        ],
      );
}
