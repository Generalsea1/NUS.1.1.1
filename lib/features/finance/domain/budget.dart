import '../../../core/domain/domain_entity.dart';
import '../../../core/domain/domain_repository.dart';

enum BudgetDirection { expense, income }

class Budget implements DomainEntity {
  factory Budget({required String id, required String name, required int limitMinorUnits, required String currencyCode, required DateTime periodStart, required DateTime periodEnd, BudgetDirection direction = BudgetDirection.expense, String? categoryId, bool isArchived = false}) {
    final cleanId=id.trim(), cleanName=name.trim(), currency=currencyCode.trim().toUpperCase(), category=categoryId?.trim();
    if(cleanId.isEmpty) throw ArgumentError.value(id,'id','Budget ID must not be empty.');
    if(cleanName.isEmpty) throw ArgumentError.value(name,'name','Budget name must not be empty.');
    if(limitMinorUnits<=0) throw ArgumentError.value(limitMinorUnits,'limitMinorUnits','Budget limit must be greater than zero.');
    if(!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) throw ArgumentError.value(currencyCode,'currencyCode','Currency code must be exactly three alphabetic characters.');
    if(periodEnd.isBefore(periodStart)) throw ArgumentError.value(periodEnd,'periodEnd','Budget period end must not precede its start.');
    return Budget._(id:cleanId,name:cleanName,limitMinorUnits:limitMinorUnits,currencyCode:currency,periodStart:periodStart,periodEnd:periodEnd,direction:direction,categoryId:category==null||category.isEmpty?null:category,isArchived:isArchived);
  }
  const Budget._({required this.id,required this.name,required this.limitMinorUnits,required this.currencyCode,required this.periodStart,required this.periodEnd,required this.direction,required this.categoryId,required this.isArchived});
  @override final String id; final String name; final int limitMinorUnits; final String currencyCode; final DateTime periodStart; final DateTime periodEnd; final BudgetDirection direction; final String? categoryId; final bool isArchived;
  Budget copyWith({String? id,String? name,int? limitMinorUnits,String? currencyCode,DateTime? periodStart,DateTime? periodEnd,BudgetDirection? direction,String? categoryId,bool clearCategoryId=false,bool? isArchived})=>Budget(id:id??this.id,name:name??this.name,limitMinorUnits:limitMinorUnits??this.limitMinorUnits,currencyCode:currencyCode??this.currencyCode,periodStart:periodStart??this.periodStart,periodEnd:periodEnd??this.periodEnd,direction:direction??this.direction,categoryId:clearCategoryId?null:(categoryId??this.categoryId),isArchived:isArchived??this.isArchived);
  Budget archive()=>copyWith(isArchived:true);
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'limitMinorUnits':limitMinorUnits,'currencyCode':currencyCode,'periodStart':periodStart.toIso8601String(),'periodEnd':periodEnd.toIso8601String(),'direction':direction.name,'categoryId':categoryId,'isArchived':isArchived};
  factory Budget.fromJson(Map<String,dynamic> json){final id=json['id'],name=json['name'],limit=json['limitMinorUnits'],currency=json['currencyCode'],start=json['periodStart'],end=json['periodEnd'],direction=json['direction'],category=json['categoryId'],archived=json['isArchived'];if(id is! String||name is! String||limit is! int||currency is! String||start is! String||end is! String||direction is! String||archived is! bool||(category!=null&&category is! String))throw const FormatException('Invalid Budget record.');final d=switch(direction.trim().toLowerCase()){'expense'=>BudgetDirection.expense,'income'=>BudgetDirection.income,_=>throw const FormatException('Unsupported Budget direction.')};try{return Budget(id:id,name:name,limitMinorUnits:limit,currencyCode:currency,periodStart:DateTime.parse(start),periodEnd:DateTime.parse(end),direction:d,categoryId:category as String?,isArchived:archived);}on FormatException{throw const FormatException('Invalid Budget record.');}on ArgumentError catch(e){throw FormatException(e.message.toString());}}
  @override bool operator==(Object other)=>other is Budget&&other.id==id&&other.name==name&&other.limitMinorUnits==limitMinorUnits&&other.currencyCode==currencyCode&&other.periodStart==periodStart&&other.periodEnd==periodEnd&&other.direction==direction&&other.categoryId==categoryId&&other.isArchived==isArchived;
  @override int get hashCode=>Object.hash(id,name,limitMinorUnits,currencyCode,periodStart,periodEnd,direction,categoryId,isArchived);
}
abstract interface class BudgetRepository implements DomainRepository<Budget>{Future<void> archiveById(String id);}
