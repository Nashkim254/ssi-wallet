import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stacked/stacked.dart';
import 'debug_viewmodel.dart';

class DebugView extends StackedView<DebugViewModel> {
  const DebugView({Key? key}) : super(key: key);

  @override
  Widget builder(
    BuildContext context,
    DebugViewModel viewModel,
    Widget? child,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: viewModel.loadLogs,
            tooltip: 'Refresh',
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            onPressed: viewModel.copyLogsToClipboard,
            tooltip: 'Copy to Clipboard',
          ),
        ],
      ),
      body: viewModel.isBusy
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                viewModel.logs,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                ),
              ),
            ),
    );
  }

  @override
  DebugViewModel viewModelBuilder(BuildContext context) => DebugViewModel();

  @override
  void onViewModelReady(DebugViewModel viewModel) => viewModel.initialize();
}
