class MaintenanceRequest {
  const MaintenanceRequest({
    required this.id,
    required this.projectId,
    required this.projectAddress,
    required this.clientUserId,
    required this.taskId,
    required this.systemType,
    required this.description,
    required this.preferredDate,
    required this.specialistName,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String projectId;
  final String projectAddress;
  final String clientUserId;
  final String taskId;
  final String systemType;
  final String description;
  final DateTime? preferredDate;
  final String specialistName;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory MaintenanceRequest.fromJson(Map<String, dynamic> json) {
    return MaintenanceRequest(
      id: (json['id'] ?? '').toString(),
      projectId: (json['projectId'] ?? '').toString(),
      projectAddress: (json['projectAddress'] ?? '').toString(),
      clientUserId: (json['clientUserId'] ?? '').toString(),
      taskId: (json['taskId'] ?? '').toString(),
      systemType: (json['systemType'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      preferredDate: (json['preferredDate'] ?? '').toString().isEmpty
          ? null
          : DateTime.tryParse((json['preferredDate'] ?? '').toString()),
      specialistName: (json['specialistName'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ??
          DateTime.now(),
      updatedAt: DateTime.tryParse((json['updatedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}
