import 'package:flutter/material.dart';

import '../../core/i18n.dart';
import '../../core/formatters.dart';
import '../../core/ui_tokens.dart';
import '../../models/notification_models.dart';
import '../../models/project_models.dart';
import '../../services/auth_service.dart';
import 'maintenance_page.dart';
import 'maintenance_requests_page.dart';
import 'stage_details_page.dart';
import 'support_chat_page.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({
    super.key,
    required this.auth,
    required this.role,
  });

  final AuthService auth;
  final String role;

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _loading = true;
  String? _error;
  List<AppNotification> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.auth.fetchNotifications();
      if (!mounted) return;
      setState(() => _items = items);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    try {
      await widget.auth.markAllNotificationsRead();
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _openNotification(AppNotification item) async {
    await _markRead(item);
    if (item.type == 'stage_comment') {
      if (item.projectId.isEmpty) {
        _showMessage(I18n.t('Объект не найден', 'Объект уг шедьты', 'Project not found'));
        return;
      }
      try {
        final project = await widget.auth.fetchProjectById(item.projectId);
        if (!mounted) return;
        final idx = _resolveStageIndex(project, item.stageId);
        if (idx == null || idx < 0 || idx >= project.stages.length) {
          _showMessage(I18n.t('Этап не найден', 'Этап уг шедьты', 'Stage not found'));
          return;
        }
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => StageDetailsPage(
              projectId: project.id,
              stageIndex: idx,
              initialStage: project.stages[idx],
              auth: widget.auth,
              role: widget.role,
              onUpdated: () async {},
            ),
          ),
        );
      } catch (e) {
        _showMessage(e.toString().replaceFirst('Exception: ', ''));
      }
      return;
    }

    if (item.type == 'support_reply' || item.type == 'support_incoming') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SupportThreadPage(
            auth: widget.auth,
            role: widget.role,
            clientUserId: item.clientUserId.isEmpty ? null : item.clientUserId,
          ),
        ),
      );
      return;
    }

    if (item.type == 'maintenance') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MaintenancePage(
            auth: widget.auth,
            role: widget.role,
            projectId: item.projectId,
          ),
        ),
      );
      return;
    }

    if (item.type == 'maintenance_request') {
      if (widget.role != 'admin') return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => MaintenanceRequestsPage(auth: widget.auth),
        ),
      );
      return;
    }
  }

  Future<void> _markRead(AppNotification item) async {
    if (item.isRead) return;
    try {
      if (item.type == 'stage_comment') {
        await widget.auth.markNotificationRead(item.id);
      } else if (item.type == 'support_incoming') {
        final rawId = item.id.replaceFirst('support-admin-', '');
        await widget.auth.markSupportNotificationRead(rawId);
      } else if (item.type == 'maintenance') {
        final rawId = item.id.replaceFirst('maintenance-', '');
        await widget.auth.markMaintenanceNotificationRead(rawId);
      } else if (item.type == 'maintenance_request') {
        final rawId = item.id.replaceFirst('maintenance-request-', '');
        await widget.auth.markMaintenanceRequestNotificationRead(rawId);
      }
      if (!mounted) return;
      setState(() {
        _items = _items
            .map(
              (n) => n.id == item.id
                  ? AppNotification(
                      id: n.id,
                      title: n.title,
                      body: n.body,
                      createdAt: n.createdAt,
                      isRead: true,
                      type: n.type,
                      clientUserId: n.clientUserId,
                      projectId: n.projectId,
                      stageId: n.stageId,
                    )
                  : n,
            )
            .toList(growable: false);
      });
    } catch (_) {}
  }

  int? _resolveStageIndex(ProjectDetails project, String stageId) {
    if (stageId.isNotEmpty) {
      final idx = project.stages.indexWhere((s) => s.id == stageId);
      if (idx != -1) return idx;
      final match = RegExp(r'^stage-(\\d+)$').firstMatch(stageId);
      if (match != null) {
        final raw = int.tryParse(match.group(1) ?? '');
        if (raw != null) {
          return raw.clamp(0, project.stages.length - 1);
        }
      }
    }
    return null;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _items.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(I18n.t('Уведомления', 'Уведомлениеос', 'Notifications')),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${unreadCount.toString()} ${I18n.t('непрочитанных', 'лыдъямтэ', 'unread')}',
                      style: TextStyle(color: UiTokens.muted(context)),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: unreadCount == 0 ? null : _markAllRead,
                  child: Text(I18n.t('Прочитать все', 'Ваньмыз лыдъяны', 'Mark all read')),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              )
            else if (_items.isEmpty)
              Text(
                I18n.t('Уведомлений пока нет', 'Уведомлениеос али ӧвӧл', 'No notifications yet'),
                style: TextStyle(color: UiTokens.muted(context)),
              )
            else
              ..._items.map(
                (item) => _NotificationCard(
                  item: item,
                  onTap: () => _openNotification(item),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconData = _iconForType(item.type);
    final accent = _colorForType(item.type);
    final bgColor = item.isRead
        ? UiTokens.card(context)
        : UiTokens.surface(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: item.isRead ? Colors.transparent : accent.withOpacity(0.35),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: UiTokens.foreground(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    style: TextStyle(
                      fontSize: 12,
                      color: UiTokens.muted(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 14,
                        color: UiTokens.muted(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(item.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: UiTokens.muted(context),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
            if (!item.isRead)
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _iconForType(String type) {
    switch (type) {
      case 'support_reply':
      case 'support_incoming':
        return Icons.support_agent;
      case 'stage_comment':
        return Icons.build;
      case 'maintenance':
        return Icons.calendar_month_outlined;
      case 'maintenance_request':
        return Icons.assignment_outlined;
      case 'alert':
        return Icons.warning_amber_rounded;
      case 'report':
        return Icons.assignment_outlined;
      case 'warranty':
        return Icons.shield_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  static Color _colorForType(String type) {
    switch (type) {
      case 'support_reply':
        return const Color(0xFF2F80ED);
      case 'support_incoming':
        return const Color(0xFFF2994A);
      case 'stage_comment':
        return const Color(0xFFED9B00);
      case 'maintenance':
        return const Color(0xFF3B82F6);
      case 'maintenance_request':
        return const Color(0xFF3B82F6);
      case 'alert':
        return const Color(0xFFF45C5C);
      case 'report':
        return const Color(0xFF3B82F6);
      case 'warranty':
        return const Color(0xFFED9B00);
      default:
        return const Color(0xFFED9B00);
    }
  }

  static String _formatTime(String value) {
    if (value.isEmpty) return '—';
    try {
      final date = DateTime.parse(value).toLocal();
      return formatDateRu(date.toIso8601String());
    } catch (_) {
      return value;
    }
  }
}
