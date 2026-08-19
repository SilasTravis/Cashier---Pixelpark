import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_ce/hive.dart';
import 'package:path_provider/path_provider.dart';

import 'core/local_source/local_source.dart';
import 'core/localization/locale_cubit.dart';
import 'core/network/api_client.dart';
import 'core/network/token_refresher.dart';
import 'core/update/update_checker.dart';
import 'features/auth/data/datasources/auth_remote_data_source.dart';
import 'features/auth/data/repositories/auth_repository_impl.dart';
import 'features/auth/domain/repositories/auth_repository.dart';
import 'features/auth/domain/usecases/login_usecase.dart';
import 'features/auth/presentation/bloc/login_bloc.dart';
import 'features/pos_account/data/pos_account_remote_data_source.dart';
import 'features/inside/data/inside_repository.dart';
import 'features/inside/presentation/bloc/inside_cubit.dart';
import 'features/pos_account/data/pos_account_repository_impl.dart';
import 'features/pos_account/presentation/bloc/pos_account_bloc.dart';
import 'features/pos_sale/data/pos_sale_remote_data_source.dart';
import 'features/pos_sale/data/pos_sale_repository_impl.dart';
import 'features/pos_sale/presentation/bloc/pos_sale_bloc.dart';
import 'features/products/data/products_remote_data_source.dart';
import 'features/products/data/products_repository_impl.dart';
import 'features/products/presentation/bloc/products_bloc.dart';
import 'features/sales_history/data/sales_history_remote_data_source.dart';
import 'features/sales_history/data/sales_history_repository.dart';
import 'features/sales_history/presentation/bloc/sales_history_bloc.dart';
import 'features/shift/data/shift_remote_data_source.dart';
import 'features/shift/data/shift_repository_impl.dart';
import 'features/shift/presentation/bloc/shift_bloc.dart';

final GetIt sl = GetIt.instance;

Future<void> init() async {
  await _initHive();

  sl.registerLazySingleton<TokenRefresher>(() => TokenRefresher(sl()));
  sl.registerLazySingleton<Dio>(() => buildDio(sl(), sl()));

  sl.registerLazySingleton<UpdateChecker>(
    () => UpdateChecker(
      isSafeToApply: () => sl<LocalSource>().getAccessToken() == null,
    ),
  );
  sl.registerFactory<LocaleCubit>(() => LocaleCubit(sl()));

  _authFeature();
  _shiftFeature();
  _productsFeature();
  _posAccountFeature();
  _posSaleFeature();
  _salesHistoryFeature();
  _insideFeature();
}

void _insideFeature() {
  sl.registerFactory<InsideCubit>(() => InsideCubit(sl()));
  sl.registerLazySingleton<InsideRepository>(() => InsideRepository(sl()));
}

void _salesHistoryFeature() {
  sl.registerFactory<SalesHistoryBloc>(() => SalesHistoryBloc(sl(), sl()));
  sl.registerLazySingleton<SalesHistoryRepository>(
    () => SalesHistoryRepository(sl()),
  );
  sl.registerLazySingleton<SalesHistoryRemoteDataSource>(
    () => SalesHistoryRemoteDataSource(sl()),
  );
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

void _productsFeature() {
  sl.registerFactory<ProductsBloc>(() => ProductsBloc(sl()));

  sl.registerLazySingleton<ProductsRepository>(() => ProductsRepository(sl()));

  sl.registerLazySingleton<ProductsRemoteDataSource>(
    () => ProductsRemoteDataSourceImpl(sl()),
  );
}

void _posAccountFeature() {
  sl.registerFactory<PosAccountBloc>(() => PosAccountBloc(sl()));

  sl.registerLazySingleton<PosAccountRepository>(
    () => PosAccountRepository(sl()),
  );

  sl.registerLazySingleton<PosAccountRemoteDataSource>(
    () => PosAccountRemoteDataSourceImpl(sl()),
  );
}

void _posSaleFeature() {
  sl.registerFactory<PosSaleBloc>(() => PosSaleBloc(sl(), sl()));

  sl.registerLazySingleton<PosSaleRepository>(() => PosSaleRepository(sl()));

  sl.registerLazySingleton<PosSaleRemoteDataSource>(
    () => PosSaleRemoteDataSourceImpl(sl()),
  );
}
