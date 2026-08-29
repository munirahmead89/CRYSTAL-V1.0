import 'package:flutter/foundation.dart';

class ApiConstants {
  ApiConstants._();

  static const _env = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://npafjhshccbiukyjgfrt.supabase.co',
  );
  static const _anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_Mm48hrAwAe7qI4-tQKrNGg_KXPWw0CR',
  );
  static const _wsUrl = String.fromEnvironment(
    'ERLANG_WS_URL',
    defaultValue: 'wss://npafjhshccbiukyjgfrt.supabase.co/realtime/v1/websocket',
  );

  static String get supabaseUrl => _env;
  static String get supabaseAnonKey => _anonKey;
  static String get erlangWsUrl => _wsUrl;

  static bool get isConfigured =>
      _env.isNotEmpty && _anonKey.isNotEmpty;

  static bool get isRealtimeConfigured => _wsUrl.isNotEmpty;
}
