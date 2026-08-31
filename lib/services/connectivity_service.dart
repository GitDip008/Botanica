import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Tracks whether the device has internet connectivity.
///
/// Trust priority:
///   1. If the platform reports an active interface (wifi/mobile/ethernet/vpn)
///      we treat it as ONLINE. This is the common case and avoids the
///      "stuck offline" bug caused by flaky DNS on garden / captive-portal
///      Wi-Fi.
///   2. If the platform reports no interface, we do a quick DNS probe to
///      confirm — sometimes Android lags reporting a new connection. If the
///      probe succeeds we still report ONLINE.
///   3. Only if both checks fail do we show the offline banner.
class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  bool _online = true; // optimistic — never flash the banner at boot
  bool get online => _online;
  bool get offline => !_online;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  void init() {
    // First snapshot, then live updates.
    _verify();
    _sub = Connectivity().onConnectivityChanged.listen((_) => _verify());
  }

  Future<void> _verify() async {
    final results = await Connectivity().checkConnectivity();
    final hasInterface = results.any((r) =>
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.mobile ||
        r == ConnectivityResult.ethernet ||
        r == ConnectivityResult.vpn);

    // Trust the platform when it says we have an interface — works on
    // garden Wi-Fi, captive portals, networks that block google.com, etc.
    if (hasInterface) {
      _set(true);
      return;
    }

    // No interface reported → double-check with a fast DNS probe.
    //
    // Not on web: dart:io compiles there but InternetAddress is a stub that
    // fails at runtime, and in a release build that surfaces as an opaque
    // subtype error which kills startup — a permanently blank page rather than
    // a wrong connectivity reading. The browser's own reachability signal is
    // what checkConnectivity already reports, so there is nothing to add.
    if (kIsWeb) {
      _set(false);
      return;
    }
    try {
      final lookup = await InternetAddress.lookup('one.one.one.one')
          .timeout(const Duration(seconds: 2));
      _set(lookup.isNotEmpty && lookup.first.rawAddress.isNotEmpty);
    } catch (_) {
      _set(false);
    }
  }

  void _set(bool isOnline) {
    if (isOnline != _online) {
      _online = isOnline;
      notifyListeners();
    }
  }

  /// Public — for the banner's tap-to-recheck affordance.
  Future<void> recheck() => _verify();

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
