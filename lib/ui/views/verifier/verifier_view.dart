import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:ssi/ui/theme/app_theme.dart';
import 'package:stacked/stacked.dart';

import 'verifier_viewmodel.dart';

class VerifierView extends StackedView<VerifierViewModel> {
  const VerifierView({super.key});

  @override
  Widget builder(BuildContext context, VerifierViewModel viewModel, Widget? child) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Credential'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: viewModel.cancel,
        ),
      ),
      body: SafeArea(child: _buildBody(context, viewModel)),
    );
  }

  Widget _buildBody(BuildContext context, VerifierViewModel viewModel) {
    switch (viewModel.state) {
      case VerifierState.scanning:
        return _buildScanning(viewModel);
      case VerifierState.connecting:
        return _buildConnecting();
      case VerifierState.result:
        return _buildResult(viewModel);
      case VerifierState.error:
        return _buildError(viewModel);
    }
  }

  // ── Scanning ────────────────────────────────────────────────────────────────

  Widget _buildScanning(VerifierViewModel viewModel) {
    final found = viewModel.holderFound;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pulsing BLE icon
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: (found ? AppColors.success : AppColors.primary).withOpacity(0.08),
                    shape: BoxShape.circle,
                  ),
                ).animate(onPlay: (c) => c.repeat()).scale(
                  begin: const Offset(0.9, 0.9),
                  end: const Offset(1.1, 1.1),
                  duration: 1200.ms,
                  curve: Curves.easeInOut,
                ),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: (found ? AppColors.success : AppColors.primary).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    found ? Icons.bluetooth_connected : Icons.bluetooth_searching,
                    size: 56,
                    color: found ? AppColors.success : AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              found ? 'Holder detected!' : 'Scanning for holder…',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: found ? AppColors.success : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              found
                  ? 'Connecting via Bluetooth…'
                  : 'Make sure the holder has opened\n"Share in Person" on their device.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            if (!found) ...[
              const SizedBox(height: 40),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ── Connecting ──────────────────────────────────────────────────────────────

  Widget _buildConnecting() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 24),
          Text(
            'Connecting via Bluetooth…',
            style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          ),
          SizedBox(height: 8),
          Text(
            'Waiting for holder to approve',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  // ── Result ──────────────────────────────────────────────────────────────────

  Widget _buildResult(VerifierViewModel viewModel) {
    final dto = viewModel.result!;
    final claims = dto.receivedClaims;

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.verified, color: AppColors.success, size: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dto.holderName.isNotEmpty ? dto.holderName : 'Unknown Holder',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _friendlyDocType(dto.docType),
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.check_circle, color: AppColors.success),
              ],
            ),
          ),
        ).animate().fadeIn().slideY(begin: -0.2, end: 0),

        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              const Text(
                'Received claims:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...claims.entries
                  .where((e) => e.key != null && e.value != null)
                  .toList()
                  .asMap()
                  .entries
                  .map((entry) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(
                            _formatClaimName(entry.value.key!),
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(entry.value.value.toString()),
                          leading: const Icon(Icons.info_outline, color: AppColors.primary),
                        ),
                      ).animate().fadeIn(delay: (entry.key * 50).ms)),
            ],
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: viewModel.retry,
                  child: const Text('Verify Another'),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: viewModel.done,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Error ───────────────────────────────────────────────────────────────────

  Widget _buildError(VerifierViewModel viewModel) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline, size: 64, color: AppColors.error),
            ),
            const SizedBox(height: 24),
            const Text('Verification Failed',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(
              viewModel.errorMessage ?? 'An unknown error occurred',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                OutlinedButton(
                  onPressed: viewModel.cancel,
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: viewModel.retry,
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                  child: const Text('Scan Again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _formatClaimName(String name) {
    return name
        .split('_')
        .map((w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : w)
        .join(' ');
  }

  String _friendlyDocType(String docType) {
    if (docType.contains('mDL') || docType.contains('18013')) return 'Mobile Driving Licence';
    if (docType.contains('pid') || docType.contains('PID')) return 'Personal ID Document';
    return docType;
  }

  @override
  VerifierViewModel viewModelBuilder(BuildContext context) => VerifierViewModel();

  @override
  void onViewModelReady(VerifierViewModel viewModel) => viewModel.initialize();
}
