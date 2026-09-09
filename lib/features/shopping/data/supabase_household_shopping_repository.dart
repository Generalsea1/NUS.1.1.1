import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_service.dart';
import '../domain/shopping_item.dart';
import '../domain/shopping_list.dart';

/// Supabase-backed ShoppingList aggregate scoped to the authenticated user's
/// current household. The repository never accepts an arbitrary owner id.
class SupabaseHouseholdShoppingRepository implements ShoppingRepository {
  const SupabaseHouseholdShoppingRepository({required this.householdId});

  final String householdId;

  SupabaseClient _client() {
    final client = SupabaseService.client;
    if (client == null) {
      throw const ShoppingConfigurationException();
    }
    return client;
  }

  String _requireHouseholdId() {
    final clean = householdId.trim();
    if (clean.isEmpty) {
      throw ArgumentError.value(householdId, 'householdId', 'Household ID is required.');
    }
    return clean;
  }

  String _requireUserId() {
    final userId = SupabaseService.client?.auth.currentUser?.id.trim();
    if (userId == null || userId.isEmpty) {
      throw StateError('An authenticated user is required for household shopping.');
    }
    return userId;
  }

  @override
  Future<ShoppingList?> getById(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Shopping list ID is required.');
    }

    final row = await _client()
        .from('household_shopping_lists')
        .select('id,name,household_id')
        .eq('id', cleanId)
        .eq('household_id', _requireHouseholdId())
        .maybeSingle();
    if (row == null) return null;

    final items = await _itemsForList(cleanId);
    return ShoppingList(
      id: row['id'].toString(),
      name: row['name'].toString(),
      items: items,
    );
  }

  @override
  Future<List<ShoppingList>> list() async {
    final rows = await _client()
        .from('household_shopping_lists')
        .select('id,name,household_id')
        .eq('household_id', _requireHouseholdId())
        .order('updated_at', ascending: false)
        .order('id', ascending: true);

    if (rows.isEmpty) return const <ShoppingList>[];

    final ids = rows.map((row) => row['id'].toString()).toList(growable: false);
    final itemRows = await _client()
        .from('household_shopping_items')
        .select('id,shopping_list_id,name,quantity,is_completed')
        .inFilter('shopping_list_id', ids)
        .order('created_at', ascending: true);

    final grouped = <String, List<ShoppingItem>>{};
    for (final row in itemRows) {
      final listId = row['shopping_list_id'].toString();
      (grouped[listId] ??= <ShoppingItem>[]).add(_itemFromRow(row));
    }

    return rows
        .map(
          (row) => ShoppingList(
            id: row['id'].toString(),
            name: row['name'].toString(),
            items: grouped[row['id'].toString()] ?? const <ShoppingItem>[],
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> save(ShoppingList entity) async {
    final listId = entity.id.trim();
    if (listId.isEmpty) {
      throw ArgumentError.value(entity.id, 'id', 'Shopping list ID is required.');
    }
    final household = _requireHouseholdId();
    final currentUser = _requireUserId();
    final client = _client();

    final existingList = await client
        .from('household_shopping_lists')
        .select('created_by')
        .eq('id', listId)
        .eq('household_id', household)
        .maybeSingle();
    final createdBy = existingList?['created_by']?.toString() ?? currentUser;

    await client.from('household_shopping_lists').upsert(
      <String, dynamic>{
        'id': listId,
        'household_id': household,
        'name': entity.name.trim(),
        'created_by': createdBy,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'id',
    );

    final existingRows = await client
        .from('household_shopping_items')
        .select('id')
        .eq('shopping_list_id', listId);
    final existingIds = existingRows.map((row) => row['id'].toString()).toSet();
    final incomingIds = entity.items.map((item) => item.id.trim()).toSet();
    final removedIds = existingIds.difference(incomingIds).toList(growable: false);
    if (removedIds.isNotEmpty) {
      await client
          .from('household_shopping_items')
          .delete()
          .eq('shopping_list_id', listId)
          .inFilter('id', removedIds);
    }

    if (entity.items.isEmpty) return;

    await client.from('household_shopping_items').upsert(
      entity.items
          .map(
            (item) => <String, dynamic>{
              'id': item.id.trim(),
              'shopping_list_id': listId,
              'name': item.name.trim(),
              'quantity': item.quantity,
              'is_completed': item.isCompleted,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
          )
          .toList(growable: false),
      onConflict: 'id',
    );
  }

  @override
  Future<void> deleteById(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) {
      throw ArgumentError.value(id, 'id', 'Shopping list ID is required.');
    }
    await _client()
        .from('household_shopping_lists')
        .delete()
        .eq('id', cleanId)
        .eq('household_id', _requireHouseholdId());
  }

  Future<List<ShoppingItem>> _itemsForList(String listId) async {
    final rows = await _client()
        .from('household_shopping_items')
        .select('id,shopping_list_id,name,quantity,is_completed')
        .eq('shopping_list_id', listId)
        .order('created_at', ascending: true);
    return rows.map(_itemFromRow).toList(growable: false);
  }

  ShoppingItem _itemFromRow(Map<String, dynamic> row) => ShoppingItem(
        id: row['id'].toString(),
        name: row['name'].toString(),
        quantity: row['quantity'] as String?,
        isCompleted: row['is_completed'] == true,
      );
}

class ShoppingConfigurationException implements Exception {
  const ShoppingConfigurationException();

  @override
  String toString() => 'Supabase household shopping storage is not configured for this build.';
}
