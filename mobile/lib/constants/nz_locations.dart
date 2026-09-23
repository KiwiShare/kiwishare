import 'package:flutter/foundation.dart';

@immutable
class NzRegion {
  final String name;
  final String code;
  final List<String> suburbs;

  const NzRegion({
    required this.name,
    required this.code,
    required this.suburbs,
  });
}

class NzLocations {
  NzLocations._();

  static const String defaultLocation = 'Auckland CBD';
  static const String allNzLabel = 'All NZ';

  static const List<NzRegion> regions = [
    NzRegion(
      name: 'Auckland',
      code: 'AUK',
      suburbs: [
        'Auckland CBD',
        'Newmarket',
        'Ponsonby',
        'Parnell',
        'Mount Eden',
        'Grey Lynn',
        'Mount Albert',
        'Epsom',
        'Remuera',
        'Takapuna',
        'Devonport',
        'Albany',
        'Northcote',
        'Birkenhead',
        'Henderson',
        'Westgate',
        'New Lynn',
        'Manukau',
        'Botany Downs',
        'Flat Bush',
        'Howick',
        'Papakura',
        'Pukekohe',
        'Silverdale',
        'Whangaparaoa',
      ],
    ),
    NzRegion(
      name: 'Wellington',
      code: 'WGN',
      suburbs: [
        'Wellington Central',
        'Te Aro',
        'Thorndon',
        'Kelburn',
        'Newtown',
        'Mount Victoria',
        'Karori',
        'Island Bay',
        'Miramar',
        'Johnsonville',
        'Lower Hutt Central',
        'Petone',
        'Upper Hutt',
        'Porirua',
        'Kapiti Coast',
      ],
    ),
    NzRegion(
      name: 'Canterbury',
      code: 'CAN',
      suburbs: [
        'Christchurch Central',
        'Riccarton',
        'Ilam',
        'Merivale',
        'Papanui',
        'Fendalton',
        'Addington',
        'Sydenham',
        'Hornby',
        'Rangiora',
        'Kaiapoi',
        'Rolleston',
        'Ashburton',
        'Timaru',
      ],
    ),
    NzRegion(
      name: 'Waikato',
      code: 'WKO',
      suburbs: [
        'Hamilton Central',
        'Hamilton East',
        'Te Rapa',
        'Chartwell',
        'Frankton',
        'Cambridge',
        'Te Awamutu',
        'Huntly',
        'Taupō',
        'Matamata',
      ],
    ),
    NzRegion(
      name: 'Bay of Plenty',
      code: 'BOP',
      suburbs: [
        'Tauranga Central',
        'Mount Maunganui',
        'Papamoa',
        'Bethlehem',
        'Greerton',
        'Rotorua Central',
        'Rotorua East',
        'Whakatāne',
      ],
    ),
    NzRegion(
      name: 'Otago',
      code: 'OTA',
      suburbs: [
        'Dunedin Central',
        'North Dunedin',
        'South Dunedin',
        'Mornington',
        'Mosgiel',
        'Queenstown',
        'Frankton',
        'Arrowtown',
        'Wanaka',
        'Oamaru',
      ],
    ),
    NzRegion(
      name: 'Hawke\'s Bay',
      code: 'HKB',
      suburbs: [
        'Napier Central',
        'Napier South',
        'Taradale',
        'Hastings',
        'Havelock North',
        'Flaxmere',
      ],
    ),
    NzRegion(
      name: 'Taranaki',
      code: 'TKI',
      suburbs: [
        'New Plymouth Central',
        'Strandon',
        'Fitzroy',
        'Bell Block',
        'Hawera',
        'Stratford',
      ],
    ),
    NzRegion(
      name: 'Manawatū-Whanganui',
      code: 'MWT',
      suburbs: [
        'Palmerston North Central',
        'Kelvin Grove',
        'Hokowhitu',
        'Whanganui Central',
        'Feilding',
        'Levin',
      ],
    ),
    NzRegion(
      name: 'Northland',
      code: 'NTL',
      suburbs: [
        'Whangārei Central',
        'Kamo',
        'Tikipunga',
        'Kerikeri',
        'Paihia',
        'Kaitaia',
        'Dargaville',
      ],
    ),
    NzRegion(
      name: 'Nelson',
      code: 'NSN',
      suburbs: ['Nelson Central', 'Tahunanui', 'Stoke', 'Atawhai'],
    ),
    NzRegion(
      name: 'Tasman',
      code: 'TAS',
      suburbs: ['Richmond', 'Motueka', 'Mapua', 'Takaka', 'Golden Bay'],
    ),
    NzRegion(
      name: 'Marlborough',
      code: 'MBH',
      suburbs: ['Blenheim Central', 'Springlands', 'Picton', 'Renwick'],
    ),
    NzRegion(
      name: 'Southland',
      code: 'STL',
      suburbs: [
        'Invercargill Central',
        'Gladstone',
        'Hargest',
        'Gore',
        'Te Anau',
        'Winton',
      ],
    ),
    NzRegion(
      name: 'Gisborne',
      code: 'GIS',
      suburbs: ['Gisborne Central', 'Kaiti', 'Mangapapa', 'Whataupoko'],
    ),
    NzRegion(
      name: 'West Coast',
      code: 'WTC',
      suburbs: ['Greymouth', 'Westport', 'Hokitika', 'Runanga'],
    ),
  ];

  static List<String> getSuburbsForRegion(String regionName) {
    for (final reg in regions) {
      if (reg.name.toLowerCase() == regionName.toLowerCase()) {
        return reg.suburbs;
      }
    }
    return const [];
  }

  static String? findRegionForSuburb(String suburbName) {
    final needle = suburbName.toLowerCase().trim();
    for (final reg in regions) {
      if (reg.name.toLowerCase() == needle) return reg.name;
      for (final s in reg.suburbs) {
        if (s.toLowerCase() == needle) {
          return reg.name;
        }
      }
    }
    return null;
  }

  static List<Map<String, String>> searchLocations(String query) {
    final clean = query.toLowerCase().trim();
    if (clean.isEmpty) return const [];

    final results = <Map<String, String>>[];
    for (final reg in regions) {
      if (reg.name.toLowerCase().contains(clean)) {
        results.add({
          'display': reg.name,
          'region': reg.name,
          'suburb': '',
          'type': 'Region',
        });
      }
      for (final suburb in reg.suburbs) {
        if (suburb.toLowerCase().contains(clean)) {
          results.add({
            'display': '$suburb, ${reg.name}',
            'region': reg.name,
            'suburb': suburb,
            'type': 'Suburb',
          });
        }
      }
    }
    return results;
  }

  static const Map<String, NzCoordinates> _coordinatesMap = {
    'auckland': NzCoordinates(-36.8485, 174.7633),
    'auckland cbd': NzCoordinates(-36.8485, 174.7633),
    'newmarket': NzCoordinates(-36.8687, 174.7770),
    'ponsonby': NzCoordinates(-36.8524, 174.7431),
    'parnell': NzCoordinates(-36.8560, 174.7820),
    'mount eden': NzCoordinates(-36.8797, 174.7645),
    'grey lynn': NzCoordinates(-36.8614, 174.7391),
    'mount albert': NzCoordinates(-36.8837, 174.7186),
    'epsom': NzCoordinates(-36.8906, 174.7708),
    'remuera': NzCoordinates(-36.8821, 174.8016),
    'takapuna': NzCoordinates(-36.7885, 174.7731),
    'devonport': NzCoordinates(-36.8300, 174.7960),
    'albany': NzCoordinates(-36.7297, 174.7003),
    'northcote': NzCoordinates(-36.8040, 174.7500),
    'birkenhead': NzCoordinates(-36.8150, 174.7270),
    'henderson': NzCoordinates(-36.8800, 174.6290),
    'westgate': NzCoordinates(-36.8200, 174.6140),
    'new lynn': NzCoordinates(-36.9080, 174.6850),
    'manukau': NzCoordinates(-36.9930, 174.8778),
    'botany downs': NzCoordinates(-36.9280, 174.9120),
    'flat bush': NzCoordinates(-36.9650, 174.9080),
    'howick': NzCoordinates(-36.8950, 174.9350),
    'papakura': NzCoordinates(-37.0650, 174.9450),
    'pukekohe': NzCoordinates(-37.2000, 174.9000),
    'silverdale': NzCoordinates(-36.6180, 174.6700),
    'whangaparaoa': NzCoordinates(-36.6340, 174.8350),

    'wellington': NzCoordinates(-41.2865, 174.7762),
    'wellington central': NzCoordinates(-41.2865, 174.7762),
    'te aro': NzCoordinates(-41.2936, 174.7762),
    'thorndon': NzCoordinates(-41.2720, 174.7770),
    'kelburn': NzCoordinates(-41.2860, 174.7640),
    'newtown': NzCoordinates(-41.3140, 174.7810),
    'mount victoria': NzCoordinates(-41.2990, 174.7920),
    'karori': NzCoordinates(-41.2860, 174.7330),
    'island bay': NzCoordinates(-41.3410, 174.7730),
    'miramar': NzCoordinates(-41.3150, 174.8210),
    'johnsonville': NzCoordinates(-41.2220, 174.8080),
    'lower hutt central': NzCoordinates(-41.2092, 174.9080),
    'petone': NzCoordinates(-41.2250, 174.8700),
    'upper hutt': NzCoordinates(-41.1240, 175.0700),
    'porirua': NzCoordinates(-41.1340, 174.8400),
    'kapiti coast': NzCoordinates(-40.9000, 175.0000),

    'canterbury': NzCoordinates(-43.5321, 172.6362),
    'christchurch': NzCoordinates(-43.5321, 172.6362),
    'christchurch central': NzCoordinates(-43.5321, 172.6362),
    'riccarton': NzCoordinates(-43.5283, 172.5936),
    'ilam': NzCoordinates(-43.5220, 172.5760),
    'merivale': NzCoordinates(-43.5130, 172.6240),
    'papanui': NzCoordinates(-43.4920, 172.6070),
    'fendalton': NzCoordinates(-43.5150, 172.5980),
    'addington': NzCoordinates(-43.5430, 172.6100),
    'sydenham': NzCoordinates(-43.5470, 172.6380),
    'hornby': NzCoordinates(-43.5430, 172.5250),
    'rangiora': NzCoordinates(-43.3030, 172.5960),
    'rolleston': NzCoordinates(-43.5930, 172.3830),
    'ashburton': NzCoordinates(-43.8990, 171.7480),
    'timaru': NzCoordinates(-44.3970, 171.2550),

    'waikato': NzCoordinates(-37.7870, 175.2793),
    'hamilton': NzCoordinates(-37.7870, 175.2793),
    'hamilton central': NzCoordinates(-37.7870, 175.2793),
    'hamilton east': NzCoordinates(-37.7890, 175.2950),
    'cambridge': NzCoordinates(-37.8900, 175.4670),
    'te awamutu': NzCoordinates(-38.0100, 175.3250),
    'taupo': NzCoordinates(-38.6860, 176.0700),

    'bay of plenty': NzCoordinates(-37.6878, 176.1651),
    'tauranga': NzCoordinates(-37.6878, 176.1651),
    'tauranga central': NzCoordinates(-37.6878, 176.1651),
    'mount maunganui': NzCoordinates(-37.6433, 176.1856),
    'papamoa': NzCoordinates(-37.7120, 176.2890),
    'rotorua central': NzCoordinates(-38.1368, 176.2497),

    'otago': NzCoordinates(-45.8788, 170.5028),
    'dunedin': NzCoordinates(-45.8788, 170.5028),
    'dunedin central': NzCoordinates(-45.8788, 170.5028),
    'north dunedin': NzCoordinates(-45.8640, 170.5180),
    'queenstown': NzCoordinates(-45.0312, 168.6626),
    'queenstown central': NzCoordinates(-45.0312, 168.6626),
    'wanaka': NzCoordinates(-44.7032, 169.1321),

    'hawke\'s bay': NzCoordinates(-39.4928, 176.9120),
    'napier central': NzCoordinates(-39.4928, 176.9120),
    'hastings central': NzCoordinates(-39.6390, 176.8490),
    'manawatu-whanganui': NzCoordinates(-40.3523, 175.6082),
    'palmerston north central': NzCoordinates(-40.3523, 175.6082),
    'whanganui central': NzCoordinates(-39.9300, 175.0500),
    'nelson': NzCoordinates(-41.2706, 173.2840),
    'nelson central': NzCoordinates(-41.2706, 173.2840),
    'northland': NzCoordinates(-35.7275, 174.3166),
    'whangarei central': NzCoordinates(-35.7275, 174.3166),
    'taranaki': NzCoordinates(-39.0556, 174.0752),
    'new plymouth central': NzCoordinates(-39.0556, 174.0752),
    'southland': NzCoordinates(-46.4132, 168.3538),
    'invercargill central': NzCoordinates(-46.4132, 168.3538),
    'marlborough': NzCoordinates(-41.5134, 173.9612),
    'blenheim central': NzCoordinates(-41.5134, 173.9612),
    'gisborne': NzCoordinates(-38.6623, 178.0176),
    'gisborne central': NzCoordinates(-38.6623, 178.0176),
    'west coast': NzCoordinates(-42.4504, 171.2081),
    'greymouth': NzCoordinates(-42.4504, 171.2081),
  };

  static NzCoordinates? getApproximateCoordinates(String locationName) {
    final clean = locationName.toLowerCase().trim();
    if (_coordinatesMap.containsKey(clean)) {
      return _coordinatesMap[clean];
    }
    // Try matching without suburb or suffix
    for (final entry in _coordinatesMap.entries) {
      if (clean.contains(entry.key) || entry.key.contains(clean)) {
        return entry.value;
      }
    }
    // Fallback: check parent region
    final parentRegion = findRegionForSuburb(locationName);
    if (parentRegion != null) {
      final regKey = parentRegion.toLowerCase();
      if (_coordinatesMap.containsKey(regKey)) {
        return _coordinatesMap[regKey];
      }
    }
    return null;
  }
}

class NzCoordinates {
  final double latitude;
  final double longitude;
  const NzCoordinates(this.latitude, this.longitude);
}
