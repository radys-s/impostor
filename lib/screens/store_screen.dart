import 'package:flutter/material.dart';

import '../ai/ai_client.dart';
import '../data/app_state.dart';
import '../models/play_context.dart';
import '../store/store.dart';
import '../ui/icons.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Native plugin store. Features ship inside the app and work offline once
/// switched on; word packs are downloaded from the public repo.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key, this.client});

  final StoreClient? client;

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  late final StoreClient _client = widget.client ?? StoreClient();
  List<StoreItem>? _packs;
  String? _error;
  bool _loading = true;
  final Set<String> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _client.catalog();
      if (!mounted) return;
      setState(() => _packs = [for (final i in items) if (i.type == PluginType.pack) i]);
    } on StoreException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleFeature(FeaturePlugin f) {
    final state = AppScope.read(context);
    tick(state.appSettings.haptics);
    if (state.has(f)) {
      state.removeFeature(f);
      showSnack(context, '${f.name}: odebráno');
    } else {
      state.installFeature(f);
      showSnack(context, '${f.name}: nainstalováno');
    }
  }

  Future<void> _togglePack(StoreItem item) async {
    final state = AppScope.read(context);
    tick(state.appSettings.haptics);
    if (state.hasStorePack(item.id)) {
      state.removeStorePack(item.id);
      showSnack(context, '${item.name}: odebráno');
      return;
    }
    if (item.audience == Audience.adult && !state.adultConfirmed) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Balíček 18+'),
          content: const Text('Obsahuje pikantní slova pro dospělé. Uvidíš ho jen v režimu Mix nebo Freaky.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zpět')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Je mi 18+')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      state.confirmAdult();
    }
    setState(() => _busy.add(item.id));
    try {
      final pack = await _client.pack(item);
      state.installStorePack(pack);
      if (mounted) {
        final hidden = !state.fitsContext(pack);
        showSnack(context, hidden ? '${item.name} je nainstalován, ukáže se v jiném režimu' : '${item.name} je mezi tématy');
      }
    } on StoreException catch (e) {
      if (mounted) showSnack(context, e.message);
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final packs = _packs;

    return Scaffold(
      appBar: AppBar(title: const Text('Obchod')),
      body: AmbientBackground(
        intensity: 1.3,
        child: RefreshIndicator(
          onRefresh: _load,
          child: PageBody(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 4),
                child: Text(
                  'Všechno zdarma. Hra funguje i bez rozšíření, přidej si jen to, co chceš.',
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
              const SectionLabel('Rozšíření'),
              for (final f in FeaturePlugin.values)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _StoreTile(
                    icon: f.icon,
                    title: f.name,
                    description: f == FeaturePlugin.ai && !AiClient.configured
                        ? '${f.description} Server zatím není zapojený.'
                        : f.description,
                    installed: state.has(f),
                    onTap: () => _toggleFeature(f),
                  ),
                ),
              const SectionLabel('Balíčky slov'),
              if (_loading && packs == null)
                const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null && packs == null)
                _Offline(message: _error!, onRetry: _load)
              else if (packs != null && packs.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Zatím tu nic není.', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
                )
              else if (packs != null)
                for (final item in packs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _StoreTile(
                      icon: PackIcons.of(item.emoji),
                      title: item.name,
                      description: item.description,
                      badge: item.audience == Audience.adult
                          ? '18+'
                          : (item.audience == Audience.friends ? '13+' : null),
                      meta: item.words > 0 ? '${item.words} slov' : null,
                      installed: state.hasStorePack(item.id),
                      busy: _busy.contains(item.id),
                      onTap: () => _togglePack(item),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.installed,
    required this.onTap,
    this.badge,
    this.meta,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool installed;
  final VoidCallback onTap;
  final String? badge;
  final String? meta;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ctx = AppScope.of(context).playContext;
    return AnimatedContainer(
      duration: Motion.quick,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: installed ? ctx.accent.withValues(alpha: 0.7) : scheme.outlineVariant.withValues(alpha: 0.4),
          width: installed ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: Party.red.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(badge!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Party.red)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(description, style: TextStyle(color: scheme.onSurfaceVariant)),
                if (meta != null) ...[
                  const SizedBox(height: 2),
                  Text(meta!, style: TextStyle(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w600, fontSize: 12)),
                ],
                const SizedBox(height: 10),
                _InstallButton(installed: installed, busy: busy, onTap: onTap, title: title),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallButton extends StatelessWidget {
  const _InstallButton({required this.installed, required this.busy, required this.onTap, required this.title});

  final bool installed;
  final bool busy;
  final VoidCallback onTap;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final g = AppScope.of(context).playContext.gradient;
    final label = busy ? 'Stahuji…' : (installed ? 'Odebrat' : 'Přidat');
    return Semantics(
      button: true,
      label: '$label $title',
      excludeSemantics: true,
      child: Pressable(
        onTap: busy ? null : onTap,
        child: AnimatedContainer(
          duration: Motion.quick,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            gradient: installed ? null : g,
            color: installed ? scheme.surfaceContainerHighest : null,
            borderRadius: BorderRadius.circular(40),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                busy ? Icons.downloading_rounded : (installed ? Icons.check_rounded : Icons.add_rounded),
                size: 18,
                color: installed ? scheme.onSurface : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontWeight: FontWeight.w800, color: installed ? scheme.onSurface : Colors.white)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Offline extends StatelessWidget {
  const _Offline({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.wifi_off_rounded, size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 12),
            OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Zkusit znovu')),
          ],
        ),
      ),
    );
  }
}
