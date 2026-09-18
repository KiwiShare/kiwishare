export interface LocationSuggestion {
  name: string;
  category: 'campus' | 'transit' | 'suburb';
  city: string;
}

export const CAMPUS_LOCATIONS: LocationSuggestion[] = [
  // Universities & Campuses
  { name: 'University of Auckland (City Campus - General Library)', category: 'campus', city: 'Auckland' },
  { name: 'University of Auckland (City Campus - Kate Edger InfoCommons)', category: 'campus', city: 'Auckland' },
  { name: 'University of Auckland (City Campus - Science Building 303)', category: 'campus', city: 'Auckland' },
  { name: 'University of Auckland (City Campus - Engineering 401)', category: 'campus', city: 'Auckland' },
  { name: 'University of Auckland (Grafton Campus - Medical School)', category: 'campus', city: 'Auckland' },
  { name: 'University of Auckland (Newmarket Campus)', category: 'campus', city: 'Auckland' },
  { name: 'AUT City Campus (WG Building - Hikuwai Plaza)', category: 'campus', city: 'Auckland' },
  { name: 'AUT City Campus (WA Building Library)', category: 'campus', city: 'Auckland' },
  { name: 'AUT North Campus (Northcote)', category: 'campus', city: 'Auckland' },
  { name: 'AUT South Campus (Manukau)', category: 'campus', city: 'Auckland' },
  { name: 'Massey University (Albany Campus - Quad)', category: 'campus', city: 'Auckland' },
  { name: 'Unitec Mt Albert Campus (Te Puna)', category: 'campus', city: 'Auckland' },

  // Transit Hubs
  { name: 'Britomart Transport Centre (Queen St Entrance)', category: 'transit', city: 'Auckland' },
  { name: 'Newmarket Train Station (Broadway Entrance)', category: 'transit', city: 'Auckland' },
  { name: 'Grafton Train Station (Park Rd)', category: 'transit', city: 'Auckland' },
  { name: 'Auckland Town Hall (Aotea Square)', category: 'transit', city: 'Auckland' },
  { name: 'Civic Theatre / Wellesley St Bus Interchange', category: 'transit', city: 'Auckland' },
  { name: 'Sylvia Park Train Station', category: 'transit', city: 'Auckland' },

  // Suburbs & Public Spots
  { name: 'Auckland CBD (Queen Street / Commercial Bay)', category: 'suburb', city: 'Auckland' },
  { name: 'Ponsonby (Ponsonby Central)', category: 'suburb', city: 'Auckland' },
  { name: 'Parnell (Parnell Road Shops)', category: 'suburb', city: 'Auckland' },
  { name: 'Newmarket (Westfield Newmarket)', category: 'suburb', city: 'Auckland' },
  { name: 'Grafton / Domain Wintergardens', category: 'suburb', city: 'Auckland' },
  { name: 'Mount Eden Village', category: 'suburb', city: 'Auckland' },
  { name: 'Kingsland Station / New North Rd', category: 'suburb', city: 'Auckland' },
  { name: 'Takapuna Beach / Centre', category: 'suburb', city: 'Auckland' },
  { name: 'Albany Westfield Mall', category: 'suburb', city: 'Auckland' },
];

export function searchLocations(query: string, maxResults = 8): LocationSuggestion[] {
  const clean = query.trim().toLowerCase();
  if (!clean) return CAMPUS_LOCATIONS.slice(0, maxResults);
  return CAMPUS_LOCATIONS.filter((loc) =>
    loc.name.toLowerCase().includes(clean) || loc.city.toLowerCase().includes(clean)
  ).slice(0, maxResults);
}
