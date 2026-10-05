import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../controllers/session_controller.dart';
import '../../models/models.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';
import '../responsive/breakpoints.dart';
import '../runtime/app_surface.dart';
import '../theme/app_theme.dart';
import '../../services/geofence_service.dart';
import 'adaptive_shell.dart';

Color mutedAccentForIcon(BuildContext context, IconData icon) {
  if (icon == Icons.payments_outlined ||
      icon == Icons.receipt_long_outlined ||
      icon == Icons.account_balance_wallet_outlined) {
    return const Color(0xFFAA8A45);
  }
  if (icon == Icons.warning_amber_outlined ||
      icon == Icons.priority_high_rounded ||
      icon == Icons.emergency_outlined) {
    return const Color(0xFFAA6870);
  }
  if (icon == Icons.build_outlined ||
      icon == Icons.handyman_outlined ||
      icon == Icons.tune_outlined) {
    return const Color(0xFFB47A52);
  }
  if (icon == Icons.shield_outlined ||
      icon == Icons.schedule_outlined ||
      icon == Icons.gavel_outlined) {
    return const Color(0xFF7D70A0);
  }
  if (icon == Icons.person_outline ||
      icon == Icons.groups_outlined ||
      icon == Icons.bed_outlined ||
      icon == Icons.home_outlined) {
    return const Color(0xFF56886B);
  }
  if (icon == Icons.sensor_door_outlined ||
      icon == Icons.videocam_outlined ||
      icon == Icons.memory_outlined ||
      icon == Icons.timeline_outlined) {
    return const Color(0xFF568F8E);
  }
  return const Color(0xFF627FA8);
}

enum RecordListScope { active, history }

enum RecordListSort { newest, oldest, status, title }

/// Shared progressive-disclosure controls for operational record lists.
class RecordListToolbar extends StatelessWidget {
  const RecordListToolbar({
    required this.scope,
    required this.sort,
    required this.onScopeChanged,
    required this.onSortChanged,
    this.activeCount,
    this.historyCount,
    this.extra,
    super.key,
  });

  final RecordListScope scope;
  final RecordListSort sort;
  final ValueChanged<RecordListScope> onScopeChanged;
  final ValueChanged<RecordListSort> onSortChanged;
  final int? activeCount;
  final int? historyCount;
  final Widget? extra;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final useCompactScope = constraints.maxWidth < 720 ||
              MediaQuery.textScalerOf(context).scale(1) > 1.15;
          final scopeControl = SegmentedButton<RecordListScope>(
            segments: [
              ButtonSegment(
                value: RecordListScope.active,
                icon: const Icon(Icons.bolt_outlined),
                label: Text(
                  activeCount == null ? 'Active' : 'Active ($activeCount)',
                ),
              ),
              ButtonSegment(
                value: RecordListScope.history,
                icon: const Icon(Icons.history_outlined),
                label: Text(
                  historyCount == null ? 'History' : 'History ($historyCount)',
                ),
              ),
            ],
            selected: {scope},
            onSelectionChanged: (values) => onScopeChanged(values.first),
          );
          final sortControl = DropdownButton<RecordListSort>(
            value: sort,
            underline: const SizedBox.shrink(),
            borderRadius: BorderRadius.circular(14),
            items: const [
              DropdownMenuItem(
                value: RecordListSort.newest,
                child: Text('Newest first'),
              ),
              DropdownMenuItem(
                value: RecordListSort.oldest,
                child: Text('Oldest first'),
              ),
              DropdownMenuItem(
                value: RecordListSort.status,
                child: Text('By status'),
              ),
              DropdownMenuItem(
                value: RecordListSort.title,
                child: Text('A-Z'),
              ),
            ],
            onChanged: (value) {
              if (value != null) onSortChanged(value);
            },
          );
          final sortBox = Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).dividerColor),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.sort_rounded, size: 18),
                const SizedBox(width: 6),
                sortControl,
              ],
            ),
          );
          final children = [scopeControl, if (extra != null) extra!, sortBox];
          if (useCompactScope) {
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Row(
                children: [
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    selected: scope == RecordListScope.active,
                    label: Text(activeCount == null
                        ? 'Active'
                        : 'Active ($activeCount)'),
                    onSelected: (_) => onScopeChanged(RecordListScope.active),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    selected: scope == RecordListScope.history,
                    label: Text(historyCount == null
                        ? 'History'
                        : 'History ($historyCount)'),
                    onSelected: (_) => onScopeChanged(RecordListScope.history),
                  ),
                  if (extra != null) ...[
                    const SizedBox(width: 8),
                    extra!,
                  ],
                  const SizedBox(width: 8),
                  PopupMenuButton<RecordListSort>(
                    tooltip: 'Sort records',
                    initialValue: sort,
                    onSelected: onSortChanged,
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                          value: RecordListSort.newest,
                          child: Text('Newest first')),
                      PopupMenuItem(
                          value: RecordListSort.oldest,
                          child: Text('Oldest first')),
                      PopupMenuItem(
                          value: RecordListSort.status,
                          child: Text('By status')),
                      PopupMenuItem(
                          value: RecordListSort.title, child: Text('A-Z')),
                    ],
                    child: Chip(
                      visualDensity: VisualDensity.compact,
                      avatar: const Icon(Icons.sort_rounded, size: 17),
                      label: Text(switch (sort) {
                        RecordListSort.oldest => 'Oldest',
                        RecordListSort.status => 'Status',
                        RecordListSort.title => 'A-Z',
                        _ => 'Newest',
                      }),
                    ),
                  ),
                ],
              ),
            );
          }
          return constraints.maxWidth < 600
              ? Wrap(spacing: 10, runSpacing: 10, children: children)
              : Row(children: [
                  scopeControl,
                  const Spacer(),
                  if (extra != null) ...[extra!, const SizedBox(width: 10)],
                  sortBox,
                ]);
        },
      );
}

/// Shared hierarchy for tenant reporting workflows: purpose, audience, and action.
class ReportWorkflowIntroCard extends StatelessWidget {
  const ReportWorkflowIntroCard({
    required this.title,
    required this.purpose,
    required this.audience,
    required this.icon,
    this.action,
    super.key,
  });

  final String title;
  final String purpose;
  final String audience;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) => CarmelitaCard(
        emphasis: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: .10),
              foregroundColor: Theme.of(context).colorScheme.primary,
              child: Icon(icon, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(purpose),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.visibility_outlined, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          audience,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  if (action != null) ...[
                    const SizedBox(height: 10),
                    action!,
                  ],
                ],
              ),
            ),
          ],
        ),
      );
}

/// Keeps explanatory text available without letting it dominate repeat visits.
class CollapsibleInfoCard extends StatelessWidget {
  const CollapsibleInfoCard({
    required this.title,
    required this.body,
    this.icon = Icons.info_outline_rounded,
    this.initiallyExpanded = false,
    super.key,
  });

  final String title;
  final String body;
  final IconData icon;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) => CarmelitaCard(
        padding: EdgeInsets.zero,
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          leading: Icon(icon),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [SizedBox(width: double.infinity, child: Text(body))],
        ),
      );
}

/// Renders a bounded first page and progressively reveals older records.
class PagedRecordList extends StatefulWidget {
  const PagedRecordList({
    required this.children,
    this.pageSize = 6,
    this.loadMoreLabel = 'Show more',
    this.showVisibleCount = false,
    this.showEndState = false,
    this.endLabel = 'End of records',
    super.key,
  });

  final List<Widget> children;
  final int pageSize;
  final String loadMoreLabel;
  final bool showVisibleCount;
  final bool showEndState;
  final String endLabel;

  @override
  State<PagedRecordList> createState() => _PagedRecordListState();
}

class _PagedRecordListState extends State<PagedRecordList> {
  late int visibleCount = widget.pageSize;

  @override
  void didUpdateWidget(covariant PagedRecordList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.children.length != widget.children.length) {
      visibleCount = widget.pageSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = visibleCount.clamp(0, widget.children.length);
    final hasMore = count < widget.children.length;
    final total = widget.children.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ...widget.children.take(count),
        if (widget.showVisibleCount && total > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Showing $count of $total records',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (hasMore || count > widget.pageSize)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                if (hasMore)
                  OutlinedButton.icon(
                    onPressed: () => setState(() => visibleCount =
                        (visibleCount + widget.pageSize)
                            .clamp(0, widget.children.length)),
                    icon: const Icon(Icons.expand_more),
                    label: Text(
                      '${widget.loadMoreLabel} (${total - count} remaining)',
                    ),
                  ),
                if (count > widget.pageSize)
                  TextButton.icon(
                    onPressed: () =>
                        setState(() => visibleCount = widget.pageSize),
                    icon: const Icon(Icons.expand_less),
                    label: const Text('Show fewer'),
                  ),
              ],
            ),
          ),
        if (widget.showEndState && !hasMore && total > widget.pageSize)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.endLabel,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class MessageDeliveryMeta extends StatelessWidget {
  const MessageDeliveryMeta({
    required this.message,
    required this.isMine,
    super.key,
  });

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall;
    if (!isMine) return Text(timeText(message.sentAt), style: style);
    final read = message.isRead && message.readAt != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('${timeText(message.sentAt)} • ', style: style),
        Icon(
          read ? Icons.done_all_rounded : Icons.done_rounded,
          size: 14,
          color: read ? Theme.of(context).colorScheme.primary : style?.color,
        ),
        const SizedBox(width: 3),
        Text(read ? 'Read' : 'Sent', style: style),
      ],
    );
  }
}

class ConversationThreadPanel extends StatefulWidget {
  const ConversationThreadPanel({
    required this.messages,
    required this.composerController,
    required this.isMine,
    required this.onSend,
    this.sending = false,
    this.emptyMessage = 'No messages yet.',
    this.hintText = 'Write a message...',
    super.key,
  });

  final List<ChatMessage> messages;
  final TextEditingController composerController;
  final bool Function(ChatMessage message) isMine;
  final Future<void> Function() onSend;
  final bool sending;
  final String emptyMessage;
  final String hintText;

  @override
  State<ConversationThreadPanel> createState() =>
      _ConversationThreadPanelState();
}

class _ConversationThreadPanelState extends State<ConversationThreadPanel> {
  final ScrollController _scrollController = ScrollController();
  bool _showNewMessages = false;
  int _previousMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _previousMessageCount = widget.messages.length;
    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToLatest());
  }

  @override
  void didUpdateWidget(covariant ConversationThreadPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.messages.length == _previousMessageCount) return;
    final wasNearBottom = _isNearBottom();
    final grew = widget.messages.length > _previousMessageCount;
    _previousMessageCount = widget.messages.length;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !grew) return;
      if (wasNearBottom) {
        _scrollToLatest();
      } else if (!_showNewMessages) {
        setState(() => _showNewMessages = true);
      }
    });
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    return (_scrollController.position.maxScrollExtent -
            _scrollController.position.pixels) <=
        96;
  }

  void _handleScroll() {
    if (_showNewMessages && _isNearBottom() && mounted) {
      setState(() => _showNewMessages = false);
    }
  }

  void _jumpToLatest() {
    if (!_scrollController.hasClients) return;
    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  void _scrollToLatest() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
    if (_showNewMessages && mounted) {
      setState(() => _showNewMessages = false);
    }
  }

  Future<void> _send() async {
    if (widget.sending || widget.composerController.text.trim().isEmpty) return;
    await widget.onSend();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToLatest());
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final desktop = media.size.width >= 900;
    final keyboardInset = media.viewInsets.bottom;
    final availableHeight =
        media.size.height - keyboardInset - (desktop ? 220.0 : 176.0);
    final panelHeight = availableHeight
        .clamp(
          desktop ? 430.0 : 340.0,
          desktop ? 680.0 : 620.0,
        )
        .toDouble();

    return SizedBox(
      key: const Key('conversation-thread-panel'),
      height: panelHeight,
      child: CarmelitaCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  if (widget.messages.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          widget.emptyMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      key: const Key('conversation-message-scroll'),
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: widget.messages.length,
                      itemBuilder: (context, index) {
                        final item = widget.messages[index];
                        final mine = widget.isMine(item);
                        return Align(
                          alignment: mine
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 560),
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              color: mine
                                  ? const Color(0xFF627FA8)
                                      .withValues(alpha: .10)
                                  : Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest
                                      .withValues(alpha: .55),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(15),
                                topRight: const Radius.circular(15),
                                bottomLeft: Radius.circular(mine ? 15 : 4),
                                bottomRight: Radius.circular(mine ? 4 : 15),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: mine
                                  ? CrossAxisAlignment.end
                                  : CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.senderName,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.body,
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 3),
                                MessageDeliveryMeta(
                                  message: item,
                                  isMine: mine,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  if (_showNewMessages)
                    Positioned(
                      right: 14,
                      bottom: 12,
                      child: FilledButton.tonalIcon(
                        key: const Key('conversation-new-messages-button'),
                        onPressed: _scrollToLatest,
                        icon:
                            const Icon(Icons.arrow_downward_rounded, size: 17),
                        label: const Text('New messages'),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                child: TextField(
                  key: const Key('conversation-composer'),
                  controller: widget.composerController,
                  enabled: !widget.sending,
                  minLines: 1,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    prefixIcon: const Icon(Icons.chat_bubble_outline_rounded),
                    suffixIcon: widget.sending
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            tooltip: 'Send message',
                            onPressed: _send,
                            icon: const Icon(Icons.send_outlined),
                          ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CarmelitaLogo extends StatelessWidget {
  const CarmelitaLogo({
    this.height = 56,
    super.key,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: Colors.white),
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(13),
            child: Image.asset(
              AppAssets.logo,
              height: height,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

class MutedDashboardItem {
  const MutedDashboardItem(
      {required this.label,
      required this.value,
      required this.detail,
      required this.icon,
      required this.color,
      this.onTap});
  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
}

class MutedDashboardGrid extends StatelessWidget {
  const MutedDashboardGrid(
      {required this.items,
      this.compact = false,
      this.denseFourColumn = false,
      this.prominentCompactText = false,
      super.key});
  final List<MutedDashboardItem> items;
  final bool compact;
  final bool denseFourColumn;
  final bool prominentCompactText;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final scaledText = textScale > 1.15;
        final compactTriple = compact &&
            items.length == 3 &&
            constraints.maxWidth >= 285 &&
            !scaledText;
        final columns = denseFourColumn
            ? constraints.maxWidth < 400
                ? items.length.clamp(1, 2)
                : items.length.clamp(1, 4)
            : compactTriple
                ? 3
                : constraints.maxWidth < 600
                    ? (constraints.maxWidth < 320 ? 1 : 2)
                    : items.length.clamp(2, 4);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            mainAxisExtent: compact
                ? (prominentCompactText ? 99 : 100) +
                    ((textScale - 1).clamp(0, 1) * 72)
                : null,
            childAspectRatio: compact
                ? (scaledText ? 1.05 : 1.25)
                : denseFourColumn && constraints.maxWidth < 500
                    ? (scaledText ? .54 : .65)
                    : constraints.maxWidth < 500
                        ? (scaledText ? .86 : 1.05)
                        : (scaledText ? .96 : 1.15),
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: EdgeInsets.all(
                  prominentCompactText
                      ? 6
                      : (compactTriple ? 6 : (compact ? 7 : 10)),
                ),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: .035),
                  border: Border.all(color: item.color.withValues(alpha: .10)),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          padding: EdgeInsets.all(
                              compactTriple ? 3 : (compact ? 4 : 7)),
                          decoration: BoxDecoration(
                              color: item.color.withValues(alpha: .09),
                              borderRadius: BorderRadius.circular(9)),
                          child: Icon(item.icon,
                              color: item.color,
                              size: prominentCompactText
                                  ? 18
                                  : (compactTriple
                                      ? 15
                                      : (compact ? 17 : 19)))),
                      const Spacer(),
                      Text(item.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: item.color,
                                  fontWeight: FontWeight.w900,
                                  fontSize: prominentCompactText
                                      ? 20
                                      : compactTriple
                                          ? 17
                                          : (compact ? 19 : 17))),
                      const SizedBox(height: 2),
                      Text(item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                  fontSize: prominentCompactText
                                      ? 12
                                      : (compactTriple
                                          ? 10
                                          : (compact ? 12 : 10)),
                                  fontWeight: FontWeight.w800)),
                      Text(item.detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontSize: prominentCompactText
                                      ? 10.5
                                      : compactTriple
                                          ? 8.5
                                          : (compact ? 11 : 9))),
                    ]),
              ),
            );
          },
        );
      });
}

class MutedActionItem {
  const MutedActionItem(
      {required this.label,
      required this.detail,
      required this.icon,
      required this.color,
      required this.onTap});
  final String label;
  final String detail;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class MutedActionGrid extends StatelessWidget {
  const MutedActionGrid({required this.items, super.key});
  final List<MutedActionItem> items;

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) {
        final scaledText = MediaQuery.textScalerOf(context).scale(1) > 1.15;
        final columns = constraints.maxWidth >= 900 ? 3 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: constraints.maxWidth < 520
                  ? (scaledText ? 1.8 : 2.15)
                  : (scaledText ? 2.35 : 2.8)),
          itemBuilder: (context, index) {
            final item = items[index];
            return CarmelitaCard(
              onTap: item.onTap,
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: item.color.withValues(alpha: .075),
                        borderRadius: BorderRadius.circular(11)),
                    child: Icon(item.icon, color: item.color, size: 21)),
                const SizedBox(width: 9),
                Expanded(
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(item.detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 10)),
                    ])),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: Theme.of(context).colorScheme.outline),
              ]),
            );
          },
        );
      });
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.heroTitle,
    this.useScriptTitle = true,
    this.onRefresh,
    this.onBack,
    this.maxWidth,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? heroTitle;
  final bool useScriptTitle;
  final Widget child;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Future<void> Function()? onRefresh;
  final VoidCallback? onBack;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final navScope = CarmelitaNavScope.maybeOf(context);
    final webPortal = CarmeLinkSurfaceScope.isWebPortal(context);
    final showMobileMenu = !webPortal && navScope != null;
    final canPop = Navigator.of(context).canPop();
    final extraBottom = navScope == null ? 24.0 : (webPortal ? 32.0 : 132.0);
    final currentRole = SessionController.instance.currentUser?.role;
    final isStaff =
        currentRole == UserRole.owner || currentRole == UserRole.caretaker;
    final ownerOperationalPage = isStaff && title != 'Dashboard';
    final compactHeader = MediaQuery.sizeOf(context).width < 500;
    final canShowNotifications = !webPortal &&
        SessionController.instance.currentUser != null &&
        title.toLowerCase() != 'notifications';
    final canShowMessages = !webPortal &&
        (navScope != null ||
            (isStaff && AdaptiveRoleShell.activeMessagePage != null)) &&
        title.toLowerCase() != 'messages';
    final ownerSection = isStaff &&
        title != 'Dashboard' &&
        title != 'Operations' &&
        title != 'Profile' &&
        title != 'Notifications';
    final basePageChild = ownerSection
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                currentRole == UserRole.owner ? 'OWNER' : 'CARETAKER',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      letterSpacing: 1.25,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 10),
              if (subtitle != null) ...[
                Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 14),
              ],
              child,
            ],
          )
        : child;
    final pageChild = compactHeader && subtitle != null && !ownerSection
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              basePageChild,
            ],
          )
        : basePageChild;

    void openNotifications() => AdaptiveRoleShell.openNotifications(context);

    void openMessages() {
      if (navScope?.openMessages != null) {
        navScope!.openMessages!.call();
      } else {
        AdaptiveRoleShell.openActiveMessages(context);
      }
    }

    Widget countedHeaderButton({
      required String tooltip,
      required IconData icon,
      required int count,
      required VoidCallback onPressed,
    }) {
      final label = count > 99 ? '99+' : '$count';
      return Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            tooltip: tooltip,
            onPressed: onPressed,
            icon: Icon(icon),
          ),
          if (count > 0)
            Positioned(
              right: 1,
              top: 1,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onError,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    final messageButton = countedHeaderButton(
      tooltip: 'Messages',
      icon: Icons.chat_bubble_outline,
      count: navScope?.unreadMessageCount ?? 0,
      onPressed: openMessages,
    );

    final notificationButton = countedHeaderButton(
      tooltip: 'Notifications',
      icon: Icons.notifications_outlined,
      count: navScope?.unreadNotificationCount ?? 0,
      onPressed: openNotifications,
    );

    Widget? resolvedFloatingActionButton = floatingActionButton;
    if (resolvedFloatingActionButton != null &&
        navScope != null &&
        !webPortal) {
      resolvedFloatingActionButton = Padding(
        padding: const EdgeInsets.only(bottom: 82),
        child: resolvedFloatingActionButton,
      );
    }

    return _PageEntrance(
      enabled: !canPop,
      child: Scaffold(
        extendBody: navScope != null && !webPortal,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor ??
              Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          toolbarHeight: compactHeader ? 58 : (isStaff ? 64 : 72),
          automaticallyImplyLeading: false,
          leadingWidth: showMobileMenu || onBack != null || canPop
              ? (isStaff ? 60 : 68)
              : 0,
          leading: showMobileMenu
              ? Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: IconButton(
                    key: const Key('mobile-hamburger-menu'),
                    tooltip: 'Open navigation',
                    onPressed: navScope.openMenu,
                    icon: const Icon(Icons.menu_rounded),
                  ),
                )
              : (onBack != null || canPop)
                  ? Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: IconButton(
                        tooltip: 'Back',
                        onPressed: () {
                          if (onBack != null) {
                            onBack!();
                          } else {
                            Navigator.of(context).maybePop();
                          }
                        },
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                        ),
                      ),
                    )
                  : null,
          titleSpacing: 4,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  heroTitle ?? title,
                  maxLines: 1,
                  softWrap: false,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontFamily: useScriptTitle ? 'GreatVibes' : null,
                        fontSize: compactHeader
                            ? (useScriptTitle ? 25 : 20)
                            : (useScriptTitle ? 30 : null),
                        fontWeight:
                            useScriptTitle ? FontWeight.w600 : FontWeight.w700,
                      ),
                ),
              ),
              if (subtitle != null && !ownerOperationalPage && !compactHeader)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
          actions: [
            ...?actions,
            if (canShowMessages) messageButton,
            if (canShowNotifications) notificationButton,
            SizedBox(width: compactHeader ? 2 : 10),
          ],
        ),
        floatingActionButton: resolvedFloatingActionButton,
        body: SafeArea(
          top: false,
          child: onRefresh != null
              ? RefreshIndicator(
                  onRefresh: onRefresh!,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    child: ResponsiveContent(
                      maxWidth:
                          maxWidth ?? (webPortal ? double.infinity : null),
                      padding: EdgeInsets.fromLTRB(
                        AppBreakpoints.horizontalPadding(context),
                        6,
                        AppBreakpoints.horizontalPadding(context),
                        extraBottom,
                      ),
                      child: RepaintBoundary(child: pageChild),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: ResponsiveContent(
                    maxWidth: maxWidth ?? (webPortal ? double.infinity : null),
                    padding: EdgeInsets.fromLTRB(
                      AppBreakpoints.horizontalPadding(context),
                      6,
                      AppBreakpoints.horizontalPadding(context),
                      extraBottom,
                    ),
                    child: RepaintBoundary(child: pageChild),
                  ),
                ),
        ),
      ),
    );
  }
}

class _PageEntrance extends StatefulWidget {
  const _PageEntrance({required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  State<_PageEntrance> createState() => _PageEntranceState();
}

class _PageEntranceState extends State<_PageEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> opacity;
  late final Animation<Offset> position;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    final curve = CurvedAnimation(
      parent: controller,
      curve: Curves.easeOutCubic,
    );
    opacity = CurvedAnimation(
      parent: controller,
      curve: const Interval(0, .72, curve: Curves.easeOut),
    );
    position = Tween<Offset>(
      begin: const Offset(0, .055),
      end: Offset.zero,
    ).animate(curve);
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return FadeTransition(
      opacity: opacity,
      child: SlideTransition(
        position: position,
        child: widget.child,
      ),
    );
  }
}

class CarmelitaCard extends StatelessWidget {
  const CarmelitaCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.emphasis = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<CarmelitaThemeExtension>();
    final scheme = Theme.of(context).colorScheme;
    final role = SessionController.instance.currentUser?.role;
    final isStaff = role == UserRole.owner || role == UserRole.caretaker;
    final usesDefaultPadding = padding == const EdgeInsets.all(16);
    final resolvedPadding =
        isStaff && usesDefaultPadding ? const EdgeInsets.all(12) : padding;
    final radius = isStaff ? 16.0 : 20.0;

    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      padding: resolvedPadding,
      decoration: BoxDecoration(
        color:
            emphasis ? scheme.primary.withValues(alpha: .075) : scheme.surface,
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        border: Border.all(
          color: emphasis
              ? scheme.primary.withValues(alpha: .22)
              : ext?.border ?? Theme.of(context).dividerColor,
        ),
        boxShadow: Theme.of(context).brightness == Brightness.light
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .032),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.all(Radius.circular(radius)),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class ElegantHeader extends StatelessWidget {
  const ElegantHeader({
    required this.eyebrow,
    required this.title,
    this.subtitle,
    this.trailing,
    this.useScriptTitle = true,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final bool useScriptTitle;

  Widget _copy(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 350 ? 29.0 : 34.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: 1.3,
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                fontFamily: useScriptTitle ? 'GreatVibes' : null,
                fontSize: useScriptTitle ? titleSize + 10 : titleSize,
                fontWeight: useScriptTitle ? FontWeight.w600 : FontWeight.w700,
                height: useScriptTitle ? 1.15 : null,
                letterSpacing: useScriptTitle ? 0 : null,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (trailing == null) {
      return _copy(context);
    }

    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420 || textScale > 1.3) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: trailing!,
              ),
              const SizedBox(height: 12),
              _copy(context),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _copy(context)),
            const SizedBox(width: 12),
            Flexible(
              flex: 0,
              child: trailing!,
            ),
          ],
        );
      },
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(
    this.title, {
    this.trailing,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final stack = MediaQuery.sizeOf(context).width < 370 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.3;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );

    if (trailing == null) return copy;
    if (stack) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          copy,
          const SizedBox(height: 6),
          trailing!,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: copy),
        trailing!,
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill(
    this.text, {
    this.icon,
    super.key,
  });

  final String text;
  final IconData? icon;

  Color _color() {
    final value = text.toLowerCase();
    if (value.contains('verified') ||
        value.contains('approved') ||
        value.contains('online') ||
        value.contains('locked') ||
        value == 'in' ||
        value == 'clear' ||
        value.contains('resolved')) {
      return AppColors.success;
    }
    if (value.contains('reject') ||
        value.contains('late') ||
        value.contains('offline') ||
        value.contains('alert') ||
        value.contains('escalated')) {
      return AppColors.danger;
    }
    if (value.contains('pending') ||
        value.contains('ongoing') ||
        value.contains('review') ||
        value.contains('waiting') ||
        value.contains('due') ||
        value.contains('submitted')) {
      return AppColors.warning;
    }
    return AppColors.info;
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 138),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .105),
          borderRadius: const BorderRadius.all(
            Radius.circular(999),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 11.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    this.detail,
    this.onTap,
    this.highlight = false,
    this.color,
    super.key,
  });

  final String label;
  final String value;
  final IconData icon;
  final String? detail;
  final VoidCallback? onTap;
  final bool highlight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return CarmelitaCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      emphasis: highlight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final veryNarrow = constraints.maxWidth < 145;
          final iconSize = veryNarrow ? 40.0 : 44.0;

          final accent = color ?? mutedAccentForIcon(context, icon);
          final iconBox = Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .075),
              borderRadius: const BorderRadius.all(
                Radius.circular(14),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: veryNarrow ? 19 : 21,
              color: accent,
            ),
          );

          final copy = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: veryNarrow ? 18 : 21,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 4),
                Text(
                  detail!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          );

          if (veryNarrow) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    iconBox,
                    const Spacer(),
                    if (onTap != null)
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: .30),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                copy,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              iconBox,
              const SizedBox(width: 12),
              Expanded(child: copy),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: .30),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class QuickAction extends StatelessWidget {
  const QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
    super.key,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? mutedAccentForIcon(context, icon);
    return CarmelitaCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 14,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .075),
              borderRadius: const BorderRadius.all(
                Radius.circular(14),
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 20,
              color: accent,
            ),
          ),
          const SizedBox(height: 9),
          Text(
            label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 11.5,
                  height: 1.18,
                ),
          ),
        ],
      ),
    );
  }
}

class AdaptiveGrid extends StatelessWidget {
  const AdaptiveGrid({
    required this.children,
    this.minTileWidth = 220,
    super.key,
  });

  final List<Widget> children;
  final double minTileWidth;

  int _columnsFor(double width) => AppBreakpoints.columnsForMinTileWidth(
        width,
        minTileWidth: minTileWidth,
        spacing: 12,
        maxColumns: 4,
      );

  @override
  Widget build(BuildContext context) {
    const spacing = 12.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = _columnsFor(constraints.maxWidth);
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          alignment: WrapAlignment.start,
          children: children
              .map(
                (child) => SizedBox(
                  width: itemWidth,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class ActionGrid extends StatelessWidget {
  const ActionGrid({
    required this.children,
    super.key,
  });

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    const spacing = 10.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final columns = width < 360 || textScale >= 1.35
            ? 2
            : width < 600
                ? 3
                : width < 1024
                    ? 4
                    : 6;
        final itemWidth = (width - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map(
                (child) => SizedBox(
                  width: itemWidth,
                  child: child,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class PhotoHero extends StatelessWidget {
  const PhotoHero({
    required this.image,
    required this.title,
    required this.subtitle,
    this.height = 210,
    super.key,
  });

  final String image;
  final String title;
  final String subtitle;
  final double height;

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = AppBreakpoints.isPhone(context)
        ? height.clamp(180, 250).toDouble()
        : height.clamp(220, 320).toDouble();

    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(26)),
      child: SizedBox(
        height: effectiveHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(image, fit: BoxFit.cover),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: .76),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AttentionCard extends StatelessWidget {
  const AttentionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.status,
    this.onTap,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? status;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = mutedAccentForIcon(context, icon);
    return CarmelitaCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 9 : 14,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stackStatus = constraints.maxWidth < 320;
          final iconSize = compact ? 36.0 : 44.0;

          final leading = Container(
            width: iconSize,
            height: iconSize,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .075),
              borderRadius: BorderRadius.circular(compact ? 12 : 15),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              color: accent,
              size: compact ? 19 : 24,
            ),
          );

          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: compact
                    ? Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        )
                    : Theme.of(context).textTheme.titleMedium,
              ),
              SizedBox(height: compact ? 2 : 4),
              Text(
                subtitle,
                style: compact
                    ? Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 11,
                          height: 1.25,
                        )
                    : Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          );

          if (stackStatus && status != null) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leading,
                SizedBox(width: compact ? 9 : 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      copy,
                      SizedBox(height: compact ? 7 : 10),
                      StatusPill(status!),
                    ],
                  ),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              SizedBox(width: compact ? 9 : 13),
              Expanded(child: copy),
              if (status != null) ...[
                SizedBox(width: compact ? 7 : 10),
                StatusPill(status!),
              ] else if (onTap != null) ...[
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(top: 13),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class ConversationListCard extends StatelessWidget {
  const ConversationListCard({
    required this.name,
    required this.role,
    this.lastMessage,
    this.lastMessageText,
    this.lastMessageTime,
    this.unreadCount = 0,
    required this.onTap,
    super.key,
  });

  final String name;
  final String role;
  final ChatMessage? lastMessage;
  final String? lastMessageText;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final previewText =
        lastMessage?.body ?? lastMessageText ?? 'No messages yet';
    final previewTime = lastMessage?.sentAt ?? lastMessageTime;

    return CarmelitaCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 22,
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: .10),
          foregroundColor: Theme.of(context).colorScheme.primary,
          child: Text(
            name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            if (previewTime != null) ...[
              const SizedBox(width: 8),
              Text(
                timeText(previewTime),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
        subtitle: Text(
          '$role • $previewText',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (unreadCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  unreadCount.toString(),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    required this.label,
    required this.value,
    this.icon,
    super.key,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 370 ||
        MediaQuery.textScalerOf(context).scale(1) > 1.15;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(
                        icon,
                        size: 18,
                        color: mutedAccentForIcon(context, icon!),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: 19,
                    color: mutedAccentForIcon(context, icon!),
                  ),
                  const SizedBox(width: 10),
                ],
                SizedBox(
                  width: 118,
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class TimelineTile extends StatelessWidget {
  const TimelineTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.color,
    this.compact = true,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? mutedAccentForIcon(context, icon);
    return ListTile(
      dense: compact,
      visualDensity: compact ? const VisualDensity(vertical: -3) : null,
      minLeadingWidth: compact ? 36 : null,
      contentPadding: EdgeInsets.symmetric(
        horizontal: compact ? 0 : 2,
        vertical: compact ? 0 : 3,
      ),
      leading: Container(
        width: compact ? 36 : 42,
        height: compact ? 36 : 42,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: .075),
          borderRadius: const BorderRadius.all(Radius.circular(14)),
        ),
        child: Icon(
          icon,
          size: compact ? 18 : 21,
          color: accent,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: compact ? 12.5 : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: compact ? const TextStyle(fontSize: 11) : null,
      ),
      trailing: trailing,
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final accent = mutedAccentForIcon(context, icon);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 42),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .075),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 34,
                color: accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

void showAppSnackBar(
  BuildContext context,
  String message,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

class WorkInProgressNotice extends StatelessWidget {
  const WorkInProgressNotice({
    this.message =
        'Work in progress: curfew and background location behavior is still undergoing physical-device validation.',
    super.key,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Work in progress notice',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.tertiaryContainer.withValues(alpha: .65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.tertiary.withValues(alpha: .35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.construction_rounded,
                size: 20, color: scheme.onTertiaryContainer),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Responsive explanation of the privacy-preserving dual-geofence pipeline.
class TripwireFlowCard extends StatefulWidget {
  const TripwireFlowCard({
    this.compact = false,
    this.gateLabel = 'Point 1 → Point 2',
    this.initiallyExpanded = true,
    super.key,
  });

  final bool compact;
  final String gateLabel;
  final bool initiallyExpanded;

  @override
  State<TripwireFlowCard> createState() => _TripwireFlowCardState();
}

class _TripwireFlowCardState extends State<TripwireFlowCard> {
  late bool _expanded;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => setState(() {
              _dismissed = false;
              _expanded = true;
            }),
            icon: const Icon(Icons.info_outline, size: 16),
            label: const Text(
              'Show crossing detection guide',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    Widget legend(Color color, String title, String detail) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 11,
                height: 11,
                margin: const EdgeInsets.only(top: 3),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$title — ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: detail),
                    ],
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        );

    final diagram = Semantics(
      label:
          'Diagram showing the outer circular wake zone, four-corner property polygon, and Point 1 to Point 2 gate on the polygon edge.',
      child: Container(
        height: widget.compact ? 190 : 215,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: .32),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const _ActualGeofenceMap(
          key: const Key('dual-geofence-diagram'),
        ),
      ),
    );

    final explanation = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        legend(scheme.primary, 'Wake circle',
            'low-power OS region that starts verification.'),
        legend(const Color(0xFF56886B), 'Property polygon',
            'the four measured corners decide inside or outside.'),
        legend(const Color(0xFFC77800), 'Official gate',
            '${widget.gateLabel} provides an extra prompt wake-up signal.'),
        const Divider(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline_rounded,
                size: 16, color: scheme.onSurfaceVariant),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                'Coordinates stay on the phone; only confirmed events are uploaded.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );

    return CarmelitaCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_searching_rounded,
                  size: 20, color: scheme.primary),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('How automatic crossing detection works',
                    style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              IconButton(
                tooltip: _expanded ? 'Collapse guide' : 'Expand guide',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
              IconButton(
                tooltip: 'Hide guide',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () => setState(() => _dismissed = true),
              ),
            ],
          ),
          if (_expanded) ...[
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final vertical = widget.compact || constraints.maxWidth < 620;
                if (vertical) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      diagram,
                      const SizedBox(height: 12),
                      explanation,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: diagram),
                    const SizedBox(width: 16),
                    Expanded(flex: 5, child: explanation),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Keeps filter controls on one horizontally scrollable line on phones while
/// retaining a wrapped desktop/tablet layout.
class ResponsiveFilterBar extends StatelessWidget {
  const ResponsiveFilterBar({
    super.key,
    required this.children,
    this.spacing = 8,
    this.runSpacing = 8,
    this.mobileBreakpoint = 600,
  });

  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final double mobileBreakpoint;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= mobileBreakpoint) {
          return Wrap(
            spacing: spacing,
            runSpacing: runSpacing,
            children: children,
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Row(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) SizedBox(width: spacing),
                children[index],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ActualGeofenceMap extends StatelessWidget {
  const _ActualGeofenceMap({super.key});

  @override
  Widget build(BuildContext context) {
    final points = GeofenceLocationService.activePolygon
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);
    final center = LatLng(
      GeofenceLocationService.activeCenterLatitude,
      GeofenceLocationService.activeCenterLongitude,
    );
    final gate = centeredGateSegment(GeofenceLocationService.activePolygon)
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList(growable: false);

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: 18.5,
          minZoom: 16,
          maxZoom: 21,
          interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.drag |
                InteractiveFlag.pinchZoom |
                InteractiveFlag.doubleTapZoom,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.carmelita.carmelink',
            maxNativeZoom: 19,
          ),
          CircleLayer(
            circles: [
              CircleMarker(
                point: center,
                radius: GeofenceLocationService.activeRadiusMeters,
                useRadiusInMeter: true,
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: .08),
                borderColor: Theme.of(context).colorScheme.primary,
                borderStrokeWidth: 2,
              ),
            ],
          ),
          if (points.length >= 3)
            PolygonLayer(
              polygons: [
                Polygon(
                  points: points,
                  color: const Color(0xFF56886B).withValues(alpha: .22),
                  borderColor: const Color(0xFF2F6D4A),
                  borderStrokeWidth: 3,
                ),
              ],
            ),
          if (gate.length == 2)
            PolylineLayer(
              polylines: [
                Polyline(
                  points: gate,
                  color: const Color(0xFFC77800).withValues(alpha: .22),
                  strokeWidth: 7.5,
                  useStrokeWidthInMeter: true,
                ),
                Polyline(
                  points: gate,
                  color: const Color(0xFFC77800),
                  strokeWidth: 4,
                ),
              ],
            ),
          MarkerLayer(
            markers: [
              for (var index = 0; index < points.length; index++)
                Marker(
                  point: points[index],
                  width: 26,
                  height: 26,
                  child: CircleAvatar(
                    backgroundColor: const Color(0xFF2F6D4A),
                    foregroundColor: Colors.white,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          RichAttributionWidget(
            attributions: [
              TextSourceAttribution(
                'OpenStreetMap contributors',
                onTap: () => launchUrl(
                  Uri.parse('https://www.openstreetmap.org/copyright'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String money(double value) => '₱${value.toStringAsFixed(0)}';

String shortDate(DateTime value) {
  final local = value.toLocal();
  return '${local.month}/${local.day}/${local.year}';
}

String timeText(DateTime value) {
  final local = value.toLocal();
  final hour =
      local.hour == 0 ? 12 : (local.hour > 12 ? local.hour - 12 : local.hour);
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${local.hour >= 12 ? 'PM' : 'AM'}';
}
