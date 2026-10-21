import '../models/play_context.dart';

/// How often a round gets a twist.
enum EventRate {
  off('Vypnuto', 0),
  sometimes('Občas', 0.3),
  often('Často', 0.6),
  always('Pořád', 1);

  const EventRate(this.label, this.chance);

  final String label;
  final double chance;

  static EventRate parse(Object? value) =>
      EventRate.values.firstWhere((e) => e.name == value, orElse: () => EventRate.often);
}

/// What an event changes in the game itself. Most events are only a rule
/// the players follow; a few also change the round.
enum EventEffect {
  none,

  /// Clue order is reversed.
  reverse,

  /// The discussion timer is forced to [RoundEvent.timerSeconds].
  timer,

  /// Every clue must start with a random letter ({letter} in the text).
  letter,

  /// Plain impostors see the first letter of the secret word.
  impostorLetter,
}

/// A twist announced on the round screen.
class RoundEvent {
  const RoundEvent({
    required this.id,
    required this.title,
    required this.text,
    required this.icon,
    this.audiences = _all,
    this.effect = EventEffect.none,
    this.timerSeconds = 0,
    this.payoff = false,
  });

  final String id;
  final String title;

  /// May contain {letter}, replaced by [Round.eventLetter].
  final String text;

  /// Key resolved to an icon in the UI (see EventIcons).
  final String icon;

  /// Shown when any of these audiences is allowed in the current context.
  final Set<Audience> audiences;
  final EventEffect effect;
  final int timerSeconds;

  /// The rule settles after the vote, so the result screen repeats it.
  final bool payoff;

  bool fits(Set<Audience> allowed) => audiences.any(allowed.contains);

  String textWith(String? letter) => text.replaceAll('{letter}', letter ?? '');

  static const _all = {Audience.family, Audience.friends, Audience.adult};
}

const _teen = {Audience.friends, Audience.adult};
const _adult = {Audience.adult};

/// Letters that start plenty of Czech words.
const eventLetters = ['A', 'B', 'D', 'H', 'K', 'L', 'M', 'N', 'O', 'P', 'R', 'S', 'T', 'V', 'Z'];

const roundEvents = <RoundEvent>[
  // For everybody.
  RoundEvent(
    id: 'rychlovka',
    title: 'Rychlovka',
    text: 'Na nápovědu máte 3 vteřiny. Diskuze trvá jen minutu. Kdo zaváhá, je podezřelý.',
    icon: 'bolt',
    effect: EventEffect.timer,
    timerSeconds: 60,
  ),
  RoundEvent(
    id: 'zpatecka',
    title: 'Zpátečka',
    text: 'Dnes se jede v opačném pořadí. Začíná ten, kdo by byl jinak poslední.',
    icon: 'reverse',
    effect: EventEffect.reverse,
  ),
  RoundEvent(
    id: 'pismenko',
    title: 'Písmenko',
    text: 'Všechny nápovědy musí začínat na {letter}. Kdo to poruší, vysvětluje.',
    icon: 'letter',
    effect: EventEffect.letter,
  ),
  RoundEvent(
    id: 'tip-pro-impostora',
    title: 'Tip pro impostora',
    text: 'Impostor dnes zná první písmeno tajného slova. Buďte opatrní.',
    icon: 'spy',
    effect: EventEffect.impostorLetter,
  ),
  RoundEvent(
    id: 'dve-kolecka',
    title: 'Dvě kolečka',
    text: 'Každý řekne dvě slova ve dvou kolech. Druhé kolo musí navázat na první.',
    icon: 'repeat',
  ),
  RoundEvent(
    id: 'pantomima',
    title: 'Pantomima',
    text: 'Žádná slova. Nápovědu jen ukaž, zvuky jsou zakázané.',
    icon: 'gesture',
  ),
  RoundEvent(
    id: 'septanda',
    title: 'Šeptanda',
    text: 'Celé kolo včetně diskuze se mluví jen šeptem.',
    icon: 'whisper',
  ),
  RoundEvent(
    id: 'otazky',
    title: 'Výslech',
    text: 'Místo slova polož otázku dalšímu hráči. Ten odpoví jedním slovem.',
    icon: 'question',
  ),
  RoundEvent(
    id: 'zvuky',
    title: 'Zvukař',
    text: 'Místo slova vydej zvuk, který k tajnému slovu sedí.',
    icon: 'sound',
  ),
  RoundEvent(
    id: 'robot',
    title: 'Roboti',
    text: 'Všichni mluví jako roboti. Až do hlasování.',
    icon: 'robot',
  ),
  RoundEvent(
    id: 'na-tri',
    title: 'Na tři!',
    text: 'Žádná diskuze. Po nápovědách všichni naráz ukážou na podezřelého.',
    icon: 'point',
  ),
  RoundEvent(
    id: 'mlcoun',
    title: 'Mlčoun',
    text: 'Kdo začíná, nesmí mluvit až do hlasování. Jen kývá a ukazuje.',
    icon: 'mute',
  ),
  // Teens and adults.
  RoundEvent(
    id: 'herec',
    title: 'Oscarová role',
    text: 'Každou nápovědu řekni dramaticky, jako by šlo o život.',
    icon: 'drama',
    audiences: _teen,
  ),
  RoundEvent(
    id: 'bez-smichu',
    title: 'Kamenná tvář',
    text: 'Kdo se během kola zasměje, dostane automaticky jeden hlas navíc.',
    icon: 'serious',
    audiences: _teen,
    payoff: true,
  ),
  RoundEvent(
    id: 'obhajoba',
    title: 'Soud',
    text: 'Kdo dostane nejvíc hlasů, má 15 vteřin na obhajobu. Pak se hlasuje znovu.',
    icon: 'gavel',
    audiences: _teen,
    payoff: true,
  ),
  RoundEvent(
    id: 'prizvuk',
    title: 'Přízvuk',
    text: 'Mluvte s přízvukem. Moravák, Slovák, Ostravák, vyberte si.',
    icon: 'accent',
    audiences: _teen,
  ),
  RoundEvent(
    id: 'roast',
    title: 'Roast',
    text: 'Než řekneš nápovědu, rýpni si do hráče po své pravici. Laskavě.',
    icon: 'fire',
    audiences: _teen,
  ),
  // 18+ only (Mix and Freaky).
  RoundEvent(
    id: 'svudny-hlas',
    title: 'Svůdný hlas',
    text: 'Všechny nápovědy svůdným hlasem. Kdo se rozesměje, prozradil se.',
    icon: 'lips',
    audiences: _adult,
  ),
  RoundEvent(
    id: 'pohled-do-oci',
    title: 'Pohled do očí',
    text: 'Při nápovědě se dívej do očí hráči vedle sebe. Kdo uhne pohledem, je podezřelý.',
    icon: 'eyes',
    audiences: _adult,
  ),
  RoundEvent(
    id: 'kompliment',
    title: 'Lichotník',
    text: 'Před nápovědou slož kompliment hráči po své levici. Čím odvážnější, tím líp.',
    icon: 'heart',
    audiences: _adult,
  ),
  RoundEvent(
    id: 'dvojsmysl',
    title: 'Dvojsmysl',
    text: 'Každá nápověda musí znít dvojsmyslně. Nevinná slova se nepočítají.',
    icon: 'wink',
    audiences: _adult,
  ),
  RoundEvent(
    id: 'do-ucha',
    title: 'Do ouška',
    text: 'Nápovědu pošeptej sousedovi do ucha. On ji řekne nahlas za tebe.',
    icon: 'whisper',
    audiences: _adult,
  ),
  RoundEvent(
    id: 'hot-seat',
    title: 'Hot seat',
    text: 'Kdo dostane nejvíc hlasů, odpoví na jednu pikantní otázku skupiny. Nebo dá fant.',
    icon: 'fire',
    audiences: _adult,
    payoff: true,
  ),
  RoundEvent(
    id: 'panak',
    title: 'Na zdraví',
    text: 'Poražená strana si připije. Impostor, pokud vyhraje, rozdá dva doušky komu chce.',
    icon: 'drink',
    audiences: _adult,
    payoff: true,
  ),
  RoundEvent(
    id: 'poza',
    title: 'Fotka pro Insta',
    text: 'Při nápovědě zaujmi co nejvíc sexy pózu. Bez ní nápověda neplatí.',
    icon: 'camera',
    audiences: _adult,
  ),
  RoundEvent(
    id: 'odhaleni',
    title: 'Sundej to',
    text: 'Kdo dostane nejvíc hlasů, sundá si jednu věc. Hodinky a ponožky se počítají.',
    icon: 'shirt',
    audiences: _adult,
    payoff: true,
  ),
  RoundEvent(
    id: 'rychle-rande',
    title: 'Speed dating',
    text: 'Diskuze jako rychlé rande. Každý má 10 vteřin, aby ostatní přesvědčil, že je nevinný.',
    icon: 'heart',
    audiences: _adult,
  ),
  RoundEvent(
    id: 'fant',
    title: 'Fant',
    text: 'Vítězové vymyslí poraženým fant. Nic, co by někdo nechtěl.',
    icon: 'gift',
    audiences: _adult,
    payoff: true,
  ),
];
