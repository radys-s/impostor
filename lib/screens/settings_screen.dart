import 'package:flutter/material.dart';

import '../ai/ai_client.dart';
import '../data/app_state.dart';
import '../ui/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.appSettings;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nastavení')),
      body: PageBody(
        children: [
          const SectionLabel('Hra'),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('Hlasování v aplikaci'),
                  subtitle: Text(s.inAppVoting
                      ? 'Telefon koluje a každý tajně hlasuje. Aplikace počítá body.'
                      : 'Hlasujete nahlas, aplikace jen odhalí impostora.'),
                  value: s.inAppVoting,
                  onChanged: (v) => state.updateAppSettings(s.copyWith(inAppVoting: v)),
                ),
                SwitchListTile(
                  title: const Text('Vibrace'),
                  value: s.haptics,
                  onChanged: (v) => state.updateAppSettings(s.copyWith(haptics: v)),
                ),
              ],
            ),
          ),
          const SectionLabel('Jak se hraje'),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '1. Každý si tajně prohlédne svou kartu.\n'
                '2. Všichni kromě impostora vidí stejné tajné slovo.\n'
                '3. Po řadě každý řekne jedno slovo, které k němu sedí. '
                'Ne moc jasné, ať impostor slovo neuhodne.\n'
                '4. Diskutujte a hlasujte, kdo je impostor.\n'
                '5. Když impostora odhalíte, má poslední šanci uhodnout slovo.\n\n'
                'Undercover: impostor dostane podobné slovo a neví, že je impostor.\n'
                'Chaos: občas není impostor nikdo, nebo jsou to všichni.',
              ),
            ),
          ),
          const SectionLabel('O aplikaci'),
          Card(
            child: ListTile(
              title: const Text('Impostor 1.0'),
              subtitle: Text(
                'Zdarma, bez reklam, bez účtu. AI témata: ${AiClient.configured ? 'zapnuto' : 'není nastaveno'}.',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
