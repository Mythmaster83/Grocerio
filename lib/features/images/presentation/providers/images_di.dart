import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grocer/features/images/data/datasources/pexels_remote_datasource.dart';
import 'package:grocer/features/images/domain/repositories/image_repository.dart';
import '../../../../core/config/env_config.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/proxy_image_remote_datasource.dart';
import '../../data/repositories/image_repository_impl.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final pexelsRemoteDataSourceProvider = Provider<PexelsRemoteDataSource>((ref) {
  return PexelsRemoteDataSource(ref.watch(apiClientProvider));
});

final proxyImageRemoteDataSourceProvider =
    Provider<ProxyImageRemoteDataSource>((ref) {
  return ProxyImageRemoteDataSource(ref.watch(apiClientProvider));
});

final imageRepositoryProvider = Provider<ImageRepository>((ref) {
  final useProxy = EnvConfig.maybeApiBaseUrl() != null;
  return ImageRepositoryImpl(
    pexels: ref.watch(pexelsRemoteDataSourceProvider),
    proxy: ref.watch(proxyImageRemoteDataSourceProvider),
    useProxy: useProxy,
  );
});
