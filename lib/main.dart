import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/config/env_config.dart';
import 'core/di/isar_provider.dart';
import 'core/utils/app_logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail fast on misconfiguration — see env_config.dart for why this must
  // run before anything else touches the network layer.
  try {
    await EnvConfig.load();
  } catch (e, st) {
    logger.error('Startup configuration error', e, st);
    // In an MVP we still boot the app (image search will simply fail
    // gracefully via ApiClient's error mapping) so a missing dev API key
    // doesn't block working on unrelated features. Flip this to `rethrow`
    // before shipping a release build.
  }

  final isar = await openAppIsar();

  runApp(
    ProviderScope(
      overrides: [isarProvider.overrideWithValue(isar)],
      child: const GrocerApp(),
    ),
  );
}
