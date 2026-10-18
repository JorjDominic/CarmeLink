import 'package:flutter/material.dart';

import '../../controllers/messaging_controller.dart';
import 'common_widgets.dart';

/// Desktop selection is local UI state. Existing conversation widgets retain
/// responsibility for opening, sending, subscriptions and disposal.
class ChatWorkspace extends StatefulWidget {
  const ChatWorkspace(
      {required this.contactsBuilder, this.initialThread, super.key});
  final Widget? initialThread;
  final Widget Function(ValueChanged<Widget>? select, Key? selectedKey)
      contactsBuilder;

  @override
  State<ChatWorkspace> createState() => _ChatWorkspaceState();
}

class _ChatWorkspaceState extends State<ChatWorkspace> {
  Widget? _thread;
  Key? _selectedKey;
  bool _switching = false;

  @override
  void initState() {
    super.initState();
    _thread = widget.initialThread;
    _selectedKey = _thread?.key;
  }

  Future<void> _select(Widget thread) async {
    final messaging = MessagingController.instance;
    if (_switching ||
        messaging.loadingMessages ||
        messaging.sendingMessage ||
        _selectedKey == thread.key) return;
    setState(() {
      _switching = true;
      _thread = null;
      _selectedKey = thread.key;
    });
    // Dispose the previous embedded page before the next page opens its
    // conversation. Its existing cleanup must not close the newly opened one.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() {
      _thread = thread;
      _switching = false;
    });
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, bounds) {
        if (bounds.maxWidth < 900 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.3) {
          return widget.contactsBuilder(null, null);
        }
        final height =
            (MediaQuery.sizeOf(context).height - 220).clamp(340.0, 760.0);
        return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
              child: _thread ??
                  SizedBox(
                    height: height,
                    child: CarmelitaCard(
                        child: Center(
                            child: _switching
                                ? const CircularProgressIndicator()
                                : const EmptyState(
                                    icon: Icons.forum_outlined,
                                    title: 'Select a conversation',
                                    message:
                                        'Choose a contact on the right to open your chat here.'))),
                  )),
          const SizedBox(width: 20),
          SizedBox(
              width: 320,
              height: height,
              child: CarmelitaCard(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                    child: widget.contactsBuilder(_select, _selectedKey)),
              )),
        ]);
      });
}
