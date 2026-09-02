

class ApiConstants {
  ApiConstants._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const erlangWsUrl = String.fromEnvironment(
    'ERLANG_WS_URL',
    defaultValue: 'wss://npafjhshccbiukyjgfrt.supabase.co/realtime/v1/websocket',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isRealtimeConfigured => erlangWsUrl.isNotEmpty;
}
