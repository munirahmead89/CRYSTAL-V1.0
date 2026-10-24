import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';

/// Single source of truth for the app router.
final routerProvider = Provider<GoRouter>((ref) => createRouter(ref));
