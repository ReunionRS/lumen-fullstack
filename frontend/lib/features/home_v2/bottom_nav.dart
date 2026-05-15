import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/ui_tokens.dart';

class BottomNav extends StatelessWidget {
  const BottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.onOpenMore,
    required this.language,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onOpenMore;
  final AppLanguage language;

  String _t(
    String ru,
    String udm,
    String en, {
    String? tt,
    String? ba,
  }) {
    switch (language) {
      case AppLanguage.udm:
        return udm;
      case AppLanguage.tt:
        return tt ?? ru;
      case AppLanguage.ba:
        return ba ?? ru;
      case AppLanguage.en:
        return en;
      case AppLanguage.ru:
        return ru;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(icon: Icons.home_outlined, label: _t('Главная', 'Тӧдьы', 'Home', tt: 'Төп', ba: 'Баш')),
      _NavItem(icon: Icons.construction_outlined, label: _t('Стройка', 'Лэсьтон', 'Construction', tt: 'Төзелеш', ba: 'Төҙөлөш')),
      _NavItem(icon: Icons.build_outlined, label: _t('Системы', 'Системaос', 'Systems', tt: 'Системалар', ba: 'Системалар')),
      _NavItem(icon: Icons.folder_open_outlined, label: _t('Документы', 'Документъёс', 'Documents', tt: 'Документлар', ba: 'Документтар')),
      _NavItem(icon: Icons.menu_rounded, label: _t('Ещё', 'Мукет', 'More', tt: 'Тагын', ba: 'Тағы')),
    ];

    return Container(
      decoration: BoxDecoration(
        color: UiTokens.card(context).withOpacity(0.92),
        border: Border(
          top: BorderSide(color: UiTokens.border(context)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              final active = currentIndex == index;
              return InkWell(
                onTap: () {
                  if (index == items.length - 1) {
                    onOpenMore();
                    return;
                  }
                  onSelect(index);
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (active && index != items.length - 1)
                        Container(
                          width: 26,
                          height: 3,
                          decoration: BoxDecoration(
                            color: UiTokens.accent,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        )
                      else
                        const SizedBox(height: 3),
                      const SizedBox(height: 6),
                      Icon(
                        item.icon,
                        size: 20,
                        color:
                            active ? UiTokens.accent : UiTokens.muted(context),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: active
                              ? UiTokens.accent
                              : UiTokens.muted(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}
