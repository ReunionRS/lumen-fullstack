import 'package:flutter/material.dart';

import '../../core/app_language.dart';
import '../../core/ui_tokens.dart';
import '../../models/project_models.dart';
import 'house_card.dart';
import 'quick_action.dart';
import 'status_badge.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.projects,
    required this.greetingName,
    required this.role,
    required this.canCreateProject,
    required this.onCreateProject,
    required this.onSelectProject,
    required this.onOpenNotifications,
    required this.onOpenSystems,
    required this.onOpenConstruction,
    required this.onOpenDocuments,
    required this.onOpenMaintenance,
    required this.onOpenJournal,
    required this.onOpenFinances,
    required this.onOpenSupport,
    required this.onOpenAdminPanel,
    required this.hasUnreadNotifications,
    required this.resolveFileUrl,
    required this.language,
    this.systemStatusOk = true,
    this.systemTemp = '--',
    this.systemEnergy = '--',
    this.systemHumidity = '--',
    this.systemSecurity = '--',
  });

  final List<ProjectSummary> projects;
  final String greetingName;
  final String role;
  final bool canCreateProject;
  final VoidCallback onCreateProject;
  final ValueChanged<ProjectSummary> onSelectProject;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenSystems;
  final VoidCallback onOpenConstruction;
  final VoidCallback onOpenDocuments;
  final VoidCallback onOpenMaintenance;
  final VoidCallback onOpenJournal;
  final VoidCallback onOpenFinances;
  final VoidCallback onOpenSupport;
  final VoidCallback onOpenAdminPanel;
  final bool hasUnreadNotifications;
  final String Function(String) resolveFileUrl;
  final AppLanguage language;
  final bool systemStatusOk;
  final String systemTemp;
  final String systemEnergy;
  final String systemHumidity;
  final String systemSecurity;

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
    final isAdmin = role == 'admin';
    return Container(
      color: UiTokens.background(context),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 88),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _t('Добро пожаловать', 'Валэктон', 'Welcome',
                          tt: 'Рәхим итегез', ba: 'Рәхим итегеҙ'),
                      style: TextStyle(
                        fontSize: 12,
                        color: UiTokens.muted(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      greetingName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: UiTokens.foreground(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconBubble(
                    icon: Icons.notifications_none,
                    onTap: onOpenNotifications,
                    showDot: hasUnreadNotifications,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (!isAdmin)
            InkWell(
              onTap: onOpenSystems,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: UiTokens.card(context),
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: UiTokens.cardShadow(context),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _t('Статус систем', 'Системалэн статуссы',
                              'System status',
                              tt: 'Системалар статусы',
                              ba: 'Системалар статусы'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: UiTokens.foreground(context),
                          ),
                        ),
                        StatusBadge(
                          label: systemStatusOk
                              ? _t('Всё в норме', 'Ваньмыз нормо', 'All good',
                                  tt: 'Барысы да тәртиптә',
                                  ba: 'Барыһы ла тәртиптә')
                              : _t('Требует внимания', 'Игътисал кулэ',
                                  'Needs attention',
                                  tt: 'Игътибар кирәк', ba: 'Иғтибар кәрәк'),
                          tone: systemStatusOk
                              ? StatusTone.success
                              : StatusTone.warning,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _StatItem(
                            icon: Icons.thermostat_outlined,
                            value: systemTemp,
                            label: _t('Темп.', 'Темп.', 'Temp.')),
                        _StatItem(
                            icon: Icons.bolt_outlined,
                            value: systemEnergy,
                            label: _t('Энергия', 'Энергия', 'Energy',
                                tt: 'Энергия', ba: 'Энергия')),
                        _StatItem(
                            icon: Icons.shield_outlined,
                            value: systemSecurity,
                            label: _t('Охрана', 'Утён', 'Security',
                                tt: 'Сак', ba: 'Һаҡ')),
                        _StatItem(
                            icon: Icons.water_drop_outlined,
                            value: systemHumidity,
                            label: _t('Влажн.', 'Лыжыклык', 'Humidity')),
                      ],
                    )
                  ],
                ),
              ),
            ),
          const SizedBox(height: 18),
          Text(
            _t('Быстрые действия', 'Тазьы ик каронъёс', 'Quick actions',
                tt: 'Тиз гамәлләр', ba: 'Тиҙ ғәмәлдәр'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: UiTokens.foreground(context),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: isAdmin
                  ? [
                      QuickAction(
                        icon: Icons.construction_outlined,
                        label: _t('Стройка', 'Лэсьтон', 'Construction',
                            tt: 'Төзелеш', ba: 'Төҙөлөш'),
                        onTap: onOpenConstruction,
                      ),
                      const SizedBox(width: 10),
                      QuickAction(
                        icon: Icons.support_agent,
                        label: _t('Поддержка', 'Поддержка', 'Support',
                            tt: 'Ярдәм', ba: 'Ярҙам'),
                        onTap: onOpenSupport,
                      ),
                      const SizedBox(width: 10),
                      QuickAction(
                        icon: Icons.admin_panel_settings_outlined,
                        label: _t('Панель', 'Панель', 'Panel',
                            tt: 'Панель', ba: 'Панель'),
                        onTap: onOpenAdminPanel,
                      ),
                    ]
                  : [
                      QuickAction(
                        icon: Icons.construction_outlined,
                        label: _t('Стройка', 'Лэсьтон', 'Construction',
                            tt: 'Төзелеш', ba: 'Төҙөлөш'),
                        onTap: onOpenConstruction,
                      ),
                      const SizedBox(width: 10),
                      QuickAction(
                        icon: Icons.folder_open_outlined,
                        label: _t('Документы', 'Документъёс', 'Documents',
                            tt: 'Документлар', ba: 'Документтар'),
                        onTap: onOpenDocuments,
                      ),
                      const SizedBox(width: 10),
                      QuickAction(
                        icon: Icons.calendar_month_outlined,
                        label: _t('Сервис', 'Сервис', 'Service',
                            tt: 'Сервис', ba: 'Сервис'),
                        onTap: onOpenMaintenance,
                      ),
                      const SizedBox(width: 10),
                      QuickAction(
                        icon: Icons.book_outlined,
                        label: _t('Журнал', 'Журнал', 'Journal',
                            tt: 'Журнал', ba: 'Журнал'),
                        onTap: onOpenJournal,
                      ),
                      const SizedBox(width: 10),
                      QuickAction(
                        icon: Icons.account_balance_wallet_outlined,
                        label: _t('Финансы', 'Финансъёс', 'Finances',
                            tt: 'Финанслар', ba: 'Финанстар'),
                        onTap: onOpenFinances,
                      ),
                      const SizedBox(width: 10),
                      QuickAction(
                        icon: Icons.support_agent,
                        label: _t('Поддержка', 'Поддержка', 'Support',
                            tt: 'Ярдәм', ba: 'Ярҙам'),
                        onTap: onOpenSupport,
                      ),
                    ],
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _t('Ваши объекты', 'Тон объектъёс', 'Your projects',
                    tt: 'Сезнең объектлар', ba: 'Һеҙҙең объекттар'),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: UiTokens.foreground(context),
                ),
              ),
              if (canCreateProject)
                TextButton(
                  onPressed: onCreateProject,
                  child: Text(_t('Добавить', 'Сутыны', 'Add',
                      tt: 'Өстәргә', ba: 'Өҫтәргә')),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (projects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                _t('Дома не найдены', 'Коркаос уг шедьты', 'No houses found',
                    tt: 'Йортлар табылмады', ba: 'Йорттар табылманы'),
                style: TextStyle(color: UiTokens.muted(context)),
              ),
            )
          else
            Column(
              children: List.generate(projects.length, (index) {
                final project = projects[index];
                final imageAsset =
                    index.isEven ? 'assets/house-1.jpg' : 'assets/house-2.jpg';
                final thumbnailUrl = project.thumbnailUrl.isEmpty
                    ? null
                    : resolveFileUrl(project.thumbnailUrl);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: HouseCard(
                    imageAsset: imageAsset,
                    imageUrl: thumbnailUrl,
                    name: project.clientFio.isEmpty
                        ? 'Дом №${index + 1}'
                        : project.clientFio,
                    address: project.constructionAddress.isEmpty
                        ? 'Адрес не указан'
                        : project.constructionAddress,
                    year: project.startDate.isEmpty
                        ? '—'
                        : project.startDate.substring(0, 4),
                    documentsCount: 0,
                    onTap: () => onSelectProject(project),
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  const _IconBubble({
    required this.icon,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: UiTokens.card(context),
              borderRadius: BorderRadius.circular(18),
              boxShadow: UiTokens.cardShadow(context),
            ),
            child: Icon(icon, size: 18, color: UiTokens.muted(context)),
          ),
        ),
        if (showDot)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: UiTokens.accent,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 18, color: UiTokens.accent),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: UiTokens.foreground(context),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: UiTokens.muted(context),
          ),
        ),
      ],
    );
  }
}
