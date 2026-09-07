import '../domain/household_profile.dart';

class HouseholdProfileValidator {
  const HouseholdProfileValidator();

  static const _housingTypes = {'rent', 'owned', 'family', 'other'};
  static const _incomeFrequencies = {
    'monthly',
    'weekly',
    'biweekly',
    'irregular',
  };

  ValidationResult validate(HouseholdProfile profile) {
    final errors = <String, String>{};
    final country = profile.countryCode.trim().toUpperCase();
    final currency = profile.currencyCode.trim().toUpperCase();
    final region = profile.region?.trim() ?? '';

    if (!RegExp(r'^[A-Z]{2}$').hasMatch(country)) {
      errors['country'] = 'Country must be a valid 2-letter country code.';
    }
    if (_requiresRegion(country) && region.isEmpty) {
      errors['region'] = 'Region/state/province is required for this country.';
    }
    if (!RegExp(r'^[A-Z]{3}$').hasMatch(currency)) {
      errors['currency'] = 'Currency must be a valid 3-letter code.';
    }
    if (profile.householdSize < 1 || profile.householdSize > 50) {
      errors['householdSize'] = 'Household size must be between 1 and 50.';
    }
    if (profile.adults < 1 || profile.adults > 20) {
      errors['adults'] = 'At least one adult is required.';
    }
    if (profile.children < 0 || profile.children > 30) {
      errors['children'] = 'Children count must be between 0 and 30.';
    }
    if (profile.adults + profile.children != profile.householdSize) {
      errors['householdSize'] = 'Adults plus children must equal household size.';
    }
    if (!_housingTypes.contains(profile.housingType)) {
      errors['housingType'] = 'Select a valid housing type.';
    }
    if (!_incomeFrequencies.contains(profile.incomeFrequency)) {
      errors['incomeFrequency'] = 'Select a valid income frequency.';
    }
    if (profile.monthlyIncome <= 0) {
      errors['monthlyIncome'] = 'Monthly income must be greater than zero.';
    }
    if (profile.monthlyIncome < 0) {
      errors['monthlyIncome'] = 'Monthly income cannot be negative.';
    }
    if (profile.recurringObligations < 0) {
      errors['recurringObligations'] = 'Recurring obligations cannot be negative.';
    }
    if (profile.userId.trim().isEmpty) {
      errors['userId'] = 'A signed-in user is required.';
    }

    return ValidationResult(errors);
  }

  bool isValid(HouseholdProfile profile) => validate(profile).isValid;

  bool _requiresRegion(String country) =>
      const {'US', 'CA', 'AU', 'IN', 'BR', 'MX'}.contains(country);
}

class ValidationResult {
  const ValidationResult(this.errors);

  final Map<String, String> errors;

  bool get isValid => errors.isEmpty;
  String get firstError =>
      errors.values.isEmpty ? '' : errors.values.first;
}
