import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';

/// Supported Phase 7.3 financial account types.
enum AccountType {
  bank,
  wallet,
  cash,
}

/// Aggregate root representing a user's source or destination of money.
///
/// The account owns identity and opening state only. Transaction history is
/// intentionally stored separately and references [id].
class Account implements DomainEntity {
  factory Account({
    required String id,
    required String name,
    required AccountType type,
    required String currencyCode,
    required int openingBalanceMinorUnits,
    bool isArchived = false,
  }) {
    final cleanId = id.trim();
    final cleanName = name.trim();
    final normalizedCurrency = currencyCode.trim().toUpperCase();

    if (cleanId.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Account ID must not be empty.');
    }
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Account name must not be empty.');
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(normalizedCurrency)) {
      throw ArgumentError.value(
        currencyCode,
        'currencyCode',
        'Currency code must be exactly three alphabetic characters.',
      );
    }

    return Account._(
      id: cleanId,
      name: cleanName,
      type: type,
      currencyCode: normalizedCurrency,
      openingBalanceMinorUnits: openingBalanceMinorUnits,
      isArchived: isArchived,
    );
  }

  const Account._({
    required this.id,
    required this.name,
    required this.type,
    required this.currencyCode,
    required this.openingBalanceMinorUnits,
    required this.isArchived,
  });

  @override
  final String id;
  final String name;
  final AccountType type;
  final String currencyCode;
  final int openingBalanceMinorUnits;
  final bool isArchived;

  Account copyWith({
    String? id,
    String? name,
    AccountType? type,
    String? currencyCode,
    int? openingBalanceMinorUnits,
    bool? isArchived,
  }) => Account(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        currencyCode: currencyCode ?? this.currencyCode,
        openingBalanceMinorUnits:
            openingBalanceMinorUnits ?? this.openingBalanceMinorUnits,
        isArchived: isArchived ?? this.isArchived,
      );

  Account archive() => copyWith(isArchived: true);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'type': type.name,
        'currencyCode': currencyCode,
        'openingBalanceMinorUnits': openingBalanceMinorUnits,
        'isArchived': isArchived,
      };

  factory Account.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final type = json['type'];
    final currencyCode = json['currencyCode'];
    final openingBalanceMinorUnits = json['openingBalanceMinorUnits'];
    final isArchived = json['isArchived'];

    if (id is! String) {
      throw const FormatException('Account id must be a string.');
    }
    if (name is! String) {
      throw const FormatException('Account name must be a string.');
    }
    if (type is! String) {
      throw const FormatException('Account type must be a string.');
    }
    if (currencyCode is! String) {
      throw const FormatException('Account currencyCode must be a string.');
    }
    if (openingBalanceMinorUnits is! int) {
      throw const FormatException(
        'Account openingBalanceMinorUnits must be an integer.',
      );
    }
    if (isArchived is! bool) {
      throw const FormatException('Account isArchived must be a boolean.');
    }

    final accountType = switch (type.trim().toLowerCase()) {
      'bank' => AccountType.bank,
      'wallet' => AccountType.wallet,
      'cash' => AccountType.cash,
      _ => throw const FormatException('Account type is unsupported.'),
    };

    try {
      return Account(
        id: id,
        name: name,
        type: accountType,
        currencyCode: currencyCode,
        openingBalanceMinorUnits: openingBalanceMinorUnits,
        isArchived: isArchived,
      );
    } on ArgumentError catch (error) {
      throw FormatException(error.message.toString());
    }
  }

  @override
  bool operator ==(Object other) =>
      other is Account &&
      other.id == id &&
      other.name == name &&
      other.type == type &&
      other.currencyCode == currencyCode &&
      other.openingBalanceMinorUnits == openingBalanceMinorUnits &&
      other.isArchived == isArchived;

  @override
  int get hashCode => Object.hash(
        id,
        name,
        type,
        currencyCode,
        openingBalanceMinorUnits,
        isArchived,
      );
}

/// Repository boundary for [Account] aggregates.
abstract interface class AccountRepository
    implements DomainRepository<Account> {
  Future<void> archiveById(String id);
}
