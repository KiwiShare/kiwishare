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
      suburbs: [
        'Nelson Central',
        'Tahunanui',
        'Stoke',
        'Atawhai',
      ],
    ),
    NzRegion(
      name: 'Tasman',
      code: 'TAS',
      suburbs: [
        'Richmond',
        'Motueka',
        'Mapua',
        'Takaka',
        'Golden Bay',
      ],
    ),
    NzRegion(
      name: 'Marlborough',
      code: 'MBH',
      suburbs: [
        'Blenheim Central',
        'Springlands',
        'Picton',
        'Renwick',
      ],
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
      suburbs: [
        'Gisborne Central',
        'Kaiti',
        'Mangapapa',
        'Whataupoko',
      ],
    ),
    NzRegion(
      name: 'West Coast',
      code: 'WTC',
      suburbs: [
        'Greymouth',
        'Westport',
        'Hokitika',
        'Runanga',
      ],
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
}
