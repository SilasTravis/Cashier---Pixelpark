import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'core/local_source/local_source.dart';
import 'core/network/api_client.dart';
import 'core/network/token_refresher.dart';
import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/presentation/bloc/login_bloc.dart';
import 'features/shift/data/shift_remote_data_source.dart';
import 'features/shift/data/shift_repository_impl.dart';
import 'features/shift/presentation/bloc/shift_bloc.dart';

final GetIt sl = GetIt.instance;

Future<void> init() async {
  await _initHive();

  sl.registerLazySingleton<TokenRefresher>(() => TokenRefresher(sl()));
  sl.registerLazySingleton<Dio>(() => buildDio(sl(), sl()));

  _authFeature();
  _shiftFeature();
}

Future<void> _initHive() async {
  final dir = await getApplicationSupportDirectory();
  Hive.init(dir.path);
  final box = await Hive.openBox<dynamic>('cashier_app_box');
  sl.registerSingleton<LocalSource>(LocalSource(box));
}

void _authFeature() {
  sl.registerFactory<LoginBloc>(() => LoginBloc(sl()));

  sl.registerLazySingleton<LoginUseCase>(() => LoginUseCase(sl()));

  sl.registerLazySingleton<AuthRepository>(
    () => AuthRepositoryImpl(sl(), sl()),
  );

  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => AuthRemoteDataSourceImpl(sl()),
  );
}

void _shiftFeature() {
  sl.registerFactory<ShiftBloc>(() => ShiftBloc(sl()));

  sl.registerLazySingleton<ShiftRepository>(() => ShiftRepository(sl()));

  sl.registerLazySingleton<ShiftRemoteDataSource>(
    () => ShiftRemoteDataSourceImpl(sl()),
  );
}
