enum AppEnvironment {
  development('development'),
  staging('staging'),
  production('production');

  const AppEnvironment(this.value);

  final String value;

  static AppEnvironment fromString(String? raw) {
    return AppEnvironment.values.firstWhere(
      (environment) => environment.value == raw,
      orElse: () => AppEnvironment.development,
    );
  }
}
