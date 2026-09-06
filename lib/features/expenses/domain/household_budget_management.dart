/// Actionable management output produced from a household budget plan.
enum HouseholdBudgetPriority { essential, important, flexible, reserve }

class HouseholdBudgetLine {
  const HouseholdBudgetLine({
    required this.key,
    required this.title,
    required this.amount,
    required this.weeklyCap,
    required this.priority,
    required this.autoAllocated,
  });

  final String key;
  final String title;
  final int amount;
  final int weeklyCap;
  final HouseholdBudgetPriority priority;
  final bool autoAllocated;
}

class HouseholdBudgetManagement {
  const HouseholdBudgetManagement({
    required this.lines,
    required this.protectedAmount,
    required this.flexibleRoom,
    required this.weeklyRoom,
    required this.cutOrder,
    required this.managerMessage,
  });

  final List<HouseholdBudgetLine> lines;
  final int protectedAmount;
  final int flexibleRoom;
  final int weeklyRoom;
  final List<String> cutOrder;
  final String managerMessage;
}

HouseholdBudgetManagement buildHouseholdBudgetManagement({
  required int rent,
  required int utilities,
  required int food,
  required int transport,
  required int debt,
  required int health,
  required int clothing,
  required int maintenance,
  required int familyFun,
  required int other,
  required int reserve,
  required int weeklyRoom,
  required int knownFood,
  required int knownClothing,
  required int knownMaintenance,
  required int knownFamilyFun,
  required int knownOther,
}) {
  final lines = <HouseholdBudgetLine>[
    HouseholdBudgetLine(key: 'rent', title: 'السكن', amount: rent, weeklyCap: _weekly(rent), priority: HouseholdBudgetPriority.essential, autoAllocated: false),
    HouseholdBudgetLine(key: 'utilities', title: 'المرافق', amount: utilities, weeklyCap: _weekly(utilities), priority: HouseholdBudgetPriority.essential, autoAllocated: false),
    HouseholdBudgetLine(key: 'food', title: 'الغذاء والبيت', amount: food, weeklyCap: _weekly(food), priority: HouseholdBudgetPriority.essential, autoAllocated: knownFood == 0),
    HouseholdBudgetLine(key: 'transport', title: 'المواصلات', amount: transport, weeklyCap: _weekly(transport), priority: HouseholdBudgetPriority.essential, autoAllocated: false),
    HouseholdBudgetLine(key: 'debt', title: 'الديون والأقساط', amount: debt, weeklyCap: _weekly(debt), priority: HouseholdBudgetPriority.essential, autoAllocated: false),
    HouseholdBudgetLine(key: 'health', title: 'الصحة والدواء', amount: health, weeklyCap: _weekly(health), priority: HouseholdBudgetPriority.essential, autoAllocated: false),
    HouseholdBudgetLine(key: 'clothing', title: 'الملابس', amount: clothing, weeklyCap: _weekly(clothing), priority: HouseholdBudgetPriority.flexible, autoAllocated: knownClothing == 0),
    HouseholdBudgetLine(key: 'maintenance', title: 'الصيانة', amount: maintenance, weeklyCap: _weekly(maintenance), priority: HouseholdBudgetPriority.important, autoAllocated: knownMaintenance == 0),
    HouseholdBudgetLine(key: 'familyFun', title: 'الفسحة والعائلة', amount: familyFun, weeklyCap: _weekly(familyFun), priority: HouseholdBudgetPriority.flexible, autoAllocated: knownFamilyFun == 0),
    HouseholdBudgetLine(key: 'other', title: 'متفرقات', amount: other, weeklyCap: _weekly(other), priority: HouseholdBudgetPriority.flexible, autoAllocated: knownOther == 0),
    HouseholdBudgetLine(key: 'reserve', title: 'احتياطي الطوارئ', amount: reserve, weeklyCap: 0, priority: HouseholdBudgetPriority.reserve, autoAllocated: reserve > 0),
  ];

  final protected = rent + utilities + transport + debt + health + reserve;
  final flexible = food + clothing + maintenance + familyFun + other;

  return HouseholdBudgetManagement(
    lines: List.unmodifiable(lines),
    protectedAmount: protected,
    flexibleRoom: flexible,
    weeklyRoom: weeklyRoom,
    cutOrder: const ['other', 'familyFun', 'clothing', 'maintenance', 'food'],
    managerMessage: weeklyRoom > 0 && flexible > 0
        ? 'ثبّت الأساسيات والاحتياطي أولاً. عند الضغط على الميزانية يبدأ الخفض من المتفرقات ثم الفسحة ثم الملابس، ولا نقترب من الغذاء والصحة والسكن إلا عند الضرورة.'
        : 'الهامش المتاح ضعيف. لا تزود الإنفاق المرن قبل تأمين الأساسيات والاحتياطي.',
  );
}

int _weekly(int monthly) => monthly <= 0 ? 0 : (monthly / 4.33).round();
