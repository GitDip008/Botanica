import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import '../services/language_service.dart';

/// Overlays the child with an offline banner that slides down from the top
/// when the device loses internet. Hidden completely (offstage) when online —
/// no peeking, no leftover gap.
class OfflineBannerOverlay extends StatefulWidget {
  final Widget child;
  const OfflineBannerOverlay({super.key, required this.child});

  @override
  State<OfflineBannerOverlay> createState() => _OfflineBannerOverlayState();
}

class _OfflineBannerOverlayState extends State<OfflineBannerOverlay> {
  @override
  void initState() {
    super.initState();
    ConnectivityService.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    ConnectivityService.instance.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final offline = ConnectivityService.instance.offline;
    final s = LanguageService.instance.strings;

    return Stack(
      children: [
        widget.child,
        // When online, remove the banner from the tree entirely. No peeking,
        // no partial offset, no leftover pixels.
        if (offline)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => ConnectivityService.instance.recheck(),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B2A0B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFB300)),
                    ),
                    child: Row(children: [
                      const Icon(Icons.cloud_off_rounded,
                          color: Color(0xFFFFD54F), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(s.youAreOffline,
                            style: const TextStyle(
                                color: Color(0xFFFFE082),
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600)),
                      ),
                      const Icon(Icons.refresh_rounded,
                          color: Color(0xFFFFD54F), size: 16),
                    ]),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
