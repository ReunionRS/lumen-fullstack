import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api_config.dart';
import '../models/project_models.dart';
import '../models/session_models.dart';
import '../models/notification_models.dart';
import '../models/support_models.dart';
import '../models/user_models.dart';
import '../models/finance_models.dart';
import '../models/maintenance_models.dart';
import '../models/journal_models.dart';
import '../models/maintenance_request_models.dart';
import '../models/system_models.dart';
import 'home_assistant_connection_service.dart';

class AuthService {
  static const _tokenKey = 'auth_token';
  static const _userIdKey = 'user_id';
  static const _rememberEmailKey = 'remember_email';
  static const _userEmailKey = 'user_email';
  static const _userFioKey = 'user_fio';
  static const _userRoleKey = 'user_role';
  static const _userAvatarKey = 'user_avatar';
  final HomeAssistantConnectionService _haConnectionService =
      HomeAssistantConnectionService();

  Future<Map<String, String>> _authHeaders() async {
    final session = await getSession();
    if (session == null) throw const UnauthorizedException();
    return <String, String>{
      'Authorization': 'Bearer ${session.token}',
      'Content-Type': 'application/json',
    };
  }

  Future<String> _token() async {
    final session = await getSession();
    if (session == null) throw const UnauthorizedException();
    return session.token;
  }

  String resolveFileUrl(String storagePath) {
    if (storagePath.isEmpty) return storagePath;
    if (storagePath.startsWith('http://') ||
        storagePath.startsWith('https://')) {
      return storagePath;
    }
    final normalized =
        storagePath.startsWith('/') ? storagePath : '/$storagePath';
    return '${ApiConfig.baseUrl}$normalized';
  }

  Future<AppSession?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    if (token == null || token.isEmpty) return null;
    return AppSession(
      id: prefs.getString(_userIdKey) ?? '',
      token: token,
      email: prefs.getString(_userEmailKey) ?? '',
      fio: prefs.getString(_userFioKey) ?? '',
      role: prefs.getString(_userRoleKey) ?? 'client',
      avatarUrl: prefs.getString(_userAvatarKey) ?? '',
    );
  }

  Future<String> getRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_rememberEmailKey) ?? '';
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userFioKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_userAvatarKey);
  }

  Future<void> saveRememberedEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rememberEmailKey, email);
  }

  Future<void> clearRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rememberEmailKey);
  }

  Future<AppSession> login({
    required String email,
    required String password,
    required bool rememberEmail,
    String? twoFactorCode,
    String? twoFactorPendingToken,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/login');

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
            if (twoFactorCode != null && twoFactorCode.trim().isNotEmpty)
              'twoFactorCode': twoFactorCode.trim(),
            if (twoFactorPendingToken != null &&
                twoFactorPendingToken.trim().isNotEmpty)
              'twoFactorPendingToken': twoFactorPendingToken.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      String message = 'Ошибка входа';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final apiMessage = body['error'];
        if (apiMessage is String && apiMessage.isNotEmpty) {
          message = apiMessage;
        }
      } catch (_) {}
      throw Exception(message);
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final requiresTwoFactor = body['requiresTwoFactor'] == true;
    if (requiresTwoFactor) {
      final pending = (body['twoFactorPendingToken'] ?? '').toString();
      throw TwoFactorRequiredException(
        pendingToken: pending,
        message:
            (body['message'] ?? 'Требуется код из Google Authenticator').toString(),
      );
    }

    final token = body['token'];
    final user = body['user'];
    if (token is! String || token.isEmpty || user is! Map<String, dynamic>) {
      throw Exception('Некорректный ответ сервера');
    }

    final session = AppSession(
      id: (user['id'] ?? user['uid'] ?? '').toString(),
      token: token,
      email: (user['email'] ?? '').toString(),
      fio: (user['fio'] ?? '').toString(),
      role: (user['role'] ?? 'client').toString(),
      avatarUrl: (user['avatarUrl'] ?? '').toString(),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, session.token);
    await prefs.setString(_userIdKey, session.id);
    await prefs.setString(_userEmailKey, session.email);
    await prefs.setString(_userFioKey, session.fio);
    await prefs.setString(_userRoleKey, session.role);
    await prefs.setString(_userAvatarKey, session.avatarUrl);

    if (rememberEmail) {
      await saveRememberedEmail(email);
    } else {
      await clearRememberedEmail();
    }

    return session;
  }

  Future<bool> getTwoFactorStatus() async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/2fa/status');
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception('Не удалось получить статус 2FA');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return body['enabled'] == true;
  }

  Future<Map<String, String>> setupTwoFactor() async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/2fa/setup');
    final response = await http.post(uri, headers: headers, body: '{}');
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception('Не удалось подготовить 2FA');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return {
      'secret': (body['secret'] ?? '').toString(),
      'otpauthUrl': (body['otpauthUrl'] ?? '').toString(),
      'account': (body['account'] ?? '').toString(),
      'issuer': (body['issuer'] ?? '').toString(),
    };
  }

  Future<void> enableTwoFactor({required String code}) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/2fa/enable');
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'code': code}),
    );
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      String message = 'Не удалось включить 2FA';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = (body['error'] ?? message).toString();
      } catch (_) {}
      throw Exception(message);
    }
  }

  Future<void> disableTwoFactor({required String code}) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/auth/2fa/disable');
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({'code': code}),
    );
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      String message = 'Не удалось отключить 2FA';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        message = (body['error'] ?? message).toString();
      } catch (_) {}
      throw Exception(message);
    }
  }

  Future<List<ProjectSummary>> fetchProjects() async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/projects');
    final headers = await _authHeaders();
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200)
      throw Exception('Не удалось загрузить объекты');

    final decoded = jsonDecode(response.body);
    final rawList = switch (decoded) {
      List<dynamic> l => l,
      Map<String, dynamic> m when m['items'] is List<dynamic> =>
        m['items'] as List<dynamic>,
      Map<String, dynamic> m when m['projects'] is List<dynamic> =>
        m['projects'] as List<dynamic>,
      _ => <dynamic>[],
    };

    return rawList
        .whereType<Map<String, dynamic>>()
        .map(ProjectSummary.fromJson)
        .toList(growable: false);
  }

  Future<List<FinanceExpense>> fetchFinanceExpenses({
    required String projectId,
  }) async {
    final headers = await _authHeaders();
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}/api/finances/expenses?projectId=$projectId');
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception('Не удалось загрузить расходы');
    }

    final decoded = jsonDecode(response.body);
    final items = switch (decoded) {
      List<dynamic> l => l,
      Map<String, dynamic> m when m['items'] is List<dynamic> =>
        m['items'] as List<dynamic>,
      Map<String, dynamic> m when m['expenses'] is List<dynamic> =>
        m['expenses'] as List<dynamic>,
      _ => <dynamic>[],
    };

    return items
        .whereType<Map<String, dynamic>>()
        .map(FinanceExpense.fromJson)
        .toList(growable: false);
  }

  Future<FinanceExpense> createFinanceExpense({
    required String projectId,
    required FinanceCategory category,
    required double amount,
    required DateTime date,
    String note = '',
  }) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/finances/expenses');
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'projectId': projectId,
        'category': category.apiValue,
        'amount': amount,
        'date': date.toIso8601String().split('T').first,
        'note': note,
      }),
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 201) {
      String message = 'Не удалось сохранить расход';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final apiMessage = body['error'];
        if (apiMessage is String && apiMessage.isNotEmpty) {
          message = apiMessage;
        }
      } catch (_) {}
      throw Exception(message);
    }

    return FinanceExpense.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteFinanceExpense(String expenseId) async {
    final headers = await _authHeaders();
    final uri =
        Uri.parse('${ApiConfig.baseUrl}/api/finances/expenses/$expenseId');
    final response = await http.delete(uri, headers: headers);

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      String message = 'Не удалось удалить расход';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final apiMessage = body['error'];
        if (apiMessage is String && apiMessage.isNotEmpty) {
          message = apiMessage;
        }
      } catch (_) {}
      throw Exception(message);
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}/api/notifications/$notificationId/read');
    final response = await http.patch(uri, headers: headers);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception('Не удалось отметить уведомление');
    }
  }

  Future<void> markSupportNotificationRead(String messageId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}/api/notifications/support/$messageId/read');
    final response = await http.patch(uri, headers: headers);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception('Не удалось отметить уведомление');
    }
  }

  Future<void> markMaintenanceNotificationRead(String taskId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}/api/notifications/maintenance/$taskId/read');
    final response = await http.patch(uri, headers: headers);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception('Не удалось отметить уведомление');
    }
  }

  Future<void> markMaintenanceRequestNotificationRead(String requestId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse(
        '${ApiConfig.baseUrl}/api/notifications/maintenance-requests/$requestId/read');
    final response = await http.patch(uri, headers: headers);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception('Не удалось отметить уведомление');
    }
  }

  Future<List<MaintenanceTask>> fetchMaintenanceTasks({
    String? projectId,
    String? clientUserId,
  }) async {
    final headers = await _authHeaders();
    final query = <String, String>{};
    if (projectId != null && projectId.isNotEmpty) {
      query['projectId'] = projectId;
    }
    if (clientUserId != null && clientUserId.isNotEmpty) {
      query['clientUserId'] = clientUserId;
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/maintenance/tasks')
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception('Не удалось загрузить обслуживание');
    }

    final decoded = jsonDecode(response.body);
    final items = decoded is List ? decoded : <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(MaintenanceTask.fromJson)
        .toList(growable: false);
  }

  Future<MaintenanceTask> createMaintenanceTask({
    required String projectId,
    required String title,
    required DateTime scheduledDate,
    String notes = '',
    String systemType = '',
  }) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/maintenance/tasks');
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'projectId': projectId,
        'title': title,
        'notes': notes,
        'scheduledDate': scheduledDate.toIso8601String().split('T').first,
        'systemType': systemType,
      }),
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 201) {
      String message = 'Не удалось создать обслуживание';
      try {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        final apiMessage = body['error'];
        if (apiMessage is String && apiMessage.isNotEmpty) {
          message = apiMessage;
        }
      } catch (_) {}
      throw Exception(message);
    }

    return MaintenanceTask.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<MaintenanceTask> updateMaintenanceTask({
    required String taskId,
    String? title,
    String? notes,
    DateTime? scheduledDate,
    MaintenanceStatus? status,
    String? systemType,
    String? specialistName,
    String? reportNotes,
    String? reportPhotoUrl,
  }) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/maintenance/tasks/$taskId');
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (notes != null) payload['notes'] = notes;
    if (scheduledDate != null) {
      payload['scheduledDate'] =
          scheduledDate.toIso8601String().split('T').first;
    }
    if (status != null) payload['status'] = status.apiValue;
    if (systemType != null) payload['systemType'] = systemType;
    if (specialistName != null) payload['specialistName'] = specialistName;
    if (reportNotes != null) payload['reportNotes'] = reportNotes;
    if (reportPhotoUrl != null) payload['reportPhotoUrl'] = reportPhotoUrl;

    final response = await http.patch(
      uri,
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception('Не удалось обновить обслуживание');
    }

    return MaintenanceTask.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteMaintenanceTask(String taskId) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/maintenance/tasks/$taskId');
    final response = await http.delete(uri, headers: headers);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось удалить обслуживание'));
    }
  }

  Future<List<MaintenanceRequest>> fetchMaintenanceRequests({
    String? projectId,
    String? clientUserId,
  }) async {
    final headers = await _authHeaders();
    final query = <String, String>{};
    if (projectId != null && projectId.isNotEmpty) {
      query['projectId'] = projectId;
    }
    if (clientUserId != null && clientUserId.isNotEmpty) {
      query['clientUserId'] = clientUserId;
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/maintenance/requests')
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось загрузить заявки'));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(MaintenanceRequest.fromJson)
        .toList(growable: false);
  }

  Future<MaintenanceRequest> createMaintenanceRequest({
    required String projectId,
    String taskId = '',
    String systemType = '',
    String description = '',
    DateTime? preferredDate,
  }) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/maintenance/requests');
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'projectId': projectId,
        'taskId': taskId,
        'systemType': systemType,
        'description': description,
        'preferredDate': preferredDate?.toIso8601String().split('T').first,
      }),
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 201) {
      throw Exception(
          _extractError(response.body, fallback: 'Не удалось создать заявку'));
    }

    return MaintenanceRequest.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<MaintenanceRequest> updateMaintenanceRequest({
    required String requestId,
    String? status,
    String? specialistName,
    DateTime? preferredDate,
  }) async {
    final headers = await _authHeaders();
    final uri =
        Uri.parse('${ApiConfig.baseUrl}/api/maintenance/requests/$requestId');
    final payload = <String, dynamic>{};
    if (status != null) payload['status'] = status;
    if (specialistName != null) payload['specialistName'] = specialistName;
    if (preferredDate != null) {
      payload['preferredDate'] =
          preferredDate.toIso8601String().split('T').first;
    }
    final response =
        await http.patch(uri, headers: headers, body: jsonEncode(payload));
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(
          _extractError(response.body, fallback: 'Не удалось обновить заявку'));
    }
    return MaintenanceRequest.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<JournalEntry>> fetchJournalEntries({
    required String projectId,
    String? clientUserId,
  }) async {
    final headers = await _authHeaders();
    final query = <String, String>{};
    if (projectId.isNotEmpty) query['projectId'] = projectId;
    if (clientUserId != null && clientUserId.isNotEmpty) {
      query['clientUserId'] = clientUserId;
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/journal/entries')
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось загрузить журнал'));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(JournalEntry.fromJson)
        .toList(growable: false);
  }

  Future<JournalEntry> createJournalEntry({
    required String projectId,
    required JournalEntryType entryType,
    required String description,
    required String specialist,
    required DateTime entryDate,
    String photoUrl = '',
  }) async {
    final headers = await _authHeaders();
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/journal/entries');
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'projectId': projectId,
        'entryType': entryType.apiValue,
        'description': description,
        'specialist': specialist,
        'entryDate': entryDate.toIso8601String().split('T').first,
        'photoUrl': photoUrl,
      }),
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 201) {
      throw Exception(
          _extractError(response.body, fallback: 'Не удалось создать запись'));
    }

    return JournalEntry.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<String> uploadJournalPhoto({required PlatformFile file}) async {
    if (file.bytes == null && file.path == null) {
      throw Exception('Файл не доступен');
    }
    final token = await _token();
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/api/journal/photos'),
    );
    req.headers['Authorization'] = 'Bearer $token';

    if (file.bytes != null) {
      req.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
          contentType: _guessMediaType(file.name),
        ),
      );
    } else if (file.path != null) {
      req.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path!,
          filename: file.name,
          contentType: _guessMediaType(file.name),
        ),
      );
    }

    final streamed = await req.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(
          _extractError(response.body, fallback: 'Не удалось загрузить фото'));
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final storagePath = decoded['storagePath']?.toString() ?? '';
    if (storagePath.isEmpty) {
      throw Exception('Некорректный ответ сервера');
    }
    return storagePath;
  }

  Future<ProjectDetails> fetchProjectById(String projectId) async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/projects/$projectId'),
      headers: headers,
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200)
      throw Exception('Не удалось загрузить объект');

    return ProjectDetails.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ProjectSummary> createProject(Map<String, dynamic> payload) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/projects'),
      headers: headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 201) {
      throw Exception('Не удалось создать объект');
    }
    return ProjectSummary.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> updateProject(
      String projectId, Map<String, dynamic> payload) async {
    final headers = await _authHeaders();
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/projects/$projectId'),
      headers: headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200)
      throw Exception('Не удалось обновить объект');
  }

  Future<void> deleteProject(String projectId) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/projects/$projectId'),
      headers: headers,
    );
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200)
      throw Exception('Не удалось удалить объект');
  }

  Future<String> uploadProjectThumbnail({
    required String projectId,
    required PlatformFile file,
  }) async {
    if (file.bytes == null && file.path == null) {
      throw Exception('Файл не доступен');
    }
    final token = await _token();
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/api/projects/$projectId/thumbnail'),
    );
    req.headers['Authorization'] = 'Bearer $token';
    if (file.bytes != null) {
      req.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
          contentType: _guessMediaType(file.name),
        ),
      );
    } else if (file.path != null) {
      req.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path!,
          filename: file.name,
          contentType: _guessMediaType(file.name),
        ),
      );
    }
    final res = await req.send();
    if (res.statusCode == 401) throw const UnauthorizedException();
    if (res.statusCode != 200) {
      throw Exception('Не удалось загрузить превью');
    }
    final body = await res.stream.bytesToString();
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    return (decoded['thumbnailUrl'] ?? '').toString();
  }

  Future<List<ClientOption>> fetchClients() async {
    final headers = await _authHeaders();
    final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/api/users'),
        headers: headers);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200)
      throw Exception('Не удалось загрузить клиентов');
    final raw = (jsonDecode(response.body) as List<dynamic>)
        .whereType<Map<String, dynamic>>();
    return raw
        .where((u) => (u['role'] ?? '').toString() == 'client')
        .map(
          (u) => ClientOption(
            id: (u['id'] ?? '').toString(),
            fio: (u['fio'] ?? u['email'] ?? 'Клиент').toString(),
            email: (u['email'] ?? '').toString(),
          ),
        )
        .toList(growable: false);
  }

  Future<ProjectDetails> uploadStagePhotos({
    String? projectId,
    required int stageIndex,
    required List<PlatformFile> files,
  }) async {
    if (files.isEmpty) throw Exception('Файлы не выбраны');
    final token = await _token();
    final req = http.MultipartRequest(
      'POST',
      Uri.parse(
          '${ApiConfig.baseUrl}/api/projects/$projectId/stages/$stageIndex/photos'),
    );
    req.headers['Authorization'] = 'Bearer $token';

    for (final file in files) {
      final name = file.name;
      if (file.bytes != null) {
        req.files.add(
          http.MultipartFile.fromBytes(
            'files',
            file.bytes!,
            filename: name,
            contentType: _guessMediaType(name),
          ),
        );
      } else if (file.path != null) {
        req.files.add(
          await http.MultipartFile.fromPath(
            'files',
            file.path!,
            filename: name,
            contentType: _guessMediaType(name),
          ),
        );
      }
    }

    final streamed = await req.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось загрузить фото этапа'));
    }
    return ProjectDetails.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ProjectDetails> deleteStagePhoto({
    required String projectId,
    required int stageIndex,
    required String photoUrl,
  }) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse(
          '${ApiConfig.baseUrl}/api/projects/$projectId/stages/$stageIndex/photos'),
      headers: headers,
      body: jsonEncode({'photoUrl': photoUrl}),
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось удалить фото этапа'));
    }

    return ProjectDetails.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<ProjectDocument>> fetchDocuments(
      {String? projectId, String? clientUserId}) async {
    final headers = await _authHeaders();
    final query = <String, String>{};
    if (projectId != null && projectId.isNotEmpty) {
      query['projectId'] = projectId;
    }
    if (clientUserId != null && clientUserId.isNotEmpty) {
      query['clientUserId'] = clientUserId;
    }
    final uri = Uri.parse(ApiConfig.baseUrl + '/api/documents')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось загрузить документы'));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ProjectDocument.fromJson)
        .toList(growable: false);
  }

  Future<ProjectDocument> uploadProjectDocument({
    String? projectId,
    required String docType,
    required PlatformFile file,
    String? clientUserId,
  }) async {
    final token = await _token();
    final req = http.MultipartRequest(
      'POST',
      Uri.parse(ApiConfig.baseUrl + '/api/documents'),
    );
    req.headers['Authorization'] = 'Bearer ' + token;
    if (projectId != null && projectId.isNotEmpty) {
      req.fields['projectId'] = projectId;
    }
    req.fields['docType'] = docType;
    if (clientUserId != null && clientUserId.isNotEmpty) {
      req.fields['clientUserId'] = clientUserId;
    }

    if (file.bytes != null) {
      req.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: file.name,
          contentType: _guessMediaType(file.name),
        ),
      );
    } else if (file.path != null) {
      req.files.add(
        await http.MultipartFile.fromPath(
          'file',
          file.path!,
          filename: file.name,
          contentType: _guessMediaType(file.name),
        ),
      );
    } else {
      throw Exception('Не удалось прочитать выбранный файл');
    }

    final streamed = await req.send();
    final response = await http.Response.fromStream(streamed);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 201) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось загрузить документ'));
    }

    return ProjectDocument.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteDocument(String documentId) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse(ApiConfig.baseUrl + '/api/documents/' + documentId),
      headers: headers,
    );
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось удалить документ'));
    }
  }

  String documentDownloadUrl(String documentId) {
    return ApiConfig.baseUrl + '/api/documents/' + documentId + '/download';
  }

  Future<String> documentViewUrl(
    String documentId, {
    bool inline = false,
  }) async {
    final token = await _token();
    final base = documentDownloadUrl(documentId);
    final params = <String, String>{'token': token};
    if (inline) params['inline'] = '1';
    final uri = Uri.parse(base).replace(queryParameters: params);
    return uri.toString();
  }

  Future<List<AppNotification>> fetchNotifications() async {
    final headers = await _authHeaders();
    var response = await http.get(
      Uri.parse(ApiConfig.baseUrl + '/api/notifications/feed'),
      headers: headers,
    );
    if (response.statusCode == 404) {
      response = await http.get(
        Uri.parse(ApiConfig.baseUrl + '/api/notifications'),
        headers: headers,
      );
    }

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode == 404) return const <AppNotification>[];
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось загрузить уведомления'));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const <AppNotification>[];

    return decoded
        .whereType<Map<String, dynamic>>()
        .map(AppNotification.fromJson)
        .toList(growable: false);
  }

  Future<void> markAllNotificationsRead() async {
    final headers = await _authHeaders();
    final response = await http.patch(
      Uri.parse(ApiConfig.baseUrl + '/api/notifications/read-all'),
      headers: headers,
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode == 404) return;
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось отметить уведомления'));
    }
  }

  Future<void> clearNotifications() async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse(ApiConfig.baseUrl + '/api/notifications/clear-all'),
      headers: headers,
      body: '{}',
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode == 404) return;
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось очистить уведомления'));
    }
  }

  Future<List<AppUser>> fetchUsers() async {
    final headers = await _authHeaders();
    final response = await http.get(
      Uri.parse('${ApiConfig.baseUrl}/api/users'),
      headers: headers,
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось загрузить пользователей'));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const <AppUser>[];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(AppUser.fromJson)
        .toList(growable: false);
  }

  Future<AppUser> createUser({
    required String fio,
    required String email,
    required String password,
    required String role,
    bool sendWelcomeEmail = true,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/users'),
      headers: headers,
      body: jsonEncode(<String, dynamic>{
        'fio': fio,
        'email': email,
        'password': password,
        'role': role,
        'sendWelcomeEmail': sendWelcomeEmail,
      }),
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 201) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось создать пользователя'));
    }

    return AppUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteUser(String userId) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/users/$userId'),
      headers: headers,
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось удалить пользователя'));
    }
  }

  Future<AppUser> updateUser({
    required String userId,
    String? fio,
    String? email,
    String? role,
    String? password,
  }) async {
    final headers = await _authHeaders();
    final payload = <String, dynamic>{};
    if (fio != null) payload['fio'] = fio;
    if (email != null) payload['email'] = email;
    if (role != null) payload['role'] = role;
    if (password != null && password.isNotEmpty) {
      payload['password'] = password;
    }
    if (payload.isEmpty) {
      throw Exception('Нет изменений для сохранения');
    }

    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/users/$userId'),
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось обновить пользователя'));
    }

    return AppUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<String> uploadAvatar({required PlatformFile file}) async {
    final token = await _token();
    if (file.bytes == null) throw Exception('Файл не доступен');
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${ApiConfig.baseUrl}/api/users/me/avatar'),
    );
    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        file.bytes!,
        filename: file.name,
        contentType: _guessMediaType(file.name),
      ),
    );

    final response = await http.Response.fromStream(await req.send());
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(
          _extractError(response.body, fallback: 'Ошибка загрузки'));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final avatarUrl = (decoded['avatarUrl'] ?? '').toString();
    if (avatarUrl.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userAvatarKey, avatarUrl);
    }
    return avatarUrl;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/users/me/password'),
      headers: headers,
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(
          _extractError(response.body, fallback: 'Ошибка смены пароля'));
    }
  }

  Future<AppUser> updateUserState(
    String userId, {
    bool? isActive,
    bool? isArchived,
  }) async {
    final headers = await _authHeaders();
    final payload = <String, dynamic>{};
    if (isActive != null) payload['isActive'] = isActive;
    if (isArchived != null) payload['isArchived'] = isArchived;
    if (payload.isEmpty) {
      throw Exception('Не переданы изменения состояния');
    }

    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/users/$userId/state'),
      headers: headers,
      body: jsonEncode(payload),
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось обновить состояние сотрудника'));
    }

    return AppUser.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<List<SupportMessage>> fetchSupportMessages(
      {String? clientUserId}) async {
    final headers = await _authHeaders();
    final query = <String, String>{};
    if (clientUserId != null && clientUserId.isNotEmpty) {
      query['clientUserId'] = clientUserId;
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/support/messages')
        .replace(queryParameters: query.isEmpty ? null : query);

    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось загрузить сообщения'));
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return const <SupportMessage>[];
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(SupportMessage.fromJson)
        .toList(growable: false);
  }

  Future<SupportMessage> sendSupportMessage({
    required String messageText,
    String? clientUserId,
  }) async {
    final headers = await _authHeaders();
    final body = <String, dynamic>{
      'messageText': messageText,
    };
    if (clientUserId != null && clientUserId.isNotEmpty) {
      body['clientUserId'] = clientUserId;
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/support/messages'),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 201) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось отправить сообщение'));
    }

    return SupportMessage.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> markSupportChatRead(String clientUserId) async {
    final headers = await _authHeaders();
    final response = await http.patch(
      Uri.parse('${ApiConfig.baseUrl}/api/support/chats/$clientUserId/read'),
      headers: headers,
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось отметить чат как прочитанный'));
    }
  }

  Future<void> deleteSupportChat(String clientUserId) async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/support/chats/$clientUserId'),
      headers: headers,
    );

    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
          _extractError(response.body, fallback: 'Не удалось удалить чат'));
    }
  }

  Future<List<SystemEntity>> fetchSystemStatus({
    String? projectId,
    String? domain,
  }) async {
    final directFromHa =
        await _fetchSystemStatusFromHomeAssistant(domain: domain);
    if (directFromHa != null) {
      return directFromHa;
    }

    final headers = await _authHeaders();
    final query = <String, String>{};
    if (projectId != null && projectId.isNotEmpty) {
      query['projectId'] = projectId;
    }
    if (domain != null && domain.isNotEmpty) {
      query['domain'] = domain;
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}/api/systems/status')
        .replace(queryParameters: query.isEmpty ? null : query);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось загрузить состояния систем'));
    }

    final decoded = jsonDecode(response.body);
    final items = decoded is Map<String, dynamic> && decoded['items'] is List
        ? decoded['items'] as List
        : const <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(SystemEntity.fromJson)
        .toList(growable: false);
  }

  Future<List<SystemEntity>?> _fetchSystemStatusFromHomeAssistant({
    String? domain,
  }) async {
    if (kIsWeb) return null;
    try {
      final session = await getSession();
      if (session == null) return null;

      var connection = await _haConnectionService.getConnection(session.id);
      if (connection == null) return null;
      if (connection.isExpired) {
        final ok = await _haConnectionService.isConnected(session.id);
        if (!ok) return null;
        connection = await _haConnectionService.getConnection(session.id);
        if (connection == null) return null;
      }

      Future<http.Response> requestWithToken(String token) {
        return http.get(
          Uri.parse('${connection!.baseUrl}/api/states'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
      }

      var response = await requestWithToken(connection.accessToken);
      if (response.statusCode == 401) {
        final ok = await _haConnectionService.isConnected(session.id);
        if (!ok) return null;
        connection = await _haConnectionService.getConnection(session.id);
        if (connection == null) return null;
        response = await requestWithToken(connection.accessToken);
      }

      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return null;

      final systems = decoded
          .whereType<Map<String, dynamic>>()
          .map((raw) {
            final entityId = (raw['entity_id'] ?? '').toString();
            final attrs = raw['attributes'] is Map<String, dynamic>
                ? raw['attributes'] as Map<String, dynamic>
                : const <String, dynamic>{};
            final domainValue =
                entityId.contains('.') ? entityId.split('.').first : 'sensor';

            return SystemEntity(
              entityId: entityId,
              domain: domainValue,
              state: (raw['state'] ?? '').toString(),
              friendlyName: (attrs['friendly_name'] ?? entityId).toString(),
              unit: (attrs['unit_of_measurement'] ?? '').toString(),
              deviceClass: (attrs['device_class'] ?? '').toString(),
              icon: (attrs['icon'] ?? '').toString(),
              lastChanged: (raw['last_changed'] ?? '').toString(),
              lastUpdated: (raw['last_updated'] ?? '').toString(),
              attributes: attrs,
            );
          })
          .where((item) => item.entityId.isNotEmpty)
          .where((item) =>
              domain == null || domain.isEmpty || item.domain == domain)
          .toList(growable: false);

      return systems;
    } catch (_) {
      return null;
    }
  }

  Future<List<SystemHistoryPoint>> fetchSystemHistory({
    required String entityId,
    String? projectId,
    int hours = 24,
  }) async {
    final directFromHa = await _fetchSystemHistoryFromHomeAssistant(
      entityId: entityId,
      hours: hours,
    );
    if (directFromHa != null) {
      return directFromHa;
    }

    final headers = await _authHeaders();
    final query = <String, String>{
      'entityId': entityId,
      'hours': '$hours',
    };
    if (projectId != null && projectId.isNotEmpty) {
      query['projectId'] = projectId;
    }
    final uri = Uri.parse('${ApiConfig.baseUrl}/api/systems/history')
        .replace(queryParameters: query);
    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось загрузить историю систем'));
    }

    final decoded = jsonDecode(response.body);
    final items = decoded is Map<String, dynamic> && decoded['items'] is List
        ? decoded['items'] as List
        : const <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(SystemHistoryPoint.fromJson)
        .toList(growable: false);
  }

  Future<List<SystemHistoryPoint>?> _fetchSystemHistoryFromHomeAssistant({
    required String entityId,
    int hours = 24,
  }) async {
    if (kIsWeb) return null;
    try {
      final session = await getSession();
      if (session == null) return null;

      var connection = await _haConnectionService.getConnection(session.id);
      if (connection == null) return null;
      if (connection.isExpired) {
        final ok = await _haConnectionService.isConnected(session.id);
        if (!ok) return null;
        connection = await _haConnectionService.getConnection(session.id);
        if (connection == null) return null;
      }

      final end = DateTime.now().toUtc();
      final start = end.subtract(Duration(hours: hours));
      final startIso = start.toIso8601String();

      Future<http.Response> requestWithToken(String token) {
        return http.get(
          Uri.parse(
            '${connection!.baseUrl}/api/history/period/$startIso',
          ).replace(
            queryParameters: {
              'filter_entity_id': entityId,
              'minimal_response': '1',
              'no_attributes': '1',
            },
          ),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
        );
      }

      var response = await requestWithToken(connection.accessToken);
      if (response.statusCode == 401) {
        final ok = await _haConnectionService.isConnected(session.id);
        if (!ok) return null;
        connection = await _haConnectionService.getConnection(session.id);
        if (connection == null) return null;
        response = await requestWithToken(connection.accessToken);
      }
      if (response.statusCode != 200) return null;

      final decoded = jsonDecode(response.body);
      if (decoded is! List) return null;

      final result = <SystemHistoryPoint>[];
      for (final group in decoded) {
        if (group is! List) continue;
        for (final item in group) {
          if (item is! Map<String, dynamic>) continue;
          final id = (item['entity_id'] ?? '').toString();
          if (id.isEmpty) continue;
          result.add(
            SystemHistoryPoint(
              entityId: id,
              state: (item['state'] ?? '').toString(),
              lastChanged: (item['last_changed'] ?? '').toString(),
              lastUpdated: (item['last_updated'] ?? item['last_changed'] ?? '')
                  .toString(),
            ),
          );
        }
      }

      result.sort((a, b) => a.lastChanged.compareTo(b.lastChanged));
      return result;
    } catch (_) {
      return null;
    }
  }

  Future<void> callSystemService({
    required String domain,
    required String service,
    required Map<String, dynamic> data,
    String? projectId,
  }) async {
    final headers = await _authHeaders();
    final payload = <String, dynamic>{
      'domain': domain,
      'service': service,
      'data': data,
    };
    if (projectId != null && projectId.isNotEmpty) {
      payload['projectId'] = projectId;
    }

    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/systems/service'),
      headers: headers,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(response.body,
          fallback: 'Не удалось выполнить команду системы'));
    }
  }

  Future<void> saveHomeAssistantConnection({
    required String baseUrl,
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
    String houseId = '',
    required String clientId,
  }) async {
    final headers = await _authHeaders();
    final response = await http.post(
      Uri.parse('${ApiConfig.baseUrl}/api/home-assistant/connection'),
      headers: headers,
      body: jsonEncode({
        'baseUrl': baseUrl,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
        'expiresAt': expiresAt.toIso8601String(),
        'houseId': houseId,
        'status': 'connected',
        'clientId': clientId,
      }),
    );
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(
        response.body,
        fallback: 'Не удалось сохранить подключение Home Assistant',
      ));
    }
  }

  Future<void> deleteHomeAssistantConnection() async {
    final headers = await _authHeaders();
    final response = await http.delete(
      Uri.parse('${ApiConfig.baseUrl}/api/home-assistant/connection'),
      headers: headers,
    );
    if (response.statusCode == 401) throw const UnauthorizedException();
    if (response.statusCode != 200) {
      throw Exception(_extractError(
        response.body,
        fallback: 'Не удалось удалить подключение Home Assistant',
      ));
    }
  }

  String _extractError(String body, {required String fallback}) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is String && error.isNotEmpty) return error;
      }
    } catch (_) {}
    return fallback;
  }

  MediaType _guessMediaType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg'))
      return MediaType('image', 'jpeg');
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    if (lower.endsWith('.docx')) {
      return MediaType('application',
          'vnd.openxmlformats-officedocument.wordprocessingml.document');
    }
    if (lower.endsWith('.doc')) return MediaType('application', 'msword');
    return MediaType('application', 'octet-stream');
  }

  Future<void> openExternal(String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw Exception('Не удалось открыть ссылку обновления');
    }
  }
}
