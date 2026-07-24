import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/config/env_config.dart';
import 'core/di/isar_provider.dart';
import 'core/utils/app_logger.dart';
import 'features/notifications/data/local_notifications_service.dart';
import 'features/notifications/presentation/providers/notifications_di.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail fast on misconfiguration — see env_config.dart for why this must
  // run before anything else touches the network layer.
  try {
    await EnvConfig.load();
  } catch (e, st) {
    logger.error('Startup configuration error', e, st);
    // Release builds must not ship without config. Debug/profile still boot
    // so a missing local `.env` does not block unrelated feature work.
    if (kReleaseMode) {
      rethrow;
    }
  }

  final notifications = LocalNotificationsService();
  await notifications.init();

  final isar = await openAppIsar();

  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
        localNotificationsServiceProvider.overrideWith((ref) => notifications),
      ],
      child: const GrocerApp(),
    ),
  );
}
