import 'package:flutter/material.dart';

enum JournalEntryType {
  repair,
  breakdown,
  maintenance,
  modernization,
}

extension JournalEntryTypeX on JournalEntryType {
  String get label {
    switch (this) {
      case JournalEntryType.repair:
        return 'Ремонт';
      case JournalEntryType.breakdown:
        return 'Поломки';
      case JournalEntryType.maintenance:
        return 'Обслуживание';
      case JournalEntryType.modernization:
        return 'Модернизация';
    }
  }

  String get apiValue {
    switch (this) {
      case JournalEntryType.repair:
        return 'repair';
      case JournalEntryType.breakdown:
        return 'breakdown';
      case JournalEntryType.maintenance:
        return 'maintenance';
      case JournalEntryType.modernization:
        return 'modernization';
    }
  }

  Color get color {
    switch (this) {
      case JournalEntryType.repair:
        return const Color(0xFFF59E0B);
      case JournalEntryType.breakdown:
        return const Color(0xFFEF4444);
      case JournalEntryType.maintenance:
        return const Color(0xFF2FA56A);
      case JournalEntryType.modernization:
        return const Color(0xFF3B82F6);
    }
  }

  static JournalEntryType fromApi(String value) {
    switch (value) {
      case 'breakdown':
        return JournalEntryType.breakdown;
      case 'maintenance':
        return JournalEntryType.maintenance;
      case 'modernization':
        return JournalEntryType.modernization;
      case 'repair':
      default:
        return JournalEntryType.repair;
    }
  }
}

class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.projectId,
    required this.projectAddress,
    required this.clientUserId,
    required this.entryType,
    required this.description,
    required this.specialist,
    required this.entryDate,
    required this.photoUrl,
    required this.createdAt,
  });

  final String id;
  final String projectId;
  final String projectAddress;
  final String clientUserId;
  final JournalEntryType entryType;
  final String description;
  final String specialist;
  final DateTime entryDate;
  final String photoUrl;
  final DateTime createdAt;

  factory JournalEntry.fromJson(Map<String, dynamic> json) {
    return JournalEntry(
      id: (json['id'] ?? '').toString(),
      projectId: (json['projectId'] ?? '').toString(),
      projectAddress: (json['projectAddress'] ?? '').toString(),
      clientUserId: (json['clientUserId'] ?? '').toString(),
      entryType: JournalEntryTypeX.fromApi((json['entryType'] ?? '').toString()),
      description: (json['description'] ?? '').toString(),
      specialist: (json['specialist'] ?? '').toString(),
      entryDate: DateTime.tryParse((json['entryDate'] ?? '').toString()) ??
          DateTime.now(),
      photoUrl: (json['photoUrl'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
