import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';

/// Minimal note domain model.
class Note implements DomainEntity {
  const Note({
    required this.id,
    required this.title,
    required this.body,
    required this.updatedAt,
  });

  @override
  final String id;
  final String title;
  final String body;
  final DateTime updatedAt;
}

/// Repository port for notes.
abstract interface class NoteRepository implements DomainRepository<Note> {}
