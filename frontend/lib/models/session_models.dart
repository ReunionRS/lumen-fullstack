class AppSession {
  const AppSession({
    required this.id,
    required this.token,
    required this.email,
    required this.fio,
    required this.role,
    required this.avatarUrl,
  });

  final String id;
  final String token;
  final String email;
  final String fio;
  final String role;
  final String avatarUrl;
}

class UnauthorizedException implements Exception {
  const UnauthorizedException();
}

class TwoFactorRequiredException implements Exception {
  const TwoFactorRequiredException({
    required this.pendingToken,
    required this.message,
  });

  final String pendingToken;
  final String message;
}

class ClientOption {
  const ClientOption({
    required this.id,
    required this.fio,
    required this.email,
  });

  final String id;
  final String fio;
  final String email;
}
