import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';

/// Minimal medication domain model.
///
/// Notification timing stays separate so future medication scheduling can
/// compose this domain with the existing reminder subsystem.
class Medication implements DomainEntity {
  const Medication({
    required this.id,
    required this.name,
    this.dosage,
    this.notes,
    this.isActive = true,
  });

  @override
  final String id;
  final String name;
  final String? dosage;
  final String? notes;
  final bool isActive;
}

/// Repository port for medications.
abstract interface class MedicationRepository
    implements DomainRepository<Medication> {}
