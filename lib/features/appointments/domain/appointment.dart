import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';

/// Minimal appointment domain model.
///
/// Doctor visits are represented as appointments at this architectural stage;
/// richer clinical/contact concepts remain deferred until required.
class Appointment implements DomainEntity {
  const Appointment({
    required this.id,
    required this.title,
    required this.startsAt,
    this.endsAt,
    this.location,
  });

  @override
  final String id;
  final String title;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? location;
}

/// Repository port for appointments.
abstract interface class AppointmentRepository
    implements DomainRepository<Appointment> {}
