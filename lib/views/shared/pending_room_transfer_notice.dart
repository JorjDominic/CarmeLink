import 'package:flutter/material.dart';
import '../../controllers/session_controller.dart';
import '../../core/config/supabase_config.dart';
import '../../services/room_transfer_service.dart';
import '../../services/table_refresh_subscription.dart';
import 'room_transfer_page.dart';

class PendingRoomTransferNotice extends StatefulWidget {
  const PendingRoomTransferNotice(
      {super.key, this.service = const RoomTransferService(), this.tenantId});
  final RoomTransferService service;
  final String? tenantId;
  @override
  State<PendingRoomTransferNotice> createState() =>
      _PendingRoomTransferNoticeState();
}

class _PendingRoomTransferNoticeState extends State<PendingRoomTransferNotice> {
  List<RoomTransfer> transfers = [];
  String? error;
  bool loading = true;
  int generation = 0;
  TableRefreshSubscription? subscription;
  @override
  void initState() {
    super.initState();
    if (widget.tenantId != null || SupabaseConfig.isInitialized) {
      load();
      subscription = TableRefreshSubscription(
          'pending-room-transfer-${widget.tenantId ?? 'self'}-${identityHashCode(this)}',
          [
            'room_transfers',
            'room_transfer_signers',
            'room_transfer_notice_acknowledgments'
          ],
          load);
    } else {
      loading = false;
    }
  }

  @override
  void dispose() {
    subscription?.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final request = ++generation;
    final tenant =
        widget.tenantId ?? SessionController.instance.currentUser?.id;
    if (tenant == null) {
      if (mounted)
        setState(() {
          transfers = [];
          loading = false;
        });
      return;
    }
    try {
      final rows = await widget.service.list(tenantId: tenant);
      if (!mounted || request != generation) return;
      setState(() {
        transfers = rows
            .where((t) =>
                t.tenantId == tenant && t.status == 'awaiting_signatures')
            .toList();
        error = null;
        loading = false;
      });
    } catch (_) {
      if (mounted && request == generation)
        setState(() {
          transfers = [];
          loading = false;
          error = 'Could not check room transfer notices.';
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const LinearProgressIndicator();
    if (error != null)
      return Card(
          child: ListTile(
              title: Text(error!),
              trailing:
                  TextButton(onPressed: load, child: const Text('Retry'))));
    return Column(children: [
      for (final t in transfers)
        Card(
            child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          t.noticeAcknowledged
                              ? 'Room transfer awaiting signatures'
                              : 'Room transfer awaiting your review',
                          style: Theme.of(context).textTheme.titleMedium),
                      Text('${t.source} → ${t.destination}'),
                      Text(
                          'Effective ${t.effectiveOn.toIso8601String().substring(0, 10)}'),
                      Text('Reason: ${t.reason}'),
                      const Text(
                          'Your current room stays active until the transfer is completed. Review the notice and amendment, acknowledge it, then sign. Contact the owner if you have concerns.'),
                      FilledButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                    builder: (_) => RoomTransferPage(
                                        tenantId: t.tenantId,
                                        service: widget.service)));
                            if (mounted) await load();
                          },
                          icon: const Icon(Icons.assignment_outlined),
                          label: const Text('Review room transfer')),
                    ])))
    ]);
  }
}
