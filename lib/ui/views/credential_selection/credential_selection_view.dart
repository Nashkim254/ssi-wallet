import 'package:flutter/material.dart';
import 'package:ssi/ui/models/credential.dart';
import 'package:ssi/ui/models/presentation_request.dart';

class CredentialSelectionView extends StatelessWidget {
  final PresentationRequest request;
  final List<Credential> matchingCredentials;

  const CredentialSelectionView({
    Key? key,
    required this.request,
    required this.matchingCredentials,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Credential'),
      ),
      body: Column(
        children: [
          // Verifier Info Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.verifierName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              request.verifierUrl,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Select a credential to share:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          // Matching Credentials List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: matchingCredentials.length,
              itemBuilder: (context, index) {
                final credential = matchingCredentials[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.card_membership),
                    ),
                    title: Text(credential.name),
                    subtitle: Text(
                      'Issued by ${credential.issuerName}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => Navigator.pop(context, credential),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
