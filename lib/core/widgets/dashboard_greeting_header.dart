import 'dart:async';

import 'package:flutter/material.dart';

import 'common_widgets.dart';

/// Dormitory greetings use Philippine time, regardless of the device timezone.
String dashboardGreeting(DateTime instant) {
  final hour = instant.toUtc().add(const Duration(hours: 8)).hour;
  if (hour >= 5 && hour < 12) return 'Good morning';
  if (hour >= 12 && hour < 18) return 'Good afternoon';
  return 'Good evening';
}

class DashboardGreetingHeader extends StatefulWidget {
  const DashboardGreetingHeader({
    required this.eyebrow,
    this.name,
    this.subtitle,
    this.trailing,
    this.now = DateTime.now,
    super.key,
  });

  final String eyebrow;
  final String? name;
  final String? subtitle;
  final Widget? trailing;
  final DateTime Function() now;

  @override
  State<DashboardGreetingHeader> createState() =>
      _DashboardGreetingHeaderState();
}

class _DashboardGreetingHeaderState extends State<DashboardGreetingHeader>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    _timer?.cancel();
    final now = widget.now();
    final nextMinute = DateTime.fromMillisecondsSinceEpoch(
      (now.millisecondsSinceEpoch ~/ 60000 + 1) * 60000,
      isUtc: true,
    );
    _timer = Timer(nextMinute.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleRefresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _scheduleRefresh();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final greeting = dashboardGreeting(widget.now());
    final name = widget.name?.trim();
    return ElegantHeader(
      eyebrow: widget.eyebrow,
      title: name == null || name.isEmpty ? '$greeting.' : '$greeting, $name.',
      subtitle: widget.subtitle,
      trailing: widget.trailing,
    );
  }
}
