import '../domain/household_profile.dart';

abstract interface class HouseholdProfileRepository {
  Future<HouseholdProfile?> load(String userId);
  Future<void> save(HouseholdProfile profile);
}
