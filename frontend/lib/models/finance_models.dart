import 'package:flutter/material.dart';

enum FinanceCategory {
  construction,
  repair,
  maintenance,
  utilities,
}

extension FinanceCategoryX on FinanceCategory {
  String get label {
    switch (this) {
      case FinanceCategory.construction:
        return 'Строительство';
      case FinanceCategory.repair:
        return 'Ремонт';
      case FinanceCategory.maintenance:
        return 'Обслуживание';
      case FinanceCategory.utilities:
        return 'Коммунальные платежи';
    }
  }

  IconData get icon {
    switch (this) {
      case FinanceCategory.construction:
        return Icons.construction_outlined;
      case FinanceCategory.repair:
        return Icons.home_repair_service_outlined;
      case FinanceCategory.maintenance:
        return Icons.build_outlined;
      case FinanceCategory.utilities:
        return Icons.receipt_long_outlined;
    }
  }

  Color get color {
    switch (this) {
      case FinanceCategory.construction:
        return const Color(0xFFE07A1A);
      case FinanceCategory.repair:
        return const Color(0xFF5B8DEF);
      case FinanceCategory.maintenance:
        return const Color(0xFF2FA56A);
      case FinanceCategory.utilities:
        return const Color(0xFF7B6CF6);
    }
  }

  String get apiValue {
    switch (this) {
      case FinanceCategory.construction:
        return 'construction';
      case FinanceCategory.repair:
        return 'repair';
      case FinanceCategory.maintenance:
        return 'maintenance';
      case FinanceCategory.utilities:
        return 'utilities';
    }
  }

  static FinanceCategory fromApi(String value) {
    switch (value) {
      case 'construction':
        return FinanceCategory.construction;
      case 'repair':
        return FinanceCategory.repair;
      case 'maintenance':
        return FinanceCategory.maintenance;
      case 'utilities':
        return FinanceCategory.utilities;
    }
    return FinanceCategory.construction;
  }
}

class FinanceExpense {
  const FinanceExpense({
    required this.id,
    required this.projectId,
    required this.category,
    required this.amount,
    required this.date,
    required this.note,
    this.createdAt,
  });

  final String id;
  final String projectId;
  final FinanceCategory category;
  final double amount;
  final DateTime date;
  final String note;
  final DateTime? createdAt;

  FinanceExpense copyWith({
    String? id,
    String? projectId,
    FinanceCategory? category,
    double? amount,
    DateTime? date,
    String? note,
    DateTime? createdAt,
  }) {
    return FinanceExpense(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory FinanceExpense.fromJson(Map<String, dynamic> json) {
    final rawDate = (json['date'] ??
            json['expenseDate'] ??
            json['expense_date'] ??
            '')
        .toString();
    final parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    final rawCreated = (json['createdAt'] ?? json['created_at'] ?? '').toString();
    final parsedCreated =
        rawCreated.isEmpty ? null : DateTime.tryParse(rawCreated);
    return FinanceExpense(
      id: (json['id'] ?? '').toString(),
      projectId: (json['projectId'] ?? json['project_id'] ?? '').toString(),
      category: FinanceCategoryX.fromApi(
          (json['category'] ?? '').toString()),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      date: parsedDate,
      note: (json['note'] ?? '').toString(),
      createdAt: parsedCreated,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'projectId': projectId,
      'category': category.apiValue,
      'amount': amount,
      'date': date.toIso8601String().split('T').first,
      'note': note,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    };
  }
}
