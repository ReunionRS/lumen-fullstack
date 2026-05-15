import 'package:flutter/material.dart';

import '../../core/ui_tokens.dart';

class MoreSheetItem {
  const MoreSheetItem({
    required this.label,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
}

class MoreSheet extends StatelessWidget {
  const MoreSheet({
    super.key,
    required this.items,
  });

  final List<MoreSheetItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: UiTokens.card(context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: UiTokens.cardShadow(context),
      ),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
            child: ListView(
              physics: const ClampingScrollPhysics(),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Все разделы',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: UiTokens.foreground(context),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: UiTokens.muted(context)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...items.map(
                  (item) => InkWell(
                    onTap: () {
                      Navigator.pop(context);
                      item.onTap();
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: UiTokens.surface(context),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(item.icon,
                                size: 18, color: UiTokens.muted(context)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: UiTokens.foreground(context),
                                  ),
                                ),
                                Text(
                                  item.description,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: UiTokens.muted(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right,
                              color: UiTokens.muted(context)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
