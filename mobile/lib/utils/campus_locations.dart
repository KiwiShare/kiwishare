/// Curated dataset of Auckland / New Zealand university campuses, student hubs,
/// transit hubs, and suburbs used for location autocomplete in posting items and scheduling meetups.
class CampusLocations {
  CampusLocations._();

  static const List<String> suggestions = [
    // University of Auckland (UoA) Campuses & Hubs
    'UoA Student Hub (Alfred Nathan House)',
    'UoA General Library (5 Alfred St)',
    'UoA Science Centre (Building 303)',
    'UoA Engineering Quad (20 Symonds St)',
    'UoA Kate Edger Information Commons (KEIC)',
    'UoA ClockTower Quad (22 Princes St)',
    'UoA Grafton Campus (Medical School, Park Rd)',
    'UoA Newmarket Campus (Khyber Pass Rd)',
    'UoA Epsom Campus (Gate 3, Epsom Ave)',
    'UoA Waipāpā Marae (Wynyard St)',

    // AUT Campuses
    'AUT City Campus (WG Hikuwai Plaza)',
    'AUT City Campus (WT Building)',
    'AUT City Campus Library (WA Building)',
    'AUT South Campus (Manukau)',
    'AUT North Campus (Akoranga Dr, Northcote)',

    // Massey & Other University Hubs
    'Massey University Auckland Campus (Albany)',
    'University of Otago (Auckland Centre, Queen St)',

    // Auckland Public Transit Hubs & Landmarks
    'Britomart Transport Centre (Queen St)',
    'Commercial Bay (Queen & Customs St)',
    'Aotea Square (Queen St)',
    'Albert Park (Princes St)',
    'Newmarket Westfield (Broadway)',
    'Sylvia Park Shopping Centre (Mt Wellington)',
    'St Lukes Westfield (St Lukes Rd)',
    'LynnMall Shopping Centre (New Lynn)',
    'Albany Westfield (North Shore)',
    'Manukau Supa Centa',
    'Ponsonby Central (Ponsonby Rd)',
    'Takapuna Centre (Hurstmere Rd)',

    // Auckland Suburbs
    'Auckland Central',
    'Grafton',
    'Newmarket',
    'Parnell',
    'Ponsonby',
    'Mount Eden',
    'Kingsland',
    'Grey Lynn',
    'Epsom',
    'Remuera',
    'Mount Albert',
    'Greenlane',
    'Onehunga',
    'Takapuna',
    'Albany',
    'Henderson',
    'New Lynn',
    'Botany Downs',
    'Manukau Central',

    // Major NZ Cities / Centres
    'Hamilton Central',
    'Wellington Central',
    'Christchurch Central',
    'Dunedin Central',
  ];

  /// Returns matching locations for the given query string (case-insensitive).
  static List<String> search(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      return suggestions.take(8).toList();
    }
    return suggestions
        .where((loc) => loc.toLowerCase().contains(clean))
        .take(8)
        .toList();
  }
}
