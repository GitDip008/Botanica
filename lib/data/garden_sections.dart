import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

// ── Garden centre ─────────────────────────────────────────────────────────────
// Oulu Botanical Garden (Oulun kasvitieteellinen puutarha), Linnanmaa campus.
// Centre placed between the systematic section and the greenhouses.
const gardenCenter = LatLng(65.06370, 25.46320);

// ── Note ──────────────────────────────────────────────────────────────────────
// Section coordinates verified from Google Maps (DMS → decimal). Facility
// coordinates (parking, toilets, bus, ponds) are still estimates relative to the
// verified sections — refine when convenient. 0.001° lat ≈ 111 m, lon ≈ 47 m.

class GardenSection {
  final String id;
  final String name;
  final String emoji;
  final String description;
  final String blooms;
  final LatLng location;
  final Color color;
  final bool isFacility; // parking, toilets, bus, ponds, gate

  const GardenSection({
    required this.id,
    required this.name,
    required this.emoji,
    required this.description,
    required this.blooms,
    required this.location,
    required this.color,
    this.isFacility = false,
  });
}

final List<GardenSection> gardenSections = [
  // ── South end — entrance area ─────────────────────────────────────────────
  GardenSection(
    id: 'entrance',
    name: 'Main Entrance',
    emoji: '🚪',
    description: 'Start here. Garden maps and info available near the gate.',
    blooms: 'Seasonal displays near gate',
    location: const LatLng(65.06310, 25.46540),
    color: Colors.grey,
  ),
  GardenSection(
    id: 'ornamental',
    name: 'Ornamental Section',
    emoji: '🌸',
    description:
        'Near the main gate. Peonies, tulips, irises, perennials and summer flowers in seasonal rotation.',
    blooms: 'Tulips, Peonies, Irises',
    location: const LatLng(65.062944, 25.463194),
    color: const Color(0xFF880E4F),
  ),

  // ── Greenhouses — central-south ───────────────────────────────────────────
  // Layout from official guide (Kasvihuoneopas, 2nd ed.):
  //   ROMEO (left wing) — AULA (entrance connecting hall) — JULIA (right wing)

  GardenSection(
    id: 'aula',
    name: 'Aula — Entrance Hall',
    emoji: '🚿',
    description:
        'The connecting entrance hall between Romeo and Julia. '
        'Home to the fern section (saniaiosasto) with lush tropical ferns, '
        'and the terrariums (terraariot) — miniature glass ecosystems with '
        'banana plants, bromeliads and mosses.',
    blooms: 'Ferns, Musa (banana), Tillandsia',
    location: const LatLng(65.063430, 25.465250),
    color: const Color(0xFF558B2F),
  ),

  GardenSection(
    id: 'romeo',
    name: 'Romeo Greenhouse',
    emoji: '🌴',
    description:
        '16 m glass pyramid — left wing. Three climate sections inside: '
        'Tropical (trooppinen), Subtropical Summer (subtrooppinen kesäisteiden) '
        'and Tropical continued. Temperature ~22–28 °C, high humidity. '
        'Highlights: Chocolate tree (Theobroma cacao), Coffee plant (Coffea), '
        'ancient Cycas palms, air plants (Tillandsia) and giant Ficus trees.',
    blooms: 'Theobroma cacao, Coffea, Cycas, Bromeliads, Ficus',
    location: const LatLng(65.063472, 25.464917),
    color: Colors.orange,
  ),

  // ROMEO internal sub-sections
  GardenSection(
    id: 'romeo_tropical',
    name: 'Romeo — Tropical Section',
    emoji: '🌿',
    description:
        'Trooppinen osasto. Humid tropical climate, 22–28 °C. '
        'Plants from the equatorial belt (±23° latitude). '
        'Look for the Chocolate tree, Coffee plant, Cycas (a living fossil '
        'unchanged since the dinosaurs), climbing Philodendrons and Bromeliads.',
    blooms: 'Theobroma cacao, Coffea arabica, Cycas revoluta',
    location: const LatLng(65.063510, 25.464850),
    color: const Color(0xFF2E7D32),
  ),
  GardenSection(
    id: 'romeo_subtropical',
    name: 'Romeo — Subtropical Summer',
    emoji: '☀️',
    description:
        'Subtrooppisten kesäisteiden osasto. Warm dry summers, mild winters. '
        'Mediterranean-style plants: Eucalyptus, Agapanthus (African blue lily), '
        'Passiflora (passion flower) and aromatic shrubs.',
    blooms: 'Eucalyptus, Agapanthus africanus, Passiflora',
    location: const LatLng(65.063440, 25.464820),
    color: const Color(0xFFF57F17),
  ),

  GardenSection(
    id: 'julia',
    name: 'Julia Greenhouse',
    emoji: '🌵',
    description:
        '14 m glass pyramid — right wing. Four climate sections: '
        'Subtropical Winter (talvisteiden), Succulents & Dry (sukkulentti), '
        'Temperate (lauhkea) and Subtropical Winter continued. '
        'Highlights: century-old cacti, Agave (blooms once in 100 years), '
        'Olive tree, Citrus, Peach tree and Magnolia.',
    blooms: 'Cacti, Agave, Olea europaea, Citrus, Magnolia',
    location: const LatLng(65.063389, 25.465583),
    color: Colors.teal,
  ),

  // JULIA internal sub-sections
  GardenSection(
    id: 'julia_subtropical_winter',
    name: 'Julia — Subtropical Winter',
    emoji: '🫒',
    description:
        'Subtrooppisten talvisteiden osasto. Mediterranean climate — cool wet winters, '
        'hot dry summers. Olive trees (Olea europaea), Citrus fruits, '
        'Pelargoniums (200+ species of geraniums), Lavender and Rosemary.',
    blooms: 'Olea europaea, Citrus, Pelargonium, Lavandula',
    location: const LatLng(65.063420, 25.465650),
    color: const Color(0xFF00695C),
  ),
  GardenSection(
    id: 'julia_succulents',
    name: 'Julia — Succulents & Dry',
    emoji: '🌵',
    description:
        'Sukkulentti- & kuivatyypin osasto. Arid desert climate. '
        'Cacti of all shapes, Agave americana (flowers once after ~100 years then dies), '
        'Aloe vera (medicinal gel), Opuntia (edible prickly pear) '
        'and Euphorbia (looks like cactus but is unrelated).',
    blooms: 'Cactaceae, Agave americana, Aloe vera, Opuntia',
    location: const LatLng(65.063360, 25.465680),
    color: const Color(0xFFE65100),
  ),
  GardenSection(
    id: 'julia_temperate',
    name: 'Julia — Temperate Section',
    emoji: '🌸',
    description:
        'Lauhkean ilmaston osasto. Cool temperate climate. '
        'Fruit trees that actually produce: Peach (Prunus persica), '
        'Pear (Pyrus communis), Apple (Malus domestica) and Cherry. '
        'Also Magnolia — one of Earth\'s oldest flowering plant lineages (95 million years old).',
    blooms: 'Magnolia, Prunus persica, Pyrus communis, Malus',
    location: const LatLng(65.063330, 25.465540),
    color: const Color(0xFF546E7A),
  ),

  // ── Central sections ──────────────────────────────────────────────────────
  GardenSection(
    id: 'medicinal',
    name: 'Medicinal & Economic Plants',
    emoji: '💊',
    description:
        'Herbs, dye plants, apple orchards. Fenced — please close the gate behind you (keeps hares out).',
    blooms: "Valerian, Chamomile, St John's Wort",
    location: const LatLng(65.064222, 25.463083),
    color: const Color(0xFFE65100),
  ),
  GardenSection(
    id: 'systematic',
    name: 'Systematic Section',
    emoji: '📚',
    description:
        'Plants ordered by botanical family and taxonomy — a living textbook of plant evolution.',
    blooms: 'Varies by family — follow the signs',
    location: const LatLng(65.064389, 25.461694),
    color: const Color(0xFF00695C),
  ),

  // ── North sections ────────────────────────────────────────────────────────
  GardenSection(
    id: 'fennoscandian',
    name: 'Fennoscandian Mountains',
    emoji: '⛰️',
    description:
        "Arctic-alpine plants from Scandinavia's mountain regions. Mountain avens, saxifrage, Lapland rhododendron.",
    blooms: 'Arctic Poppy, Mountain Avens, Cloudberry',
    location: const LatLng(65.063306, 25.461917),
    color: const Color(0xFF546E7A),
  ),
  GardenSection(
    id: 'grasslands',
    name: 'Grasslands & Meadows',
    emoji: '🌾',
    description:
        'Traditional Finnish meadow species, many rare in the wild due to modern agriculture.',
    blooms: 'Cowslip, Ox-eye Daisy, Meadow Cranesbill',
    location: const LatLng(65.064500, 25.462600),
    color: const Color(0xFF558B2F),
  ),
  GardenSection(
    id: 'woodlands',
    name: 'Woodlands',
    emoji: '🌳',
    description:
        'Native boreal forest — birch, pine, spruce and typical understory plants of Finnish forests.',
    blooms: 'Wood Anemone, May Lily, Wild Garlic',
    location: const LatLng(65.062800, 25.460800),
    color: const Color(0xFF1B5E20),
  ),

  // ── Lake shore — north-east ───────────────────────────────────────────────
  GardenSection(
    id: 'lake',
    name: 'Lake Kuivasjärvi Shore',
    emoji: '🌊',
    description:
        'Scenic lakeside walkway with over 4 km of paths. Great birdwatching in spring and summer.',
    blooms: 'Wetland plants, Water lilies',
    location: const LatLng(65.064800, 25.462800),
    color: Colors.cyan,
  ),

  // ── Additional sections from the official garden map ──────────────────────
  // ⚠️ Best-effort coordinates — replace with exact GPS from Google Maps.
  GardenSection(
    id: 'arboretum',
    name: 'Arboretum',
    emoji: '🌲',
    description:
        'A living collection of trees and shrubs from boreal and temperate regions — '
        'spruce, pine, larch, maple and rare conifers. Spreads across the western and '
        'southern edges of the garden.',
    blooms: 'Conifers, Maples, Rowan',
    location: const LatLng(65.062639, 25.460306),
    color: const Color(0xFF1B5E20),
  ),
  GardenSection(
    id: 'rhododendrons',
    name: 'Rhododendrons',
    emoji: '🌺',
    description:
        'Alppiruusut. A spectacular display of rhododendrons and azaleas — '
        'best visited in late spring/early summer when they burst into colour.',
    blooms: 'Rhododendron, Azalea (late spring)',
    // ⚠️ Doc gave same coord as native plants — nudged north toward the
    // Alppiruusut label. Replace with exact GPS when available.
    location: const LatLng(65.064700, 25.461300),
    color: const Color(0xFFAD1457),
  ),
  GardenSection(
    id: 'native_plants',
    name: 'Native Plants',
    emoji: '🍃',
    description:
        'Kotimaan kasvit. Finnish native species shown in natural-style plantings, '
        'near the heart of the garden.',
    blooms: 'Wood Cranesbill, Globeflower, Marsh Marigold',
    location: const LatLng(65.064139, 25.461556),
    color: const Color(0xFF33691E),
  ),

  // ── Facilities ────────────────────────────────────────────────────────────
  // ⚠️ Best-effort coordinates — replace with exact GPS from Google Maps.
  GardenSection(
    id: 'parking',
    name: 'Parking',
    emoji: '🅿️',
    description:
        'Visitor parking near the greenhouses (Kaitoväylä 5). Paid on weekdays '
        '8–16 (1 Aug–31 May); free otherwise. EV charging available.',
    blooms: '',
    location: const LatLng(65.063050, 25.465900),
    color: const Color(0xFF1565C0),
    isFacility: true,
  ),
  GardenSection(
    id: 'toilet_systematic',
    name: 'Toilets (Systematic)',
    emoji: '🚻',
    description: 'Public toilets near the systematic section.',
    blooms: '',
    location: const LatLng(65.064050, 25.462200),
    color: Colors.blueGrey,
    isFacility: true,
  ),
  GardenSection(
    id: 'toilet_greenhouse',
    name: 'Toilets (Greenhouses)',
    emoji: '🚻',
    description: 'Public toilets by the greenhouse entrance.',
    blooms: '',
    location: const LatLng(65.063550, 25.465100),
    color: Colors.blueGrey,
    isFacility: true,
  ),
  GardenSection(
    id: 'bus_stop',
    name: 'Bus Stop — Yliopiston puutarha',
    emoji: '🚌',
    description:
        'Bus stop at Kaitoväylä 5. Routes to Linnanmaa campus — check the City '
        'of Oulu public transport site for timetables.',
    blooms: '',
    location: const LatLng(65.062850, 25.466100),
    color: const Color(0xFF6A1B9A),
    isFacility: true,
  ),
  GardenSection(
    id: 'pond_west',
    name: 'Pond (West)',
    emoji: '🦆',
    description:
        'The larger central pond — home to water lilies and visiting waterfowl.',
    blooms: 'Water lilies, reeds',
    location: const LatLng(65.063700, 25.461400),
    color: Colors.cyan,
    isFacility: true,
  ),
  GardenSection(
    id: 'pond_south',
    name: 'Pond (South)',
    emoji: '🏞️',
    description: 'A smaller pond toward the southern path, near the ornamental beds.',
    blooms: 'Wetland margins',
    location: const LatLng(65.063100, 25.462000),
    color: Colors.cyan,
    isFacility: true,
  ),
];
