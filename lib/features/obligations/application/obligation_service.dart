import '../domain/obligation.dart';
import 'obligation_repository.dart';

class ObligationService {
  const ObligationService({required this.repository});
  final ObligationRepository repository;

  Future<List<Obligation>> list(String userId) => repository.list(userId);
  Future<Obligation> create(Obligation obligation) => repository.create(obligation);
  Future<Obligation> update(Obligation obligation) => repository.update(obligation);
  Future<void> delete(String userId, String obligationId) => repository.delete(userId, obligationId);
  Future<Obligation> setEnabled(String userId, String obligationId, bool enabled) => repository.setEnabled(userId, obligationId, enabled);

  int totalMonthlyObligations(Iterable<Obligation> obligations, {String? currencyCode}) {
    final normalizedCurrency = currencyCode?.trim().toUpperCase();
    return obligations
        .where((obligation) => obligation.enabled)
        .where((obligation) => normalizedCurrency == null || obligation.currencyCode == normalizedCurrency)
        .fold<int>(0, (total, obligation) => total + obligation.normalizedMonthlyAmount);
  }
}
