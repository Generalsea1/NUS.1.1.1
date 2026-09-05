import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/budget.dart';

class LocalBudgetRepository implements BudgetRepository {
  static const storageKey='nus.finance.budgets.v1';
  LocalBudgetRepository(this._preferences);
  final SharedPreferences _preferences;
  @override Future<Budget?> getById(String id) async { final clean=id.trim(); if(clean.isEmpty)return null; for(final b in await list()){if(b.id==clean)return b;} return null; }
  @override Future<List<Budget>> list() async { final raw=_preferences.getString(storageKey); if(raw==null||raw.trim().isEmpty)return const []; dynamic decoded; try{decoded=jsonDecode(raw);}on FormatException{return const [];} if(decoded is! List<dynamic>)return const []; final out=<Budget>[]; for(final item in decoded){if(item is Map<String,dynamic>){try{out.add(Budget.fromJson(item));}on FormatException{}}} out.sort((a,b){final p=a.periodStart.compareTo(b.periodStart);if(p!=0)return p;final n=a.name.toLowerCase().compareTo(b.name.toLowerCase());return n!=0?n:a.id.compareTo(b.id);});return List.unmodifiable(out); }
  @override Future<void> save(Budget entity) async { final records=_decodeForWrite(_preferences.getString(storageKey)); final next=<Map<String,dynamic>>[]; var replaced=false; for(final r in records){if(r['id']==entity.id){if(!replaced){next.add(entity.toJson());replaced=true;}}else{next.add(r);}} if(!replaced)next.add(entity.toJson()); await _preferences.setString(storageKey,jsonEncode(next)); }
  @override Future<void> deleteById(String id) async {final b=await getById(id);if(b!=null)await archiveById(b.id);}
  @override Future<void> archiveById(String id) async {final b=await getById(id);if(b!=null)await save(b.archive());}
  List<Map<String,dynamic>> _decodeForWrite(String? raw){if(raw==null||raw.trim().isEmpty)return [];dynamic decoded;try{decoded=jsonDecode(raw);}on FormatException{throw StateError('Financial budget storage is malformed.');}if(decoded is! List<dynamic>)throw StateError('Financial budget storage root must be a list.');return [for(final item in decoded)if(item is Map<String,dynamic>)item];}
}
