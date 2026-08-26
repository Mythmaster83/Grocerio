import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/account/data/auth_service.dart';
import 'app.dart';
import 'core/backend/supabase_config.dart';
import 'core/di/isar_provider.dart';
import 'features/catalog/data/datasources/catalog_local_datasource.dart';
import 'features/catalog/data/services/catalog_seed_service.dart';
import 'features/notifications/data/local_notifications_service.dart';
import 'features/notifications/presentation/providers/notifications_di.dart';
import 'features/preferences/data/datasources/preferences_local_datasource.dart';
import 'features/stores/data/datasources/stores_local_datasource.dart';

/// Local-first startup: Isar and notifications are set up unconditionally, and
/// the backend only if this build was given credentials. Every network feature
/// checks for that, so an unconfigured build behaves exactly like the offline
/// version of the app.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Before runApp so a returning session is restored by the time the first
  // frame builds; it fails soft when unconfigured or unreachable.
  await SupabaseConfig.initialize();
  // Mirror restored JWT session into the on-device "logged in" flag.
  await AuthService(SupabaseConfig.clientOrNull).syncDeviceLoginFlag();

  final notifications = LocalNotificationsService();
  await notifications.init();

  final isar = await openAppIsar();

  // Awaited rather than fired off in the background: the catalog is what item
  // names resolve against, and an item added in the first second of a fresh
  // install would otherwise silently resolve to nothing and never get a price.
  await CatalogSeedService(
    catalog: CatalogLocalDataSource(isar),
    stores: StoresLocalDataSource(isar),
    preferences: PreferencesLocalDataSource(isar),
    bundle: rootBundle,
  ).seedIfNeeded();

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
