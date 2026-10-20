import 'package:flutter/material.dart';

import '../ai/ai_client.dart';
import '../data/app_state.dart';
import '../store/store.dart';
import '../ui/how_to_play.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'context_screen.dart';
import 'store_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final s = state.appSettings;
    final scheme = Theme.of(context).colorScheme;
    void open(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    return Scaffold(
      appBar: AppBar(title: const Text('Nastavení')),
      body: AmbientBackground(
        child: PageBody(
          children: [
            PartyTile(
              leading: IconBadge(state.playContext.icon),
              title: 'Hrajeme: ${state.playContext.label}',
              subtitle: state.playContext.tagline,
              trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              onTap: () => open(const ContextScreen(startup: false)),
            ),
            const SectionLabel('Hra'),
            Card(
              child: Column(
                children: [
                  if (state.has(FeaturePlugin.voting))
                    SwitchListTile(
                      title: const Text('Hlasování v aplikaci'),
                      subtitle: Text(s.inAppVoting
                          ? 'Telefon koluje a každý tajně hlasuje.'
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
            const SizedBox(height: 12),
            PartyTile(
              leading: const IconBadge(Icons.storefront_rounded),
              title: 'Obchod s rozšířeními',
              subtitle: state.features.isEmpty
                  ? 'Skóre, hlasování, AI a balíčky slov. Zdarma.'
                  : 'Nainstalováno: ${[for (final f in FeaturePlugin.values) if (state.has(f)) f.name].join(', ')}',
              trailing: Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
              onTap: () => open(const StoreScreen()),
            ),
            const SectionLabel('Jak se hraje'),
            const Card(
              child: Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 4),
                child: HowToPlay(),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  'Undercover: impostor dostane podobné slovo a neví, že je impostor.\n'
                  'Chaos: občas není impostor nikdo, nebo jsou to všichni.',
                  style: TextStyle(height: 1.45, color: scheme.onSurfaceVariant),
                ),
              ),
            ),
            const SectionLabel('O aplikaci'),
            Card(
              child: ListTile(
                title: const Text('Impostor 1.0', style: TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                  'Zdarma, bez reklam, bez účtu. Hra běží offline, internet potřebuje jen obchod'
                  '${AiClient.configured ? ' a AI' : ''}.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
