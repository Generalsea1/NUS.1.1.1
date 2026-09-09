import 'package:flutter_test/flutter_test.dart';

import 'package:nus/core/ai/ai_insight.dart';
import 'package:nus/features/ai/application/nus_ai_context_composer.dart';

void main() {
  test('filters context to explicitly allowed domains', () {
    final request = NusAiContextComposer.compose(
      objective: 'Help me plan today.',
      allowedDomains: const {'calendar', 'tasks'},
      context: const [
        AiContextItem(domain: 'calendar', entityId: 'a2', summary: 'Doctor at 10.'),
        AiContextItem(domain: 'finance', entityId: 'f1', summary: 'Financial data.'),
        AiContextItem(domain: 'tasks', entityId: 't1', summary: 'Send the report.'),
      ],
    );

    expect(request.context.map((item) => item.domain), ['calendar', 'tasks']);
  });

  test('deduplicates and sorts context deterministically', () {
    final input = [
      const AiContextItem(domain: 'tasks', entityId: 't2', summary: 'Second'),
      const AiContextItem(domain: 'calendar', entityId: 'a2', summary: 'Later'),
      const AiContextItem(domain: 'calendar', entityId: 'a1', summary: 'First'),
      const AiContextItem(domain: 'tasks', entityId: 't2', summary: 'Duplicate'),
    ];

    final request = NusAiContextComposer.compose(
      objective: 'Plan.',
      context: input,
    );

    expect(request.context.map((item) => '${item.domain}:${item.entityId}'), [
      'calendar:a1',
      'calendar:a2',
      'tasks:t2',
    ]);
    expect(request.context[2].summary, 'Second');
  });

  test('ignores unsupported or malformed context without throwing', () {
    final request = NusAiContextComposer.compose(
      objective: 'Plan.',
      context: const [
        AiContextItem(domain: 'secrets', entityId: 'x', summary: 'No.'),
        AiContextItem(domain: 'finance', entityId: '', summary: 'No ID.'),
        AiContextItem(domain: 'finance', entityId: 'f1', summary: 'Monthly facts.'),
      ],
    );

    expect(request.context, hasLength(1));
    expect(request.context.single.domain, 'finance');
  });

  test('honors the context budget', () {
    final request = NusAiContextComposer.compose(
      objective: 'Plan.',
      maxItems: 2,
      context: const [
        AiContextItem(domain: 'calendar', entityId: 'a1', summary: 'One'),
        AiContextItem(domain: 'calendar', entityId: 'a2', summary: 'Two'),
        AiContextItem(domain: 'tasks', entityId: 't1', summary: 'Three'),
      ],
    );

    expect(request.context, hasLength(2));
  });

  test('rejects empty objective and invalid budget', () {
    expect(
      () => NusAiContextComposer.compose(objective: ' ', context: const []),
      throwsArgumentError,
    );
    expect(
      () => NusAiContextComposer.compose(objective: 'Plan.', maxItems: 0, context: const []),
      throwsArgumentError,
    );
  });
}
