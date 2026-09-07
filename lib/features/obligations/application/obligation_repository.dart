import '../domain/obligation.dart';

abstract interface class ObligationRepository {
  Future<List<Obligation>> list(String userId);
  Future<Obligation> create(Obligation obligation);
  Future<Obligation> update(Obligation obligation);
  Future<void> delete(String userId, String obligationId);
  Future<Obligation> setEnabled(String userId, String obligationId, bool enabled);
}
