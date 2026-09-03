/// Minimal domain entity contract shared by future feature models.
///
/// This contract deliberately contains only stable identity. Domain-specific
/// lifecycle, validation, and persistence rules belong to each feature.
abstract interface class DomainEntity {
  String get id;
}
