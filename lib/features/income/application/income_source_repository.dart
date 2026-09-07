import '../domain/income_source.dart';

abstract interface class IncomeSourceRepository {
  Future<List<IncomeSource>> list(String userId);
  Future<IncomeSource> create(IncomeSource source);
  Future<IncomeSource> update(IncomeSource source);
  Future<void> delete(String userId, String sourceId);
  Future<IncomeSource> setEnabled(String userId, String sourceId, bool enabled);
}
