import 'package:flutter/material.dart';

import '../application/household_profile_repository.dart';
import '../application/household_profile_validator.dart';
import '../domain/household_profile.dart';

class HouseholdOnboardingPage extends StatefulWidget {
  const HouseholdOnboardingPage({
    super.key,
    required this.userId,
    required this.repository,
    required this.onCompleted,
    this.initialProfile,
  });

  final String userId;
  final HouseholdProfileRepository repository;
  final HouseholdProfileValidator validator = const HouseholdProfileValidator();
  final HouseholdProfile? initialProfile;
  final ValueChanged<HouseholdProfile> onCompleted;

  @override
  State<HouseholdOnboardingPage> createState() => _HouseholdOnboardingPageState();
}

class _HouseholdOnboardingPageState extends State<HouseholdOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _countryController = TextEditingController();
  final _regionController = TextEditingController();
  final _currencyController = TextEditingController();
  final _householdSizeController = TextEditingController();
  final _adultsController = TextEditingController();
  final _childrenController = TextEditingController();
  final _incomeController = TextEditingController();
  final _obligationsController = TextEditingController();

  String _housingType = 'rent';
  String _incomeFrequency = 'monthly';
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final profile = widget.initialProfile;
    if (profile == null) return;
    _countryController.text = profile.countryCode;
    _regionController.text = profile.region ?? '';
    _currencyController.text = profile.currencyCode;
    _householdSizeController.text = '${profile.householdSize}';
    _adultsController.text = '${profile.adults}';
    _childrenController.text = '${profile.children}';
    _incomeController.text = '${profile.monthlyIncome}';
    _obligationsController.text = '${profile.recurringObligations}';
    _housingType = profile.housingType;
    _incomeFrequency = profile.incomeFrequency;
  }

  @override
  void dispose() {
    for (final controller in [
      _countryController,
      _regionController,
      _currencyController,
      _householdSizeController,
      _adultsController,
      _childrenController,
      _incomeController,
      _obligationsController,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  int _number(TextEditingController controller) =>
      int.tryParse(controller.text.trim()) ?? 0;

  HouseholdProfile _profileFromForm() => HouseholdProfile(
        userId: widget.userId,
        countryCode: _countryController.text.trim().toUpperCase(),
        region: _regionController.text.trim().isEmpty
            ? null
            : _regionController.text.trim(),
        currencyCode: _currencyController.text.trim().toUpperCase(),
        householdSize: _number(_householdSizeController),
        adults: _number(_adultsController),
        children: _number(_childrenController),
        housingType: _housingType,
        incomeFrequency: _incomeFrequency,
        monthlyIncome: _number(_incomeController),
        recurringObligations: _number(_obligationsController),
      );

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _saving) return;

    final profile = _profileFromForm();
    final result = widget.validator.validate(profile);
    if (!result.isValid) {
      setState(() => _error = result.firstError);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.save(profile);
      if (!mounted) return;
      widget.onCompleted(profile);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'ماقدرناش نحفظ بيانات البيت دلوقتي. بياناتك مازالت موجودة، حاول تاني.';
      });
    }
  }

  String _fieldError(String key) {
    final errors = widget.validator.validate(_profileFromForm()).errors;
    return errors[key] ?? '';
  }

  InputDecoration _decoration(String label, {IconData? icon}) =>
      InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon));

  Widget _numberField(
    TextEditingController controller,
    String label,
    String key, {
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      textInputAction: TextInputAction.next,
      decoration: _decoration(label, icon: icon),
      validator: (_) {
        final direct = _fieldError(key);
        return direct.isEmpty ? null : direct;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final country = _countryController.text.trim().toUpperCase();
    final regionRequired = const {'US', 'CA', 'AU', 'IN', 'BR', 'MX'}.contains(country);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إعداد بيتك', style: TextStyle(fontWeight: FontWeight.w900)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                'خلّي NUS يعرف نقطة البداية الحقيقية لاقتصاد بيتك.',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text('المعلومات دي هتتحفظ على حسابك، ومن خلالها نحسب لك أول ملخص مالي حقيقي.'),
              const SizedBox(height: 22),
              _section(context, title: 'المكان والعملة', children: [
                TextFormField(
                  controller: _countryController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _decoration('الدولة — كود من حرفين (مثل EG)', icon: Icons.public_outlined),
                  onChanged: (_) => setState(() {}),
                  validator: (_) {
                    final error = _fieldError('country');
                    return error.isEmpty ? null : error;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _regionController,
                  decoration: _decoration(regionRequired ? 'المحافظة / الولاية — مطلوبة هنا' : 'المحافظة / الولاية — اختياري عند عدم انطباقها', icon: Icons.location_on_outlined),
                  validator: (_) {
                    final error = _fieldError('region');
                    return error.isEmpty ? null : error;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _currencyController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: _decoration('العملة — كود من 3 أحرف (مثل EGP)', icon: Icons.currency_exchange_rounded),
                  validator: (_) {
                    final error = _fieldError('currency');
                    return error.isEmpty ? null : error;
                  },
                ),
              ]),
              const SizedBox(height: 14),
              _section(context, title: 'أفراد البيت', children: [
                _numberField(_householdSizeController, 'إجمالي أفراد البيت', 'householdSize', icon: Icons.groups_outlined),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _numberField(_adultsController, 'عدد البالغين', 'adults', icon: Icons.person_outline)),
                  const SizedBox(width: 12),
                  Expanded(child: _numberField(_childrenController, 'عدد الأطفال', 'children', icon: Icons.child_care_outlined)),
                ]),
                const SizedBox(height: 8),
                Text('لازم عدد البالغين + الأطفال يساوي إجمالي أفراد البيت.', style: Theme.of(context).textTheme.bodySmall),
              ]),
              const SizedBox(height: 14),
              _section(context, title: 'السكن والدخل', children: [
                DropdownButtonFormField<String>(
                  initialValue: _housingType,
                  decoration: _decoration('نوع السكن', icon: Icons.home_outlined),
                  items: const [
                    DropdownMenuItem(value: 'rent', child: Text('إيجار')),
                    DropdownMenuItem(value: 'owned', child: Text('تمليك')),
                    DropdownMenuItem(value: 'family', child: Text('مع الأسرة')),
                    DropdownMenuItem(value: 'other', child: Text('أخرى')),
                  ],
                  onChanged: (value) => setState(() => _housingType = value ?? 'rent'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _incomeFrequency,
                  decoration: _decoration('تكرار الدخل', icon: Icons.event_repeat_outlined),
                  items: const [
                    DropdownMenuItem(value: 'monthly', child: Text('شهري')),
                    DropdownMenuItem(value: 'weekly', child: Text('أسبوعي')),
                    DropdownMenuItem(value: 'biweekly', child: Text('كل أسبوعين')),
                    DropdownMenuItem(value: 'irregular', child: Text('غير منتظم')),
                  ],
                  onChanged: (value) => setState(() => _incomeFrequency = value ?? 'monthly'),
                ),
                const SizedBox(height: 12),
                _numberField(_incomeController, 'الدخل الشهري / المعادل الشهري', 'monthlyIncome', icon: Icons.account_balance_wallet_outlined),
              ]),
              const SizedBox(height: 14),
              _section(context, title: 'الالتزامات الشهرية الأولية', children: [
                _numberField(_obligationsController, 'إجمالي الالتزامات الثابتة والأقساط الشهرية', 'recurringObligations', icon: Icons.receipt_long_outlined),
                const SizedBox(height: 8),
                Text('اكتب الإجمالي الحقيقي للالتزامات المتكررة فقط. المصروفات اليومية ستدخل لاحقًا في إدارة المصروفات.', style: Theme.of(context).textTheme.bodySmall),
              ]),
              const SizedBox(height: 18),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(16)),
                  child: Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_forward_rounded),
                  label: Text(_saving ? 'جاري الحفظ...' : 'حفظ وإظهار حالتي المالية'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, {required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}
