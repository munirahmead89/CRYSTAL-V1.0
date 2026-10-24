import 'environment.dart';

/// Immutable application configuration resolved from `--dart-define` values.
///
/// Supported keys:
///   APP_ENV             development | staging | production
///   APP_NAME            display name of the application
///   APP_CONFIG_URL      HTTPS url of the secure config endpoint (production).
///                       When set, Supabase url + anon key are fetched at
///                       runtime and cached — NOT compiled into the APK.
///   SUPABASE_URL        project URL for Supabase (dev/staging fallback only)
///   SUPABASE_ANON_KEY   public anon key for Supabase (dev/staging fallback)
///   APP_LOG_VERBOSITY   off | fatal | error | warning | info | debug | trace
///
/// Security: no Supabase credentials are stored in source. Production builds
/// must provide `APP_CONFIG_URL`; the credentials themselves live server-side
/// in a Supabase Edge Function and are delivered over HTTPS at startup.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.appName,
    required this.apiBaseUrl,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.logVerbosity,
    this.appConfigUrl = '',
  });

  final AppEnvironment environment;
  final String appName;
  final String apiBaseUrl;

  /// Dev/staging fallback values, empty in production builds. Prefer the
  /// remote secure config ([appConfigUrl]) for anything that ships.
  final String supabaseUrl;
  final String supabaseAnonKey;

  /// Optional HTTPS endpoint returning `{ "url": …, "anonKey": … }`.
  /// Secrets are fetched at runtime and never baked into the binary.
  final String appConfigUrl;

  final String logVerbosity;

  factory AppConfig.fromEnvironment() {
    final environment = AppEnvironment.fromString(
      String.fromEnvironment('APP_ENV'),
    );
    const appName = String.fromEnvironment(
      'APP_NAME',
      defaultValue: 'Crystal Messenger',
    );
    const apiBaseUrl = String.fromEnvironment('APP_API_BASE_URL');
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const appConfigUrl = String.fromEnvironment('APP_CONFIG_URL');
    const logVerbosity = String.fromEnvironment(
      'APP_LOG_VERBOSITY',
      defaultValue: 'debug',
    );

    return AppConfig(
      environment: environment,
      appName: appName,
      apiBaseUrl: apiBaseUrl,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      appConfigUrl: appConfigUrl,
      logVerbosity: logVerbosity,
    );
  }

  /// Whether the app has any usable Supabase config (points to a live origin).
  bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  bool get isProduction => environment == AppEnvironment.production;
}
