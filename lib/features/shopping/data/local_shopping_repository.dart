import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/shopping_list.dart';

/// SharedPreferences-backed local repository for ShoppingList aggregates.
class LocalShoppingRepository implements ShoppingRepository {
  LocalShoppingRepository({SharedPreferences? preferences})
      : _preferences = preferences;

  static const storageKey = 'nus.shopping.v1';
  final SharedPreferences? _preferences;

  Future<SharedPreferences> get _prefs async =>
      _preferences ?? SharedPreferences.getInstance();

  @override
  Future<ShoppingList?> getById(String id) async {
    final lists = await list();
    for (final shoppingList in lists) {
      if (shoppingList.id == id) return shoppingList;
    }
    return null;
  }

  @override
  Future<List<ShoppingList>> list() async {
    final prefs = await _prefs;
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return <ShoppingList>[];

    dynamic decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return <ShoppingList>[];
    }
    if (decoded is! List) return <ShoppingList>[];

    final lists = <ShoppingList>[];
    final seenIds = <String>{};
    for (final entry in decoded) {
      if (entry is! Map) continue;
      try {
        final shoppingList = ShoppingList.fromJson(
          Map<String, dynamic>.from(entry),
        );
        if (!seenIds.add(shoppingList.id)) continue;
        lists.add(shoppingList);
      } on Object {
        // Ignore one malformed aggregate rather than losing valid lists.
      }
    }

    _sort(lists);
    return lists;
  }

  @override
  Future<void> save(ShoppingList entity) async {
    final lists = await list();
    lists.removeWhere((shoppingList) => shoppingList.id == entity.id);
    lists.add(entity);
    _sort(lists);

    final prefs = await _prefs;
    await prefs.setString(
      storageKey,
      jsonEncode(lists.map((shoppingList) => shoppingList.toJson()).toList()),
    );
  }

  @override
  Future<void> deleteById(String id) async {
    final lists = await list();
    lists.removeWhere((shoppingList) => shoppingList.id == id);

    final prefs = await _prefs;
    await prefs.setString(
      storageKey,
      jsonEncode(lists.map((shoppingList) => shoppingList.toJson()).toList()),
    );
  }

  static void _sort(List<ShoppingList> lists) {
    lists.sort((a, b) => a.id.compareTo(b.id));
  }
}
