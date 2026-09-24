import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

/// Lightweight app-level connection status notice.
///
/// This reports whether the device currently has a usable network transport.
/// Individual requests still keep their own timeout/error handling because
/// Wi-Fi or mobile data does not guarantee that the internet is reachable.
class ConnectivityBannerHost extends StatefulWidget {
  const ConnectivityBannerHost({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  State<ConnectivityBannerHost> createState() => _ConnectivityBannerHostState();
}

class _ConnectivityBannerHostState extends State<ConnectivityBannerHost> {
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _restoredTimer;

  bool _receivedInitialState = false;
  bool _offline = false;
  bool _showRestored = false;

  @override
  void initState() {
    super.initState();

    _subscription = _connectivity.onConnectivityChanged.listen(
      _applyConnectivity,
      onError: (Object error) {
        debugPrint('Connectivity listener error: $error');
      },
    );

    unawaited(_loadInitialConnectivity());
  }

  Future<void> _loadInitialConnectivity() async {
    try {
      _applyConnectivity(await _connectivity.checkConnectivity());
    } catch (error) {
      debugPrint('Could not read connectivity state: $error');
    }
  }

  void _applyConnectivity(List<ConnectivityResult> results) {
    if (!mounted) return;

    final nextOffline = results.isEmpty ||
        results.every((result) => result == ConnectivityResult.none);

    if (!_receivedInitialState) {
      setState(() {
        _receivedInitialState = true;
        _offline = nextOffline;
        _showRestored = false;
      });
      return;
    }

    if (nextOffline == _offline) return;

    final wasOffline = _offline;
    _restoredTimer?.cancel();

    setState(() {
      _offline = nextOffline;
      _showRestored = wasOffline && !nextOffline;
    });

    if (_showRestored) {
      _restoredTimer = Timer(const Duration(seconds: 3), () {
        if (!mounted) return;
        setState(() => _showRestored = false);
      });
    }
  }

  @override
  void dispose() {
    _restoredTimer?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visible = _receivedInitialState && (_offline || _showRestored);

    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: SafeArea(
            bottom: false,
            child: IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: visible
                    ? _ConnectionStatusBanner(
                        key: ValueKey<String>(
                          _offline ? 'offline' : 'restored',
                        ),
                        offline: _offline,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConnectionStatusBanner extends StatelessWidget {
  const _ConnectionStatusBanner({
    required this.offline,
    super.key,
  });

  final bool offline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background =
        offline ? scheme.errorContainer : scheme.primaryContainer;
    final foreground =
        offline ? scheme.onErrorContainer : scheme.onPrimaryContainer;

    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .10),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              offline
                  ? Icons.wifi_off_rounded
                  : Icons.check_circle_outline_rounded,
              size: 19,
              color: foreground,
            ),
            const SizedBox(width: 9),
            Flexible(
              child: Text(
                offline
                    ? "You're currently offline"
                    : 'Your internet connection was restored',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
