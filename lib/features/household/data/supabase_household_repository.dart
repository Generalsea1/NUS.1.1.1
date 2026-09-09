import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_service.dart';
import '../application/household_repository.dart';
import '../domain/household.dart';

class SupabaseHouseholdRepository implements HouseholdRepository {
  const SupabaseHouseholdRepository();

  SupabaseClient _client() {
    final client = SupabaseService.client;
    if (client == null) {
      throw const HouseholdConfigurationException();
    }
    return client;
  }

  @override
  Future<Household> create({required String ownerUserId, required String name}) async {
    final cleanUserId = ownerUserId.trim();
    final cleanName = name.trim();
    if (cleanUserId.isEmpty) {
      throw ArgumentError.value(ownerUserId, 'ownerUserId', 'Owner user ID is required.');
    }
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Household name is required.');
    }
    _requireCurrentUser(cleanUserId);

    final row = await _client()
        .from('households')
        .insert(<String, dynamic>{
          'owner_user_id': cleanUserId,
          'name': cleanName,
        })
        .select('id,owner_user_id,name')
        .single();

    return _householdFromRow(Map<String, dynamic>.from(row));
  }

  @override
  Future<Household?> getById(String householdId) async {
    final clean = householdId.trim();
    if (clean.isEmpty) {
      throw ArgumentError.value(householdId, 'householdId', 'Household ID is required.');
    }
    final row = await _client()
        .from('households')
        .select('id,owner_user_id,name')
        .eq('id', clean)
        .maybeSingle();
    return row == null ? null : _householdFromRow(Map<String, dynamic>.from(row));
  }

  @override
  Future<List<HouseholdMember>> listMemberships(String userId) async {
    final cleanUserId = userId.trim();
    if (cleanUserId.isEmpty) {
      throw ArgumentError.value(userId, 'userId', 'User ID is required.');
    }
    _requireCurrentUser(cleanUserId);

    final rows = await _client()
        .from('household_members')
        .select('household_id,user_id,role,status')
        .eq('user_id', cleanUserId)
        .order('created_at', ascending: true);

    return rows
        .map((row) => HouseholdMember.fromJson(<String, dynamic>{
              'householdId': row['household_id'],
              'userId': row['user_id'],
              'role': row['role'],
              'status': row['status'],
            }))
        .toList(growable: false);
  }

  @override
  Future<List<HouseholdMember>> listHouseholdMembers(String householdId) async {
    final cleanHouseholdId = householdId.trim();
    if (cleanHouseholdId.isEmpty) {
      throw ArgumentError.value(householdId, 'householdId', 'Household ID is required.');
    }

    final rows = await _client()
        .from('household_members')
        .select('household_id,user_id,role,status')
        .eq('household_id', cleanHouseholdId)
        .eq('status', 'active')
        .order('created_at', ascending: true);

    return rows
        .map((row) => HouseholdMember.fromJson(<String, dynamic>{
              'householdId': row['household_id'],
              'userId': row['user_id'],
              'role': row['role'],
              'status': row['status'],
            }))
        .toList(growable: false);
  }

  @override
  Future<HouseholdMember> addMembership(HouseholdMember member) async {
    if (member.userId.trim().isEmpty || member.householdId.trim().isEmpty) {
      throw ArgumentError('Household membership requires householdId and userId.');
    }
    _requireCurrentUser(member.userId);
    if (member.role != 'member') {
      throw ArgumentError.value(member.role, 'role', 'Self-service membership may only create member role.');
    }
    if (member.status != 'active') {
      throw ArgumentError.value(member.status, 'status', 'Self-service membership may only activate a member.');
    }

    final row = await _client()
        .from('household_members')
        .insert(<String, dynamic>{
          'household_id': member.householdId,
          'user_id': member.userId,
          'role': member.role,
          'status': member.status,
        })
        .select('household_id,user_id,role,status')
        .single();

    return HouseholdMember.fromJson(<String, dynamic>{
      'householdId': row['household_id'],
      'userId': row['user_id'],
      'role': row['role'],
      'status': row['status'],
    });
  }

  void _requireCurrentUser(String userId) {
    final current = SupabaseService.client?.auth.currentUser?.id.trim();
    if (current == null || current.isEmpty || current != userId) {
      throw StateError('Authenticated user does not match the requested household operation.');
    }
  }

  Household _householdFromRow(Map<String, dynamic> row) => Household.fromJson(<String, dynamic>{
        'id': row['id'],
        'ownerUserId': row['owner_user_id'],
        'name': row['name'],
      });
}

class HouseholdConfigurationException implements Exception {
  const HouseholdConfigurationException();

  @override
  String toString() => 'Supabase household storage is not configured for this build.';
}
