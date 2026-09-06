import '../domain/bill.dart';

/// Controlled application boundary for bill lifecycle mutations.
class BillMutationService {
  const BillMutationService({required this.bills});

  final BillRepository bills;

  Future<Bill> create({
    required String id,
    required String title,
    required int amountMinorUnits,
    required String currencyCode,
    required DateTime dueAt,
  }) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) throw ArgumentError.value(id, 'id');
    if (await bills.getById(cleanId) != null) {
      throw StateError('Bill with this ID already exists.');
    }

    final bill = Bill(
      id: cleanId,
      title: title,
      amountMinorUnits: amountMinorUnits,
      currencyCode: currencyCode,
      dueAt: dueAt,
    );
    await bills.save(bill);
    return bill;
  }

  Future<Bill> update(Bill bill) async {
    if (await bills.getById(bill.id) == null) {
      throw StateError('Cannot update an unknown bill.');
    }
    await bills.save(bill);
    return bill;
  }

  Future<Bill> markPaid(String id) async {
    final existing = await bills.getById(id);
    if (existing == null) throw StateError('Cannot mark an unknown bill as paid.');
    final updated = existing.copyWith(isPaid: true);
    await bills.save(updated);
    return updated;
  }

  Future<Bill> markUnpaid(String id) async {
    final existing = await bills.getById(id);
    if (existing == null) throw StateError('Cannot mark an unknown bill as unpaid.');
    final updated = existing.copyWith(isPaid: false);
    await bills.save(updated);
    return updated;
  }

  Future<void> delete(String id) async {
    await bills.deleteById(id);
  }
}
