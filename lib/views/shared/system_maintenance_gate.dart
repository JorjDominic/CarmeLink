import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../controllers/session_controller.dart';
import '../../models/models.dart';
import '../../services/system_maintenance_service.dart';

/// App availability gate across the Navigator, including already-open routes.
/// Database authorization continues to be enforced by the existing RLS policies.
class SystemMaintenanceGate extends StatefulWidget {
  const SystemMaintenanceGate(
      {super.key,
      required this.child,
      this.service = const SystemMaintenanceService(),
      this.session});
  final Widget child;
  final SystemMaintenanceService service;
  final ValueListenable<AppUser?>? session;
  @override
  State<SystemMaintenanceGate> createState() => _SystemMaintenanceGateState();
}

class _SystemMaintenanceGateState extends State<SystemMaintenanceGate>
    with WidgetsBindingObserver {
  AppUser? get user => widget.session != null
      ? widget.session!.value
      : SessionController.instance.currentUser;
  Listenable get session => widget.session ?? SessionController.instance;
  Timer? timer;
  String? userId;
  UserRole? userRole;
  Map<String, dynamic>? settings;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session.addListener(sessionChanged);
    sessionChanged();
    timer = Timer.periodic(const Duration(seconds: 30), (_) => refresh());
  }

  void sessionChanged() {
    final id = user?.id;
    if (id == userId && user?.role == userRole) return;
    userId = id;
    userRole = user?.role;
    settings = null;
    refresh();
    if (mounted) setState(() {});
  }

  Future<void> refresh() async {
    final request = ++generation;
    final role = user?.role;
    if (role != UserRole.tenant && role != UserRole.guardian) return;
    try {
      final result = await widget.service.settings();
      if (mounted && request == generation)
        setState(() {
          settings = result;
        });
    } catch (_) {
      // Missing migrations, network failures and unavailable settings must not
      // lock residents out. Retain only the last successfully confirmed state.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    session.removeListener(sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = user?.role;
    if (role != UserRole.tenant && role != UserRole.guardian)
      return widget.child;
    if (settings?['enabled'] != true) return widget.child;
    return Scaffold(
        body: SafeArea(
            child: Center(
                child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text('System maintenance',
                          style: Theme.of(context).textTheme.titleLarge,
                          textAlign: TextAlign.center),
                      Text(settings!['message'] as String,
                          textAlign: TextAlign.center),
                      TextButton(
                          onPressed: refresh, child: const Text('Check again')),
                      TextButton(
                          onPressed: () => SessionController.instance.signOut(),
                          child: const Text('Sign out')),
                    ])))));
  }
}
