import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_service.dart';
import '../application/household_profile_repository.dart';
import '../domain/household_profile.dart';

class SupabaseHouseholdProfileRepository implements HouseholdProfileRepository {
  const SupabaseHouseholdProfileRepository();

  static const _select =
      'country_code,region,currency_code,household_size,adults,children,'
      'housing_type,income_frequency,monthly_income,recurring_debt,'
      'budget_snapshot';

  @override
  Future<HouseholdProfile?> load(String userId) async {
    final client = _clientOrThrow();
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) throw StateError('Authenticated user is required.');

    final row = await client
        .from('household_profiles')
        .select(_select)
        .eq('user_id', cleanUserId)
        .maybeSingle();
    if (row == null) return null;
    return _fromRow(cleanUserId, Map<String, dynamic>.from(row));
  }

  @override
  Future<void> save(HouseholdProfile profile) async {
    final client = _clientOrThrow();
    final payload = {
      'user_id': profile.userId,
      'country_code': profile.countryCode.trim().toUpperCase(),
      'region': (profile.region ?? '').trim().isEmpty
          ? null
          : profile.region!.trim(),
      'currency_code': profile.currencyCode.trim().toUpperCase(),
      'household_size': profile.householdSize,
      'adults': profile.adults,
      'children': profile.children,
      'housing_type': profile.housingType,
      'income_frequency': profile.incomeFrequency,
      'monthly_income': profile.monthlyIncome,
      // Keep the existing schema compatible: Slice 1's initial recurring
      // obligation total is persisted through the established debt column.
      'recurring_debt': profile.recurringObligations,
      'budget_snapshot': {
        'initialRecurringObligations': profile.recurringObligations,
        'source': 'nus_2_slice_1_onboarding',
      },
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await client.from('household_profiles').upsert(payload);
  }

  SupabaseClient _clientOrThrow() {
    final client = SupabaseService.client;
    if (client == null) {
      throw const HouseholdProfileConfigurationException();
    }
    return client;
  }

  HouseholdProfile _fromRow(String userId, Map<String, dynamic> row) {
    final snapshot = row['budget_snapshot'];
    final snapshotMap = snapshot is Map
        ? Map<String, dynamic>.from(snapshot)
        : const <String, dynamic>{};
    final obligation = _readInt(
          row['recurring_debt'],
        ) ??
        _readInt(snapshotMap['initialRecurringObligations']) ??
        0;

    return HouseholdProfile(
      userId: userId,
      countryCode: '${row['country_code'] ?? ''}'.trim().toUpperCase(),
      region: (row['region'] as String?)?.trim(),
      currencyCode: '${row['currency_code'] ?? ''}'.trim().toUpperCase(),
      householdSize: _readInt(row['household_size']) ?? 0,
      adults: _readInt(row['adults']) ?? 0,
      children: _readInt(row['children']) ?? 0,
      housingType: '${row['housing_type'] ?? ''}',
      incomeFrequency: '${row['income_frequency'] ?? ''}',
      monthlyIncome: _readInt(row['monthly_income']) ?? 0,
      recurringObligations: obligation,
    );
  }

  int? _readInt(Object? value) {
    if (value is int) return value;
    return int.tryParse('$value');
  }
}

class HouseholdProfileConfigurationException implements Exception {
  const HouseholdProfileConfigurationException();

  @override
  String toString() =>
      'Supabase household profile storage is not configured for this build.';
}
