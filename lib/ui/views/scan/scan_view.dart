import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:ssi/ui/theme/app_theme.dart';
import 'package:stacked/stacked.dart';

import 'scan_viewmodel.dart';

class ScanView extends StackedView<ScanViewModel> {
  const ScanView({super.key});

  @override
  Widget builder(
    BuildContext context,
    ScanViewModel viewModel,
    Widget? child,
  ) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera view
          if (viewModel.hasPermission)
            MobileScanner(
              controller: viewModel.scannerController,
              onDetect: viewModel.onQRDetected,
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.camera_alt_outlined,
                      size: 80,
                      color: Colors.white54,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Camera Permission Required',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Please grant camera access to scan QR codes',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: viewModel.requestPermission,
                      child: const Text('Grant Permission'),
                    ),
                  ],
                ),
              ),
            ),

          // Overlay with scanning frame
          if (viewModel.hasPermission)
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
              ),
              child: Stack(
                children: [
                  // Top safe area
                  SafeArea(
                    child: Column(
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              // Back button
                              IconButton(
                                onPressed: viewModel.navigateBack,
                                icon: const Icon(
                                  Icons.arrow_back_rounded,
                                  color: Colors.white,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black26,
                                ),
                              ),
                              const Spacer(),
                              // Flash button
                              IconButton(
                                onPressed: viewModel.toggleFlash,
                                icon: Icon(
                                  viewModel.isFlashOn
                                      ? Icons.flash_on_rounded
                                      : Icons.flash_off_rounded,
                                  color: Colors.white,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: Colors.black26,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Scanning frame
                        Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Scanning square
                              Container(
                                width: 280,
                                height: 280,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),

                              // Corner decorations
                              ..._buildCorners(),

                              // Scanning line animation
                              if (viewModel.isScanning) const _ScanningLine(),
                            ],
                          ),
                        ),

                        const Spacer(),

                        // Instructions
                        Container(
                          margin: const EdgeInsets.all(20),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const Icon(
                                Icons.qr_code_scanner_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                viewModel.scanMessage,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Align the QR code within the frame',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Loading overlay
          if (viewModel.isProcessing)
            Container(
              color: Colors.black87,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.white,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      viewModel.processingMessage,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    return [
      // Top-left corner
      Positioned(
        left: 0,
        top: 0,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.primary, width: 4),
              top: BorderSide(color: AppColors.primary, width: 4),
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
            ),
          ),
        ),
      ),
      // Top-right corner
      Positioned(
        right: 0,
        top: 0,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: AppColors.primary, width: 4),
              top: BorderSide(color: AppColors.primary, width: 4),
            ),
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(20),
            ),
          ),
        ),
      ),
      // Bottom-left corner
      Positioned(
        left: 0,
        bottom: 0,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.primary, width: 4),
              bottom: BorderSide(color: AppColors.primary, width: 4),
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(20),
            ),
          ),
        ),
      ),
      // Bottom-right corner
      Positioned(
        right: 0,
        bottom: 0,
        child: Container(
          width: 30,
          height: 30,
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: AppColors.primary, width: 4),
              bottom: BorderSide(color: AppColors.primary, width: 4),
            ),
            borderRadius: BorderRadius.only(
              bottomRight: Radius.circular(20),
            ),
          ),
        ),
      ),
    ];
  }

  @override
  ScanViewModel viewModelBuilder(BuildContext context) => ScanViewModel();

  @override
  void onViewModelReady(ScanViewModel viewModel) => viewModel.initialize();

  @override
  void onDispose(ScanViewModel viewModel) => viewModel.disposeScanner();
}

class _ScanningLine extends StatefulWidget {
  const _ScanningLine();

  @override
  State<_ScanningLine> createState() => _ScanningLineState();
}

class _ScanningLineState extends State<_ScanningLine> {
  int _key = 0;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(_key),
      tween: Tween(begin: -1.0, end: 1.0),
      duration: const Duration(seconds: 2),
      onEnd: () {
        setState(() {
          _key++;
        });
      },
      builder: (context, value, child) {
        return Positioned(
          top: 140 + (value * 120),
          child: Container(
            width: 260,
            height: 2,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.primary,
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary,
                  blurRadius: 10,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
