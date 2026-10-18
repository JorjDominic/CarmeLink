import '../../core/widgets/chat_workspace.dart';
import 'package:flutter/material.dart';

import '../../controllers/messaging_controller.dart';
import '../../controllers/session_controller.dart';
import '../../core/widgets/common_widgets.dart';
import '../../models/models.dart';
import '../../services/messaging_service.dart';
import '../../services/table_refresh_subscription.dart';

class StaffMessageContacts extends StatefulWidget {
  const StaffMessageContacts({super.key, this.onOpen, this.selectedKey});
  final ValueChanged<Widget>? onOpen;
  final Key? selectedKey;

  @override
  State<StaffMessageContacts> createState() => _StaffMessageContactsState();
}

class _StaffMessageContactsState extends State<StaffMessageContacts> {
  String _search = '';
  static const _service = MessagingService();
  late Future<List<Object>> _future = _load();
  late final TableRefreshSubscription _subscription;

  Future<List<Object>> _load() => Future.wait<Object>([
        _service.listStaffContacts(),
        _service.listDirectConversations(),
      ]);

  void _refresh() {
    if (mounted) setState(() => _future = _load());
  }

  @override
  void initState() {
    super.initState();
    _subscription = TableRefreshSubscription(
      'staff-message-contacts-${identityHashCode(this)}',
      ['profiles', 'conversations', 'messages'],
      _refresh,
    );
  }

  @override
  void dispose() {
    _subscription.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.onOpen != null
      ? _contacts(context, widget.onOpen, widget.selectedKey)
      : ChatWorkspace(
          contactsBuilder: (select, selectedKey) =>
              _contacts(context, select, selectedKey));

  Widget _contacts(BuildContext context, ValueChanged<Widget>? select,
          Key? selectedKey) =>
      FutureBuilder<List<Object>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Row(children: [
              const Expanded(
                  child: Text('Could not load management contacts.')),
              TextButton(onPressed: _refresh, child: const Text('Retry')),
            ]);
          }
          if (!snapshot.hasData) return const LinearProgressIndicator();
          final contacts = snapshot.data![0] as List<Map<String, dynamic>>;
          final conversations = snapshot.data![1] as List<ConversationRecord>;
          final visibleContacts = contacts
              .where((contact) => (contact['full_name'] as String)
                  .toLowerCase()
                  .contains(_search))
              .toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle('Owner & caretakers',
                  subtitle:
                      'Private conversations with individual staff accounts'),
              const SizedBox(height: 8),
              TextField(
                decoration: const InputDecoration(
                    hintText: 'Search staff contacts',
                    prefixIcon: Icon(Icons.search)),
                onChanged: (value) =>
                    setState(() => _search = value.trim().toLowerCase()),
              ),
              const SizedBox(height: 8),
              if (contacts.isEmpty)
                const Text(
                    'No other owner or caretaker accounts are available.'),
              if (contacts.isNotEmpty && visibleContacts.isEmpty)
                const Text('No matching staff contacts.'),
              for (final contact in visibleContacts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Builder(builder: (context) {
                    // Metadata comes from a participant-only RPC, never from a
                    // query that exposes another user's private profile fields.
                    final name = contact['full_name'] as String;
                    final role =
                        contact['role'] == 'owner' ? 'Owner' : 'Caretaker';
                    final record = conversations
                        .where((item) => item.directPeerId == contact['id'])
                        .firstOrNull;
                    return ConversationListCard(
                      selected: selectedKey ==
                          ValueKey('direct-' + (contact['id'] as String)),
                      name: name,
                      role: role,
                      lastMessageText: record?.lastMessagePreview ??
                          'Start a private conversation',
                      lastMessageTime: record?.lastMessageAt,
                      unreadCount: record?.unreadCount ?? 0,
                      onTap: () async {
                        if (select != null) {
                          select(DirectStaffConversationPage(
                              key: ValueKey(
                                  'direct-' + (contact['id'] as String)),
                              staffId: contact['id'] as String,
                              contactName: name,
                              embedded: true));
                          return;
                        }
                        await Navigator.of(context)
                            .push(MaterialPageRoute<void>(
                          builder: (_) => DirectStaffConversationPage(
                              staffId: contact['id'] as String,
                              contactName: name),
                        ));
                        _refresh();
                      },
                    );
                  }),
                ),
            ],
          );
        },
      );
}

class DirectStaffConversationPage extends StatefulWidget {
  const DirectStaffConversationPage(
      {super.key,
      this.staffId,
      this.conversationId,
      this.contactName,
      this.embedded = false})
      : assert(staffId != null || conversationId != null);
  final String? staffId, conversationId, contactName;
  final bool embedded;

  @override
  State<DirectStaffConversationPage> createState() =>
      _DirectStaffConversationPageState();
}

class _DirectStaffConversationPageState
    extends State<DirectStaffConversationPage> {
  final _composer = TextEditingController();
  ConversationRecord? _record;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      const service = MessagingService();
      final record = widget.staffId != null
          ? await service.getOrCreateDirectConversation(widget.staffId!)
          : await service.fetchConversationById(widget.conversationId!);
      if (!mounted) return;
      if (record == null || !record.isDirectStaff)
        throw Exception('Private conversation unavailable');
      await MessagingController.instance.openConversation(record);
      if (!mounted) return;
      setState(() {
        _record = record;
        _loading = false;
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _error = 'Could not open this private conversation.';
          _loading = false;
        });
    }
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty) return;
    final sent = await MessagingController.instance.sendMessage(text);
    if (!mounted) return;
    if (sent && _composer.text.trim() == text) _composer.clear();
    if (!sent)
      showAppSnackBar(context, 'Message could not be sent. Please try again.');
  }

  @override
  void dispose() {
    _composer.dispose();
    if (widget.embedded) {
      final id = _record?.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (id != null &&
            MessagingController.instance.activeConversation?.id == id) {
          MessagingController.instance.closeActiveConversation();
          MessagingController.instance.startForCurrentRole();
        }
      });
    } else {
      MessagingController.instance.closeActiveConversation();
      MessagingController.instance.startForCurrentRole();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final content = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
            ? Column(children: [
                Text(_error!),
                TextButton(onPressed: _open, child: const Text('Retry'))
              ])
            : AnimatedBuilder(
                animation: MessagingController.instance,
                builder: (context, _) => ConversationThreadPanel(
                  participantName: _record?.title ??
                      widget.contactName ??
                      'Private conversation',
                  participantRole: _record?.subtitle ?? '',
                  messages: MessagingController.instance.activeMessages,
                  composerController: _composer,
                  sending: MessagingController.instance.sendingMessage,
                  emptyMessage:
                      'No messages yet. Start a private conversation.',
                  hintText: 'Write a message...',
                  onSend: _send,
                  isMine: (message) => message
                      .isMine(SessionController.instance.currentUser?.id),
                ),
              );
    if (widget.embedded) return content;
    return PageFrame(
      maxWidth: 1280,
      title: 'Chat',
      subtitle: _record?.title ?? widget.contactName ?? 'Private conversation',
      child: content,
    );
  }
}
