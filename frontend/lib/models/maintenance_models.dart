import 'package:flutter/material.dart';

enum MaintenanceStatus {
  scheduled,
  completed,
  cancelled,
}

extension MaintenanceStatusX on MaintenanceStatus {
  String get label {
    switch (this) {
      case MaintenanceStatus.scheduled:
        return 'Запланировано';
      case MaintenanceStatus.completed:
        return 'Выполнено';
      case MaintenanceStatus.cancelled:
        return 'Отменено';
    }
  }

  String get apiValue {
    switch (this) {
      case MaintenanceStatus.scheduled:
        return 'scheduled';
      case MaintenanceStatus.completed:
        return 'completed';
      case MaintenanceStatus.cancelled:
        return 'cancelled';
    }
  }

  Color get color {
    switch (this) {
      case MaintenanceStatus.scheduled:
        return const Color(0xFFF2A31A);
      case MaintenanceStatus.completed:
        return const Color(0xFF2FA56A);
      case MaintenanceStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }

  static MaintenanceStatus fromApi(String value) {
    switch (value) {
      case 'completed':
        return MaintenanceStatus.completed;
      case 'cancelled':
        return MaintenanceStatus.cancelled;
      case 'scheduled':
      default:
        return MaintenanceStatus.scheduled;
    }
  }
}

class MaintenanceTask {
  const MaintenanceTask({
    required this.id,
    required this.projectId,
    required this.projectAddress,
    required this.clientUserId,
    required this.title,
    required this.notes,
    required this.scheduledDate,
    required this.status,
    required this.createdAt,
    required this.systemType,
    required this.specialistName,
    required this.reportNotes,
    required this.reportPhotoUrl,
    this.completedAt,
  });

  final String id;
  final String projectId;
  final String projectAddress;
  final String clientUserId;
  final String title;
  final String notes;
  final DateTime scheduledDate;
  final MaintenanceStatus status;
  final DateTime createdAt;
  final String systemType;
  final String specialistName;
  final String reportNotes;
  final String reportPhotoUrl;
  final DateTime? completedAt;

  factory MaintenanceTask.fromJson(Map<String, dynamic> json) {
    return MaintenanceTask(
      id: (json['id'] ?? '').toString(),
      projectId: (json['projectId'] ?? '').toString(),
      projectAddress: (json['projectAddress'] ?? '').toString(),
      clientUserId: (json['clientUserId'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      notes: (json['notes'] ?? '').toString(),
      scheduledDate: DateTime.tryParse((json['scheduledDate'] ?? '').toString()) ??
          DateTime.now(),
      status: MaintenanceStatusX.fromApi((json['status'] ?? '').toString()),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      systemType: (json['systemType'] ?? '').toString(),
      specialistName: (json['specialistName'] ?? '').toString(),
      reportNotes: (json['reportNotes'] ?? '').toString(),
      reportPhotoUrl: (json['reportPhotoUrl'] ?? '').toString(),
      completedAt: (json['completedAt'] ?? '').toString().isEmpty
          ? null
          : DateTime.tryParse((json['completedAt'] ?? '').toString()),
    );
  }
}
