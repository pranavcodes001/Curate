class AuthToken {
  final String accessToken;
  final String tokenType;
  final String? refreshToken;

  const AuthToken({
    required this.accessToken,
    required this.tokenType,
    this.refreshToken,
  });
}
