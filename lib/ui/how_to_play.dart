import 'package:flutter/material.dart';

import 'widgets.dart';

/// The rules as four short icon steps. Shared by the home sheet and settings.
class HowToPlay extends StatelessWidget {
  const HowToPlay({super.key});

  static const steps = [
    (Icons.touch_app_rounded, 'Každý si tajně otočí kartu', 'Telefon koluje. Všichni vidí stejné slovo, impostor ne.'),
    (Icons.record_voice_over_rounded, 'Po řadě řekněte jedno slovo', 'Něco, co k tajnému slovu sedí. Ne moc jasného.'),
    (Icons.forum_rounded, 'Diskutujte a hlasujte', 'Nahlas ukažte na toho, komu nevěříte.'),
    (Icons.visibility_rounded, 'Odhalte impostora', 'Aplikace ukáže, kdo to byl. Chycený impostor ještě může hádat slovo.'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final (i, (icon, title, text)) in steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(icon, size: 40),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${i + 1}. $title', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(text, style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<void> showHowToPlay(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Jak se hraje', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              const HowToPlay(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Jasně, jdeme na to')),
              ),
            ],
          ),
        ),
      ),
    );
