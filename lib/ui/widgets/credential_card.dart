import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ssi/ui/models/credential.dart';
import 'package:ssi/ui/theme/app_theme.dart';

class CredentialCard extends StatelessWidget {
  final Credential credential;
  final VoidCallback? onTap;
  final bool showStatus;

  const CredentialCard({
    super.key,
    required this.credential,
    this.onTap,
    this.showStatus = true,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = credential.backgroundColor != null
        ? Color(
            int.parse(credential.backgroundColor!.replaceFirst('#', '0xFF')))
        : AppColors.primary;

    final textColor = credential.textColor != null
        ? Color(int.parse(credential.textColor!.replaceFirst('#', '0xFF')))
        : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              backgroundColor,
              backgroundColor.withOpacity(0.8),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background Pattern
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: CustomPaint(
                  painter:
                      CardPatternPainter(color: textColor.withOpacity(0.1)),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Credential Type Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: textColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getCredentialTypeLabel(credential.format),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                      ),

                      // Status Indicator
                      if (showStatus &&
                          credential.state != CredentialState.valid)
                        _buildStatusBadge(textColor),
                    ],
                  ),

                  const Spacer(),

                  // Credential Name
                  Text(
                    credential.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  // Issuer Name
                  Row(
                    children: [
                      Icon(
                        Icons.business_rounded,
                        size: 14,
                        color: textColor.withOpacity(0.8),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Issued by ${credential.issuerName}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: textColor.withOpacity(0.9),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Issued Date
                      Text(
                        'Issued ${_formatDate(credential.issuedDate)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),

                      // Expiry Date
                      if (credential.expiryDate != null)
                        Row(
                          children: [
                            Icon(
                              credential.isExpired
                                  ? Icons.error_rounded
                                  : credential.isExpiringSoon
                                      ? Icons.warning_rounded
                                      : Icons.schedule_rounded,
                              size: 12,
                              color: credential.isExpired ||
                                      credential.isExpiringSoon
                                  ? Colors.amber
                                  : textColor.withOpacity(0.7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              credential.isExpired
                                  ? 'Expired'
                                  : 'Exp ${_formatDate(credential.expiryDate!)}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: credential.isExpired ||
                                        credential.isExpiringSoon
                                    ? Colors.amber
                                    : textColor.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Color textColor) {
    IconData icon;
    String label;
    Color badgeColor;

    switch (credential.state) {
      case CredentialState.expired:
        icon = Icons.error_rounded;
        label = 'Expired';
        badgeColor = Colors.red;
        break;
      case CredentialState.revoked:
        icon = Icons.block_rounded;
        label = 'Revoked';
        badgeColor = Colors.red;
        break;
      case CredentialState.suspended:
        icon = Icons.pause_circle_rounded;
        label = 'Suspended';
        badgeColor = Colors.orange;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _getCredentialTypeLabel(String format) {
    switch (format.toLowerCase()) {
      case 'jwt':
      case 'jwt_vc':
        return 'JWT VC';
      case 'sd-jwt':
      case 'sdjwt':
        return 'SD-JWT';
      case 'mdoc':
      case 'iso_mdoc':
        return 'ISO mDL';
      case 'jsonld':
      case 'json-ld':
        return 'JSON-LD';
      default:
        return format.toUpperCase();
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays < 30) {
      return DateFormat('MMM d').format(date);
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }
}

class CardPatternPainter extends CustomPainter {
  final Color color;

  CardPatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Draw circles pattern
    for (var i = 0; i < 5; i++) {
      for (var j = 0; j < 3; j++) {
        final x = size.width * (0.2 + i * 0.2);
        final y = size.height * (0.2 + j * 0.3);
        canvas.drawCircle(Offset(x, y), 40, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
