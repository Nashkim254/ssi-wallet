import 'package:flutter/material.dart';
import 'package:ssi/ui/models/credential.dart';
import 'package:ssi/ui/models/presentation_request.dart';

class PresentationConsentView extends StatefulWidget {
  final PresentationRequest request;
  final Credential selectedCredential;

  const PresentationConsentView({
    Key? key,
    required this.request,
    required this.selectedCredential,
  }) : super(key: key);

  @override
  State<PresentationConsentView> createState() =>
      _PresentationConsentViewState();
}

class _PresentationConsentViewState extends State<PresentationConsentView> {
  Map<String, bool> selectedClaims = {};

  @override
  void initState() {
    super.initState();
    // Initialize with all required claims selected
    for (var claim in widget.request.requestedClaims) {
      selectedClaims[claim.claimName] = claim.required;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Share Information'),
      ),
      body: Column(
        children: [
          // Verifier Info
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.verified_user, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.request.verifierName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.request.verifierUrl,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.lock, color: Colors.green),
                ],
              ),
            ),
          ),

          // Requested Claims
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                const Text(
                  'Information requested:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                ...widget.request.requestedClaims.map((claim) {
                  final claimValue =
                      widget.selectedCredential.claims[claim.claimName];
                  final intentToRetain =
                      widget.request.intentToRetain?[claim.claimName] ?? false;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: CheckboxListTile(
                      value: selectedClaims[claim.claimName] ?? false,
                      onChanged: claim.required
                          ? null
                          : (value) {
                              setState(() {
                                selectedClaims[claim.claimName] = value ?? false;
                              });
                            },
                      title: Text(
                        _formatClaimName(claim.claimName),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(claimValue?.toString() ?? 'N/A'),
                          if (claim.required)
                            const Text(
                              'Required',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 11,
                              ),
                            ),
                          if (intentToRetain)
                            const Text(
                              '⚠️ May be stored by verifier',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }).toList(),

                const SizedBox(height: 16),

                // Privacy Notice
                Card(
                  color: Colors.blue.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.info_outline, color: Colors.blue),
                            SizedBox(width: 8),
                            Text(
                              'Privacy Notice',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Only the selected information will be shared. '
                          'Required fields are marked and cannot be deselected.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final selected = selectedClaims.entries
                          .where((e) => e.value)
                          .map((e) => e.key)
                          .toList();
                      Navigator.pop(context, selected);
                    },
                    child: const Text('Share'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatClaimName(String claimName) {
    // Convert snake_case to Title Case
    return claimName
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}
