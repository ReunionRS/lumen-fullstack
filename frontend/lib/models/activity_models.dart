class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.projectId,
    required this.clientUserId,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String createdAt;
  final String projectId;
  final String clientUserId;

  static ActivityItem fromJson(Map<String, dynamic> json) {
    return ActivityItem(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? 'activity').toString(),
      title: (json['title'] ?? 'Активность').toString(),
      body: (json['body'] ?? '').toString(),
      createdAt: (json['createdAt'] ?? '').toString(),
      projectId: (json['projectId'] ?? '').toString(),
      clientUserId: (json['clientUserId'] ?? '').toString(),
    );
  }
}
