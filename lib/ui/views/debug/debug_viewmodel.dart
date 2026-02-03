import 'package:flutter/services.dart';
import 'package:ssi/app/app.locator.dart';
import 'package:ssi/pigeon/ssi_api.g.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class DebugViewModel extends BaseViewModel {
  final _ssiApi = SsiApi();
  final _snackbarService = locator<SnackbarService>();

  String _logs = 'Loading logs...';
  String get logs => _logs;

  Future<void> initialize() async {
    await loadLogs();
  }

  Future<void> loadLogs() async {
    setBusy(true);

    try {
      final debugLogs = await _ssiApi.getDebugLogs();
      if (debugLogs.isEmpty) {
        _logs = 'No logs available yet.\n\nLogs will appear here after credential operations.';
      } else {
        _logs = debugLogs;
      }
    } catch (e) {
      _logs = 'Error loading logs: $e';
    }

    setBusy(false);
    notifyListeners();
  }

  Future<void> copyLogsToClipboard() async {
    await Clipboard.setData(ClipboardData(text: _logs));
    _snackbarService.showSnackbar(
      message: 'Logs copied to clipboard',
      duration: const Duration(seconds: 2),
    );
  }
}
