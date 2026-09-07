import '../domain/income_source.dart';
import 'income_source_repository.dart';

class IncomeSourceService {
  const IncomeSourceService({required this.repository});

  final IncomeSourceRepository repository;

  Future<List<IncomeSource>> list(String userId) => repository.list(userId);

  Future<IncomeSource> create(IncomeSource source) => repository.create(source);

  Future<IncomeSource> update(IncomeSource source) => repository.update(source);

  Future<void> delete(String userId, String sourceId) => repository.delete(userId, sourceId);

  Future<IncomeSource> setEnabled(String userId, String sourceId, bool enabled) =>
      repository.setEnabled(userId, sourceId, enabled);

  int totalMonthlyIncome(Iterable<IncomeSource> sources, {String? currencyCode}) {
    final normalizedCurrency = currencyCode?.trim().toUpperCase();
    final enabledSources = sources
        .where((source) => source.enabled)
        .where((source) => normalizedCurrency == null || source.currencyCode == normalizedCurrency);
    final hasEnabledRealSource = enabledSources.any((source) => source.sourceType != 'legacy');

    return enabledSources
        .where((source) => source.sourceType != 'legacy' || !hasEnabledRealSource)
        .fold<int>(0, (total, source) => total + source.normalizedMonthlyAmount);
  }
}
