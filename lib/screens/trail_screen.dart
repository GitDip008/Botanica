import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:permission_handler/permission_handler.dart';

// ─── Data ────────────────────────────────────────────────────────────────────

class _Stop {
  final int n;
  final String name;
  final String emoji;
  final String sectionName;      // human-readable area
  final LatLng location;
  final String navInstruction;   // how to walk there
  final String lookFor;          // what to find on arrival
  final String funFact;
  final int walkMinutesFromPrev; // 0 for first stop

  const _Stop({
    required this.n,
    required this.name,
    required this.emoji,
    required this.sectionName,
    required this.location,
    required this.navInstruction,
    required this.lookFor,
    required this.funFact,
    this.walkMinutesFromPrev = 0,
  });
}

class _Trail {
  final String name;
  final String emoji;
  final String duration;
  final String distance;
  final String description;
  final Color color;
  final List<_Stop> stops;

  const _Trail({
    required this.name,
    required this.emoji,
    required this.duration,
    required this.distance,
    required this.description,
    required this.color,
    required this.stops,
  });
}

// ─── Trail definitions ────────────────────────────────────────────────────────

final List<_Trail> _kTrails = [
  _Trail(
    name: 'Medicinal Plants Trail',
    emoji: '💊',
    duration: '45 min',
    distance: '1.2 km',
    color: const Color(0xFFE65100),
    description:
        'Explore plants used in Finnish traditional medicine — from ancient sleep remedies to modern antibiotics.',
    stops: [
      _Stop(
        n: 1,
        name: 'Valerian',
        emoji: '🌿',
        sectionName: 'Medicinal & Economic Section',
        location: const LatLng(65.0601, 25.4740),
        navInstruction:
            'Start at the main entrance gate. Walk straight along the central path for about 150 m. '
            'Turn left at the wooden sign "Medicinal & Economic Plants". The fenced section is on your right — '
            'open the gate and close it behind you (keeps the hares out!).',
        lookFor:
            'Look for tall, feathery stems up to 1.5 m high with clusters of tiny pale-pink flowers at the top. '
            'Crush a leaf gently — the earthy, slightly musty smell is unmistakeable.',
        funFact:
            'Valerian root has been used as a sleep aid since ancient Rome. '
            'Today it is still sold in Finnish pharmacies.',
        walkMinutesFromPrev: 0,
      ),
      _Stop(
        n: 2,
        name: "St. John's Wort",
        emoji: '🌼',
        sectionName: 'Medicinal & Economic Section',
        location: const LatLng(65.0602, 25.4742),
        navInstruction:
            'Stay inside the fenced area. Walk 20 m further along the right-hand border bed. '
            "St. John's Wort is two plots after the Valerian.",
        lookFor:
            'Bright yellow star-shaped flowers with tiny black dots around the petal edges. '
            'Hold a leaf up to the light — you will see translucent oil glands that look like tiny windows.',
        funFact:
            "Approved in Germany as a prescription antidepressant. Blooms around the Midsummer festival — "
            "hence the name St. John's (midsummer saint).",
        walkMinutesFromPrev: 1,
      ),
      _Stop(
        n: 3,
        name: 'Chamomile',
        emoji: '🌸',
        sectionName: 'Medicinal & Economic Section',
        location: const LatLng(65.0603, 25.4741),
        navInstruction:
            'Continue along the same border bed for another 15 m. Chamomile is at the corner of the bed, '
            'closest to the apple trees.',
        lookFor:
            'Small daisy-like flowers with white petals around a dome-shaped yellow centre. '
            'Kneel down — the apple-like scent at ground level is strong.',
        funFact:
            "One of Europe's most important medicinal herbs. Finnish grandmothers have brewed chamomile tea "
            'for upset stomachs for centuries.',
        walkMinutesFromPrev: 1,
      ),
      _Stop(
        n: 4,
        name: 'Arctic Cloudberry',
        emoji: '🍊',
        sectionName: 'Woodlands',
        location: const LatLng(65.0608, 25.4718),
        navInstruction:
            'Exit through the gate of the medicinal section and turn right. Follow the main path north for '
            'about 200 m until you see the treeline. Enter the Woodlands area — look for the low bog-like bed '
            'on the left just inside the forest edge.',
        lookFor:
            'A low creeping plant (10–25 cm tall) with roundish, crinkled leaves. '
            'In summer, ripe berries are amber-orange, one per stem. '
            'Earlier in the season, look for a single white flower per plant.',
        funFact:
            '"The gold of Lapland" — cloudberries are so prized in Finland that locals guard '
            'their secret picking spots fiercely.',
        walkMinutesFromPrev: 5,
      ),
      _Stop(
        n: 5,
        name: 'Wild Garlic',
        emoji: '🧄',
        sectionName: 'Woodlands',
        location: const LatLng(65.0609, 25.4717),
        navInstruction:
            'Stay in the Woodlands area. Walk 30 m deeper into the birch grove. '
            'Wild Garlic grows in a shaded patch near the small wooden bench.',
        lookFor:
            'Broad, bright-green lance-shaped leaves growing in clusters at ground level. '
            'Even before you see it, you may smell the gentle garlic aroma — especially after rain.',
        funFact:
            'Finnish forest people historically used wild garlic as a spring tonic after the long winter. '
            'It has stronger antibacterial compounds than cultivated garlic.',
        walkMinutesFromPrev: 2,
      ),
    ],
  ),

  _Trail(
    name: 'Arctic Plants Trail',
    emoji: '⛰️',
    duration: '30 min',
    distance: '0.8 km',
    color: const Color(0xFF546E7A),
    description:
        'Discover extraordinary plants that survive -40 °C, track the sun, and carpet the mountains of Lapland.',
    stops: [
      _Stop(
        n: 1,
        name: 'Lapland Rhododendron',
        emoji: '🪻',
        sectionName: 'Fennoscandian Mountain Section',
        location: const LatLng(65.0598, 25.4735),
        navInstruction:
            'From the main entrance, take the central path and continue past the ornamental beds. '
            'After about 200 m you will see a rocky raised mound on the right — that is the Fennoscandian '
            'Mountain Section. Climb the gentle slope.',
        lookFor:
            'A low woody shrub (40–60 cm) with small, dark evergreen leaves that curl under in winter. '
            'In May–June, vivid purple-pink flower clusters appear before the leaves fully open.',
        funFact:
            'Grows above the treeline in Lapland at altitudes up to 1 000 m. '
            'The flowers appear so early that they are often still dusted with snow.',
        walkMinutesFromPrev: 0,
      ),
      _Stop(
        n: 2,
        name: 'Arctic Poppy',
        emoji: '🌼',
        sectionName: 'Fennoscandian Mountain Section',
        location: const LatLng(65.0599, 25.4736),
        navInstruction:
            'Stay on the rocky mound. Walk 15 m to your right along the summit path. '
            'Arctic Poppy is in the open sunny patch between two granite boulders.',
        lookFor:
            'Delicate, tissue-paper-thin yellow or white petals on a single hairy stem. '
            'Watch the flower — it slowly rotates to face the sun throughout the day.',
        funFact:
            "Arctic Poppies track the sun (heliotropism) to create a warm microclimate inside the flower — "
            "raising the temperature by up to 10 °C to attract and reward pollinators.",
        walkMinutesFromPrev: 1,
      ),
      _Stop(
        n: 3,
        name: 'Mountain Avens',
        emoji: '🌸',
        sectionName: 'Fennoscandian Mountain Section',
        location: const LatLng(65.0599, 25.4737),
        navInstruction:
            'Continue 20 m along the rocky mound towards the north edge. '
            'Mountain Avens forms a mat just before the descent.',
        lookFor:
            'A creeping mat-forming plant with small, deeply lobed dark green leaves (white underneath). '
            'Eight-petalled white flowers, similar to a small rose. '
            'In autumn the feathery seed heads look like a silver cloud.',
        funFact:
            "Finland's national flower. Survives under snow at -40 °C and can live for over 100 years. "
            "It is the first plant to colonise bare ground after a glacier retreats.",
        walkMinutesFromPrev: 2,
      ),
      _Stop(
        n: 4,
        name: 'Cloudberry (Arctic Meadow)',
        emoji: '🍊',
        sectionName: 'Grasslands & Meadows',
        location: const LatLng(65.0605, 25.4725),
        navInstruction:
            'Descend from the rocky mound and turn left (west). Follow the gravel path about 100 m '
            'to the Grasslands & Meadows area — you will see open meadow ahead.',
        lookFor:
            'The same treasured cloudberry you may know from Finnish markets. '
            'Here it grows in its natural bog-meadow habitat alongside cowslip and ox-eye daisies.',
        funFact:
            'Finland exports cloudberry jam to Japan and Germany, where it fetches premium prices. '
            'A single plant produces only one berry per season.',
        walkMinutesFromPrev: 4,
      ),
    ],
  ),

  _Trail(
    name: 'Greenhouse Grand Tour',
    emoji: '🌴',
    duration: '40 min',
    distance: '0.4 km',
    color: const Color(0xFF795548),
    description:
        'The official route from the guide: Aula → Romeo (tropical & subtropical) '
        '→ Julia (Mediterranean, succulents & temperate). '
        '9 hand-picked highlights from the Kasvihuoneopas.',
    stops: [
      _Stop(
        n: 1,
        name: 'Aula — Ferns & Terrariums',
        emoji: '🌿',
        sectionName: 'Aula — Entrance Hall',
        location: const LatLng(65.0596, 25.4713),
        navInstruction:
            'Enter through the main greenhouse door. You are now in the Aula — '
            'the entrance hall connecting both glass pyramids. '
            'The fern section (saniaiosasto) is on your left, terrariums (terraariot) on your right.',
        lookFor:
            'Floor-to-ceiling ferns of dozens of species. In the glass terrariums, '
            'look for tiny banana plants (Musa) and Tillandsia air plants '
            'growing without any soil, fed entirely by the humid air.',
        funFact:
            'Ferns are among the oldest plant groups on Earth — they were already growing '
            'when dinosaurs first appeared, 360 million years ago.',
        walkMinutesFromPrev: 0,
      ),
      _Stop(
        n: 2,
        name: 'Chocolate Tree (Theobroma cacao)',
        emoji: '🍫',
        sectionName: 'Romeo — Tropical Section',
        location: const LatLng(65.0597, 25.4708),
        navInstruction:
            'Walk through the Aula into the Romeo greenhouse (left pyramid). '
            'The Chocolate tree is in the tropical section — follow signs for '
            'Trooppinen osasto. Look for the label "Theobroma cacao".',
        lookFor:
            'A small tree with large glossy leaves. The cocoa pods grow directly '
            'from the trunk and main branches (not from the tips) — an unusual growth '
            'pattern called cauliflory. Pods are large, ribbed and turn yellow or red when ripe.',
        funFact:
            'Every chocolate bar in the world starts here. The scientific name '
            '"Theobroma" means "food of the gods" in Greek. '
            'One tree produces enough beans for about 50 chocolate bars per year.',
        walkMinutesFromPrev: 2,
      ),
      _Stop(
        n: 3,
        name: 'Coffee Plant (Coffea)',
        emoji: '☕',
        sectionName: 'Romeo — Tropical Section',
        location: const LatLng(65.0597, 25.4708),
        navInstruction:
            'Stay in the tropical section. The Coffee plant is a few metres from '
            'the Chocolate tree — look for the small dark-green glossy shrub with a label "Coffea".',
        lookFor:
            'A shrub or small tree with very dark, waxy, oval leaves. '
            'In season, look for small white fragrant flowers or red "coffee cherry" fruits. '
            'Each cherry contains two coffee beans inside.',
        funFact:
            'Your morning coffee starts as a red berry on this plant. '
            'Coffee originated in Ethiopia — legend says a goat herder noticed his goats '
            'stayed awake all night after eating the berries.',
        walkMinutesFromPrev: 1,
      ),
      _Stop(
        n: 4,
        name: 'Cycas — The Dinosaur Plant',
        emoji: '🦕',
        sectionName: 'Romeo — Tropical Section',
        location: const LatLng(65.0597, 25.4709),
        navInstruction:
            'Still in the tropical section. Look for the stiff, feather-like palm '
            'with a very rough, armoured trunk — it resembles a small palm but is '
            'in an entirely different plant family. Label: Cycas revoluta.',
        lookFor:
            'A symmetrical crown of stiff, dark-green pinnate fronds radiating from '
            'a central trunk covered with old leaf bases. New fronds emerge from the centre '
            'curled like a fist, then slowly unfurl.',
        funFact:
            'This exact plant design has been unchanged for 200 million years — '
            'real dinosaurs walked past plants that looked identical to this one. '
            'It is one of the slowest-growing plants on Earth, adding one ring of leaves per year.',
        walkMinutesFromPrev: 1,
      ),
      _Stop(
        n: 5,
        name: 'Eucalyptus',
        emoji: '🐨',
        sectionName: 'Romeo — Subtropical Summer',
        location: const LatLng(65.0598, 25.4708),
        navInstruction:
            'Move into the subtropical summer section of Romeo '
            '(Subtrooppinen kesäisteiden osasto). '
            'The Eucalyptus is one of the tallest plants — look up.',
        lookFor:
            'Long, narrow, blue-grey leaves that hang vertically (not horizontally) '
            'to reduce sun exposure. Crush a leaf gently between your fingers — '
            'the strong menthol-like scent is unmistakeable.',
        funFact:
            'Koalas eat almost nothing else. Eucalyptus leaves are toxic to most animals '
            'but koalas evolved a specialised liver to detoxify them. '
            'It is also one of the fastest-growing trees on the planet.',
        walkMinutesFromPrev: 2,
      ),
      _Stop(
        n: 6,
        name: 'Julia — Olive Tree (Olea europaea)',
        emoji: '🫒',
        sectionName: 'Julia — Subtropical Winter',
        location: const LatLng(65.0597, 25.4718),
        navInstruction:
            'Walk back through the Aula and into the Julia greenhouse (right pyramid). '
            'Enter the subtropical winter section (Subtrooppinen talvisteiden osasto). '
            'The Olive tree is one of the largest specimens — look for the gnarled, '
            'twisted grey trunk.',
        lookFor:
            'Silver-green narrow leaves, extremely gnarled and twisted grey trunk. '
            'In season, small black or green olives may be visible on the branches.',
        funFact:
            'Some olive trees alive today were growing during the Roman Empire — '
            'over 2 000 years old. The oldest known olive tree in the world is on Crete '
            'and is estimated to be 3 000 years old, still producing olives.',
        walkMinutesFromPrev: 3,
      ),
      _Stop(
        n: 7,
        name: 'Agave — The Century Plant',
        emoji: '🌵',
        sectionName: 'Julia — Succulents & Dry',
        location: const LatLng(65.0596, 25.4718),
        navInstruction:
            'Move into the succulent and dry section of Julia '
            '(Sukkulentti- & kuivatyypin osasto). '
            'The Agave is one of the largest rosette plants — sharp spine-tipped leaves.',
        lookFor:
            'A huge rosette of thick, fleshy, grey-green leaves each tipped with a sharp '
            'dark spine. The leaves can be over a metre long. '
            'Look for the fibrous texture — the Aztecs used it to make rope.',
        funFact:
            'The Agave flowers only ONCE in its entire life — after 80 to 100 years — '
            'sending up a flower spike up to 8 metres tall, then dies. '
            'That is why it is called the "century plant". Tequila is also made from Agave.',
        walkMinutesFromPrev: 1,
      ),
      _Stop(
        n: 8,
        name: 'Magnolia',
        emoji: '🌸',
        sectionName: 'Julia — Temperate Section',
        location: const LatLng(65.0595, 25.4717),
        navInstruction:
            'Walk to the temperate section of Julia (Lauhkean ilmaston osasto). '
            'The Magnolia is among the largest trees in this section.',
        lookFor:
            'Large, waxy, cup-shaped flowers — white to pale pink — that appear before '
            'or alongside the large, glossy leaves. The flowers have a subtle lemony scent.',
        funFact:
            'Magnolias are one of the most ancient flowering plant lineages on Earth — '
            '95 million years old. They evolved before bees existed, so they are '
            'pollinated by beetles instead. Their flowers have no nectar tubes — '
            'beetles simply crawl inside.',
        walkMinutesFromPrev: 2,
      ),
      _Stop(
        n: 9,
        name: 'Peach Tree (Prunus persica)',
        emoji: '🍑',
        sectionName: 'Julia — Temperate Section',
        location: const LatLng(65.0595, 25.4717),
        navInstruction:
            'Stay in the temperate section. The Peach tree is nearby the Magnolia — '
            'look for the long, narrow, lance-shaped leaves and the label "Prunus persica".',
        lookFor:
            'A small tree with narrow, pointed leaves and, in season, actual peaches. '
            'In spring, look for delicate pink five-petalled blossoms before the leaves appear.',
        funFact:
            'The name "persica" means "from Persia" — Europeans first encountered peaches '
            'when Alexander the Great brought them from Persia. '
            'But they actually originate in China, where they have been cultivated for 4 000 years.',
        walkMinutesFromPrev: 1,
      ),
    ],
  ),
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class TrailScreen extends StatefulWidget {
  const TrailScreen({super.key});

  @override
  State<TrailScreen> createState() => _TrailScreenState();
}

class _TrailScreenState extends State<TrailScreen> {
  _Trail? _activeTrail;
  int _currentStop = 0;

  // GPS
  StreamSubscription<Position>? _posStream;
  LatLng? _userPos;
  bool _gpsActive = false;

  @override
  void initState() {
    super.initState();
    _startGps();
  }

  Future<void> _startGps() async {
    // Check location service is on (device-level GPS toggle)
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _gpsActive = false);
      return;
    }

    final status = await Permission.location.request();
    if (!status.isGranted) {
      if (mounted) setState(() => _gpsActive = false);
      return;
    }

    // One-shot first fix — mark GPS active as soon as we get a position
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      if (mounted) {
        setState(() {
          _userPos = LatLng(pos.latitude, pos.longitude);
          _gpsActive = true; // ← was missing, caused "No GPS" even when working
        });
      }
    } catch (_) {}

    // Continuous stream updates
    _posStream?.cancel();
    _posStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high, distanceFilter: 3),
    ).listen((pos) {
      if (mounted) {
        setState(() {
          _userPos = LatLng(pos.latitude, pos.longitude);
          _gpsActive = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _posStream?.cancel();
    super.dispose();
  }

  double? _distanceTo(LatLng target) {
    if (_userPos == null) return null;
    return const Distance().as(LengthUnit.Meter, _userPos!, target);
  }

  bool _hasArrived(LatLng target) {
    final d = _distanceTo(target);
    return d != null && d < 15;
  }

  String _distanceLabel(LatLng target) {
    final d = _distanceTo(target);
    if (d == null) return '📡 Locating…';
    if (d < 15) return '✅ You have arrived!';
    if (d < 50) return '🟢 ${d.toInt()} m — very close!';
    if (d < 200) return '🟡 ${d.toInt()} m — keep walking';
    return '🔴 ${d.toInt()} m away';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2E1E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF66BB6A)),
          onPressed: _activeTrail != null
              ? () => setState(() {
                    _activeTrail = null;
                    _currentStop = 0;
                  })
              : () => Navigator.pop(context),
        ),
        title: Text(
          _activeTrail != null ? _activeTrail!.name : '🥾 Self-Guided Trails',
          style: const TextStyle(
              color: Color(0xFFE8F5E9),
              fontWeight: FontWeight.bold,
              fontSize: 15),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          GestureDetector(
            onTap: _gpsActive ? null : _startGps, // tap to retry when no GPS
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _gpsActive ? Icons.gps_fixed : Icons.gps_not_fixed,
                    color: _gpsActive ? Colors.greenAccent : Colors.orange,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _gpsActive ? 'Live GPS' : 'Tap — No GPS',
                    style: TextStyle(
                      color: _gpsActive ? Colors.greenAccent : Colors.orange,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _activeTrail != null ? _buildActiveTrail() : _buildTrailList(),
    );
  }

  // ── Trail list ─────────────────────────────────────────────────────────────

  Widget _buildTrailList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _kTrails.length,
      itemBuilder: (_, i) {
        final t = _kTrails[i];
        return GestureDetector(
          onTap: () => setState(() {
            _activeTrail = t;
            _currentStop = 0;
          }),
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2E1E),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: t.color.withOpacity(0.6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(t.emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.name,
                              style: const TextStyle(
                                  color: Color(0xFFE8F5E9),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _Chip(
                                  icon: Icons.timer,
                                  label: t.duration,
                                  color: t.color),
                              const SizedBox(width: 8),
                              _Chip(
                                  icon: Icons.route,
                                  label: t.distance,
                                  color: t.color),
                              const SizedBox(width: 8),
                              _Chip(
                                  icon: Icons.flag,
                                  label: '${t.stops.length} stops',
                                  color: t.color),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: t.color),
                  ],
                ),
                const SizedBox(height: 10),
                Text(t.description,
                    style: const TextStyle(
                        color: Color(0xFF4CAF50), fontSize: 13, height: 1.4)),
              ],
            ),
          )
              .animate()
              .slideX(
                  begin: -0.2,
                  duration: 350.ms,
                  delay: Duration(milliseconds: i * 80)),
        );
      },
    );
  }

  // ── Active trail ───────────────────────────────────────────────────────────

  Widget _buildActiveTrail() {
    final trail = _activeTrail!;
    final stop = trail.stops[_currentStop];
    final isFirst = _currentStop == 0;
    final isLast = _currentStop == trail.stops.length - 1;
    final arrived = _hasArrived(stop.location);

    return Column(
      children: [
        // ── Progress header ──
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          color: const Color(0xFF1A2E1E),
          child: Column(
            children: [
              Row(
                children: List.generate(trail.stops.length, (i) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 4,
                      decoration: BoxDecoration(
                        color: i <= _currentStop
                            ? trail.color
                            : trail.color.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Stop ${_currentStop + 1} of ${trail.stops.length}',
                    style: TextStyle(color: trail.color, fontSize: 12),
                  ),
                  if (stop.walkMinutesFromPrev > 0)
                    Text(
                      '🚶 ~${stop.walkMinutesFromPrev} min walk from previous stop',
                      style: const TextStyle(
                          color: Color(0xFF4CAF50), fontSize: 11),
                    ),
                ],
              ),
            ],
          ),
        ),

        // ── Scrollable content ──
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── GPS Distance badge ──
                AnimatedContainer(
                  duration: const Duration(milliseconds: 400),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: arrived
                        ? Colors.green[900]!.withOpacity(0.4)
                        : const Color(0xFF1A2E1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: arrived
                          ? Colors.greenAccent
                          : trail.color.withOpacity(0.4),
                      width: arrived ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        arrived
                            ? Icons.check_circle
                            : Icons.navigation_outlined,
                        color: arrived ? Colors.greenAccent : trail.color,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _distanceLabel(stop.location),
                          style: TextStyle(
                            color:
                                arrived ? Colors.greenAccent : Colors.white70,
                            fontSize: 14,
                            fontWeight: arrived
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Stop header ──
                Row(
                  children: [
                    Text(stop.emoji,
                        style: const TextStyle(fontSize: 36))
                        .animate()
                        .scale(duration: 400.ms),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stop.name,
                            style: const TextStyle(
                              color: Color(0xFFE8F5E9),
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ).animate().fadeIn(duration: 300.ms),
                          const SizedBox(height: 2),
                          Text(
                            '📍 ${stop.sectionName}',
                            style: TextStyle(
                                color: trail.color, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ── Navigation card ──
                _SectionCard(
                  icon: Icons.directions_walk,
                  title: 'How to get there',
                  body: stop.navInstruction,
                  color: trail.color,
                ),

                const SizedBox(height: 12),

                // ── Look for card ──
                _SectionCard(
                  icon: Icons.search,
                  title: 'What to look for',
                  body: stop.lookFor,
                  color: const Color(0xFF66BB6A),
                ),

                const SizedBox(height: 12),

                // ── Fun fact card ──
                _SectionCard(
                  icon: Icons.lightbulb_outline,
                  title: 'Did you know?',
                  body: stop.funFact,
                  color: const Color(0xFF4CAF50),
                ),

                const SizedBox(height: 20),

                // ── Navigation buttons ──
                Row(
                  children: [
                    if (!isFirst)
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: trail.color,
                            side: BorderSide(color: trail.color),
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () =>
                              setState(() => _currentStop--),
                          child: const Text('← Previous'),
                        ),
                      ),
                    if (!isFirst) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: trail.color,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: isLast
                            ? () => setState(() {
                                  _activeTrail = null;
                                  _currentStop = 0;
                                })
                            : () => setState(() => _currentStop++),
                        child: Text(
                            isLast ? 'Finish Trail ✅' : 'Next Stop →'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Helper widgets ───────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Color color;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2E1E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
                color: Color(0xFFE8F5E9), fontSize: 14, height: 1.6),
          ),
        ],
      ),
    ).animate().slideY(begin: 0.1, duration: 300.ms);
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }
}
