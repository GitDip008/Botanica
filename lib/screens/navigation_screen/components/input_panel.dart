/// PURPOSE:
/// This file implements the InputPanel widget which contains the form inputs (TextFields)
/// for X and Y coordinates of the start and end navigation points.
///
/// CONTEXT/PARENT FILE:
/// Extracted from 'navigation_screen.dart' to isolate coordinate input forms.
///
/// INPUTS / PARAMETERS:
/// - startXCtrl (TextEditingController, Required): Controller for start location X coordinate.
/// - startYCtrl (TextEditingController, Required): Controller for start location Y coordinate.
/// - endXCtrl (TextEditingController, Required): Controller for destination location X coordinate.
/// - endYCtrl (TextEditingController, Required): Controller for destination location Y coordinate.
/// - statusMsg (String, Required): Status message (e.g. error or distance info).
/// - computedPath (List, Required): List of path nodes (used to check if path exists).
/// - onFindRoute (VoidCallback, Required): Action when "Find Route" is pressed.

import 'package:flutter/material.dart';

class InputPanel extends StatelessWidget {
  final TextEditingController startXCtrl;
  final TextEditingController startYCtrl;
  final TextEditingController endXCtrl;
  final TextEditingController endYCtrl;
  final String statusMsg;
  final List computedPath;
  final VoidCallback onFindRoute;

  const InputPanel({
    super.key,
    required this.startXCtrl,
    required this.startYCtrl,
    required this.endXCtrl,
    required this.endYCtrl,
    required this.statusMsg,
    required this.computedPath,
    required this.onFindRoute,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface.withOpacity(0.97),
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.my_location, color: Theme.of(context).colorScheme.secondary, size: 16.0),
              const SizedBox(width: 8.0),
              const SizedBox(
                width: 36.0,
                child: Text(
                  'Start',
                  style: TextStyle(color: Colors.white70, fontSize: 12.0),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(child: _inputField(context, startXCtrl, 'X')),
              const SizedBox(width: 8.0),
              Expanded(child: _inputField(context, startYCtrl, 'Y')),
            ],
          ),
          const SizedBox(height: 8.0),
          Row(
            children: [
              const Icon(
                Icons.location_pin,
                color: Color(0xFFEF5350),
                size: 16.0,
              ),
              const SizedBox(width: 8.0),
              const SizedBox(
                width: 36.0,
                child: Text(
                  'End',
                  style: TextStyle(color: Colors.white70, fontSize: 12.0),
                ),
              ),
              const SizedBox(width: 8.0),
              Expanded(child: _inputField(context, endXCtrl, 'X')),
              const SizedBox(width: 8.0),
              Expanded(child: _inputField(context, endYCtrl, 'Y')),
            ],
          ),
          const SizedBox(height: 10.0),
          if (statusMsg.isNotEmpty && computedPath.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Text(
                statusMsg,
                style: const TextStyle(color: Color(0xFFEF5350), fontSize: 11.0),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 10.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              icon: const Icon(Icons.route, size: 16.0),
              label: const Text(
                'Find Route',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.0),
              ),
              onPressed: onFindRoute,
            ),
          ),
        ],
      ),
    );
  }

  /// BEHAVIORAL MECHANISM:
  /// Renders a dense styled text field with number input constraints suitable for entering CAD coordinate values.
  ///
  /// PARAMETERS:
  /// - context (BuildContext): App context for styling theme.
  /// - ctrl (TextEditingController): Controller mapping the input value.
  /// - hint (String): Placeholder hint.
  ///
  /// RETURNS:
  /// - Widget: The configured TextField widget.
  Widget _inputField(BuildContext context, TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(
        signed: true,
        decimal: true,
      ),
      style: const TextStyle(color: Colors.white, fontSize: 12.0),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.white38, fontSize: 12.0),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
        filled: true,
        fillColor: Theme.of(context).scaffoldBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6.0),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
