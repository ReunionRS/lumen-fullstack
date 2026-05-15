import 'package:flutter/material.dart';

import '../../core/ui_tokens.dart';

class HouseCard extends StatelessWidget {
  const HouseCard({
    super.key,
    required this.imageAsset,
    this.imageUrl,
    required this.name,
    required this.address,
    required this.year,
    required this.documentsCount,
    this.onTap,
  });

  final String imageAsset;
  final String? imageUrl;
  final String name;
  final String address;
  final String year;
  final int documentsCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: UiTokens.card(context),
          borderRadius: BorderRadius.circular(18),
          boxShadow: UiTokens.cardShadow(context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(18)),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: imageUrl != null && imageUrl!.isNotEmpty
                    ? Image.network(
                        imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Image.asset(
                          imageAsset,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Image.asset(
                        imageAsset,
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: UiTokens.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    address,
                    style: TextStyle(
                      fontSize: 12,
                      color: UiTokens.muted(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        year,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: UiTokens.muted(context),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$documentsCount документов',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: UiTokens.muted(context),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
