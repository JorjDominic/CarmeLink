import 'package:flutter/material.dart';

import '../../services/conduct_case_service.dart';
import '../../services/report_administration_service.dart';

/// One administrative submission with an explicit preview and a stable retry key.
Future<bool> showAdministrativeEntryDialog(
  BuildContext context, {
  required String title,
  required Future<void> Function(
          String body, String visibility, String requestId)
      onSave,
  bool allowTenantVisibility = false,
}) async {
  final controller = TextEditingController();
  final requestId = const ConductCaseService().createResponseRequestId();
  var visibility = 'internal';
  var reviewing = false;
  var saving = false;
  var attempted = false;
  String? error;
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => PopScope(
              canPop: !saving,
              child: AlertDialog(
                scrollable: true,
                title: Text(reviewing ? 'Confirm administrative entry' : title),
                content: SizedBox(
                    width: 480,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(visibility == 'tenant'
                            ? 'Visible to the affected tenant. The tenant will be notified.'
                            : 'Internal administrative note. Only authorized staff can read it.'),
                        const SizedBox(height: 12),
                        if (reviewing) ...[
                          const Text(
                              'Review the complete entry before saving.'),
                          const SizedBox(height: 12),
                          SelectableText(controller.text.trim()),
                          const SizedBox(height: 12),
                          Text(allowTenantVisibility
                              ? 'This response leaves the case status unchanged. Warnings and decisions use separate actions.'
                              : 'This note leaves the report status unchanged.'),
                        ] else ...[
                          if (allowTenantVisibility) ...[
                            DropdownButtonFormField<String>(
                                initialValue: visibility,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    labelText: 'Response visibility'),
                                items: const [
                                  DropdownMenuItem(
                                      value: 'internal',
                                      child:
                                          Text('Internal administrative note')),
                                  DropdownMenuItem(
                                      value: 'tenant',
                                      child: Text(
                                          'Tenant-visible official response')),
                                ],
                                onChanged: (value) =>
                                    update(() => visibility = value!)),
                            const SizedBox(height: 12),
                          ],
                          TextField(
                              controller: controller,
                              minLines: 3,
                              maxLines: 7,
                              maxLength: allowTenantVisibility ? 4000 : 2000,
                              decoration: const InputDecoration(
                                  labelText: 'Response or instructions')),
                        ],
                        if (error != null) ...[
                          const SizedBox(height: 12),
                          Text(error!,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error))
                        ],
                      ],
                    )),
                actions: [
                  TextButton(
                      onPressed: saving
                          ? null
                          : () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel')),
                  if (reviewing && !attempted)
                    TextButton(
                        onPressed: saving
                            ? null
                            : () => update(() => reviewing = false),
                        child: const Text('Edit')),
                  FilledButton(
                      onPressed: saving
                          ? null
                          : () async {
                              if (saving) return;
                              if (!reviewing) {
                                if (controller.text.trim().length < 5) {
                                  update(() =>
                                      error = 'Enter at least 5 characters.');
                                  return;
                                }
                                update(() {
                                  reviewing = true;
                                  error = null;
                                });
                                return;
                              }
                              update(() {
                                saving = true;
                                attempted = true;
                                error = null;
                              });
                              try {
                                await onSave(controller.text.trim(), visibility,
                                    requestId);
                                if (dialogContext.mounted)
                                  Navigator.pop(dialogContext, true);
                              } catch (exception) {
                                if (dialogContext.mounted)
                                  update(() {
                                    saving = false;
                                    error =
                                        'Entry was not confirmed saved. ${reportAdministrationError(exception)}';
                                  });
                              }
                            },
                      child: Text(saving
                          ? 'Saving…'
                          : reviewing
                              ? 'Confirm and save'
                              : 'Review entry')),
                ],
              ),
            )),
  );
  // Dialog exit transitions may still reference the controller.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  controller.dispose();
  return result == true;
}
