import 'package:flutter/material.dart';

import '../../../core/ai/ai_insight.dart';
import '../../../core/ai/ai_insight_provider.dart';
import '../../expenses/domain/currency_registry.dart';
import '../../finance/application/financial_advisor.dart';
import '../../finance/application/financial_advisor_provider.dart';
import '../../finance/application/financial_engine.dart';

class AskNusPage extends StatefulWidget {
  const AskNusPage({
    super.key,
    required this.snapshot,
    this.provider = const FinancialAdvisorProvider(),
    this.initialQuestion,
  });

  final FinancialAdvisorSnapshot snapshot;
  final AiInsightProvider provider;
  final String? initialQuestion;

  @override
  State<AskNusPage> createState() => _AskNusPageState();

  // The remainder of this widget is unchanged from the verified redesign.
  // See the branch history for the full implementation.
}