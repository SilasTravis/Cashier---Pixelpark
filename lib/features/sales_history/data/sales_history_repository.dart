import '../../../core/error/exceptions.dart';
import '../domain/sale_history.dart';
import 'sales_history_remote_data_source.dart';

class SalesHistoryRepository {
  SalesHistoryRepository(this.remote);
  final SalesHistoryRemoteDataSource remote;

  Future<(SalesHistoryPageData, SalesHistorySummary)> load({
    required SaleHistoryPeriod period,
    required int page,
  }) async {
    return (
      await remote.list(period: period, page: page),
      await remote.summary(period),
    );
  }

  String errorMessage(Object error) => switch (error) {
    ServerException(:final message) => message,
    _ => "Sotuv tarixini yuklab bo‘lmadi",
  };
}
