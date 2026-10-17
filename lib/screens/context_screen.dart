import 'package:flutter/material.dart';

import '../data/app_state.dart';
import '../models/play_context.dart';
import '../ui/motion.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'home_screen.dart';

/// Shown on every launch: "who are you playing with?". Also reachable from Home.
class ContextScreen extends StatefulWidget {
  const ContextScreen({super.key, this.startup = true});

  /// true = replaces itself with Home after a pick; false = pops back.
  final bool startup;

  @override
  State<ContextScreen> createState() => _ContextScreenState();
}

class _ContextScreenState extends State<ContextScreen> {
  PlayContext? _picking;

  Future<void> _pick(PlayContext c) async {
    if (_picking != null) return;
    final state = AppScope.read(context);
    tick(state.appSettings.haptics);
    if (c.adult && !state.adultConfirmed) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Jen pro dospělé'),
          content: Text(
            '${c.label} obsahuje 18+ témata: rande, párty, alkohol a trochu pikantní slova. '
            'Potvrď, že všem hráčům je aspoň 18 let.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Zpět')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Je nám 18+')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    setState(() => _picking = c);
    state.setContext(c);
    await Future<void>.delayed(Motion.of(context, Motion.quick));
    if (!mounted) return;
    if (widget.startup) {
      Navigator.of(context).pushReplacement(PageRouteBuilder(
        transitionDuration: Motion.of(context, Motion.slow),
        pageBuilder: (_, _, _) => const HomeScreen(),
        transitionsBuilder: (_, animation, _, child) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Motion.ease),
          child: ScaleTransition(
            scale: Tween(begin: 1.04, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Motion.ease)),
            child: child,
          ),
        ),
      ));
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final current = _picking ?? state.playContext;

    return Scaffold(
      appBar: widget.startup ? null : AppBar(),
      body: AmbientBackground(
        colors: current.colors,
        intensity: 1.4,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              if (widget.startup) ...[
                FadeSlideIn(
                  child: GradientText(
                    'Impostor',
                    colors: const [Party.red, Party.yellow, Party.green, Party.pink],
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -1.5),
                  ),
                ),
                const SizedBox(height: 4),
                FadeSlideIn(
                  index: 1,
                  child: Text(
                    'Všichni znají tajné slovo. Až na jednoho.',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: scheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                  ),
                ),
                const SizedBox(height: 36),
              ],
              FadeSlideIn(
                index: 2,
                child: Text('S kým dneska hraješ?', style: Theme.of(context).textTheme.headlineSmall),
              ),
              const SizedBox(height: 16),
              for (final (i, c) in PlayContext.values.indexed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: FadeSlideIn(
                    index: 3 + i,
                    child: _ContextTile(
                      value: c,
                      selected: c == current,
                      onTap: () => _pick(c),
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              FadeSlideIn(
                index: 8,
                child: Text(
                  'Kdykoliv to změníš nahoře na hlavní obrazovce.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContextTile extends StatelessWidget {
  const _ContextTile({required this.value, required this.selected, required this.onTap});

  final PlayContext value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Pressable(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.0 : 0.97,
        duration: Motion.base,
        curve: Motion.pop,
        child: AnimatedContainer(
          duration: Motion.base,
          curve: Motion.ease,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: selected ? value.gradient : null,
            color: selected ? null : scheme.surfaceContainerHigh.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(26),
            boxShadow: selected
                ? [BoxShadow(color: value.accent.withValues(alpha: 0.4), blurRadius: 28, offset: const Offset(0, 12))]
                : null,
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: Motion.base,
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: selected ? null : value.gradient,
                  color: selected ? Colors.white.withValues(alpha: 0.22) : null,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(value.emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          value.label,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(color: selected ? Colors.white : null),
                        ),
                        if (value.adult) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: selected ? Colors.white.withValues(alpha: 0.25) : Party.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '18+',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                                color: selected ? Colors.white : Party.red,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value.tagline,
                      style: TextStyle(color: selected ? Colors.white.withValues(alpha: 0.9) : scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: Motion.quick,
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
