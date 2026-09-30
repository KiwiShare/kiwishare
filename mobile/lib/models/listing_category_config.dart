enum ListingAttributeInputType { text, number, choice, date, year }

class ListingAttributeField {
  const ListingAttributeField({
    required this.key,
    required this.label,
    this.hint,
    this.type = ListingAttributeInputType.text,
    this.options = const [],
    this.required = false,
    this.unit,
    this.min,
    this.max,
  });

  final String key;
  final String label;
  final String? hint;
  final ListingAttributeInputType type;
  final List<String> options;
  final bool required;
  final String? unit;
  final num? min;
  final num? max;
}

class ListingCategoryDefinition {
  const ListingCategoryDefinition({
    required this.name,
    required this.subtitle,
    this.attributes = const [],
  });

  final String name;
  final String subtitle;
  final List<ListingAttributeField> attributes;
}

const listingCategoryDefinitions = <ListingCategoryDefinition>[
  ListingCategoryDefinition(
    name: 'Furniture',
    subtitle: 'Desks, chairs, beds, sofas and storage',
    attributes: [
      ListingAttributeField(
        key: 'material',
        label: 'Material',
        hint: 'e.g. Solid wood',
      ),
      ListingAttributeField(
        key: 'dimensions',
        label: 'Dimensions',
        hint: 'e.g. 120 × 60 × 75 cm',
      ),
      ListingAttributeField(
        key: 'brand',
        label: 'Brand / maker',
        hint: 'Optional',
      ),
    ],
  ),
  ListingCategoryDefinition(
    name: 'Electronics',
    subtitle: 'Computers, phones, audio and appliances',
    attributes: [
      ListingAttributeField(
        key: 'brand',
        label: 'Brand',
        hint: 'e.g. Apple, Dell',
      ),
      ListingAttributeField(
        key: 'model',
        label: 'Model',
        hint: 'e.g. MacBook Air M2',
      ),
      ListingAttributeField(
        key: 'storage',
        label: 'Storage / capacity',
        hint: 'e.g. 256 GB',
      ),
    ],
  ),
  ListingCategoryDefinition(
    name: 'Books',
    subtitle: 'Textbooks, novels and reference books',
    attributes: [
      ListingAttributeField(
        key: 'author',
        label: 'Author',
        hint: 'e.g. James Clear',
      ),
      ListingAttributeField(key: 'isbn', label: 'ISBN', hint: 'Optional'),
      ListingAttributeField(
        key: 'edition',
        label: 'Edition',
        hint: 'e.g. 4th edition',
      ),
    ],
  ),
  ListingCategoryDefinition(
    name: 'Home',
    subtitle: 'Homeware, decor and household essentials',
    attributes: [
      ListingAttributeField(
        key: 'room',
        label: 'Best for',
        type: ListingAttributeInputType.choice,
        options: [
          'Kitchen',
          'Bedroom',
          'Living',
          'Bathroom',
          'Laundry',
          'Garden',
          'Other',
        ],
      ),
      ListingAttributeField(
        key: 'material',
        label: 'Material',
        hint: 'e.g. Ceramic, cotton',
      ),
      ListingAttributeField(
        key: 'dimensions',
        label: 'Dimensions',
        hint: 'Optional',
      ),
    ],
  ),
  ListingCategoryDefinition(
    name: 'Sports',
    subtitle: 'Fitness, bikes, team and outdoor sports',
    attributes: [
      ListingAttributeField(
        key: 'sport',
        label: 'Sport / activity',
        hint: 'e.g. Cycling, tennis',
      ),
      ListingAttributeField(key: 'brand', label: 'Brand', hint: 'Optional'),
      ListingAttributeField(key: 'size', label: 'Size', hint: 'e.g. M, 54 cm'),
    ],
  ),
  ListingCategoryDefinition(
    name: 'Kids',
    subtitle: 'Toys, baby gear and children’s items',
    attributes: [
      ListingAttributeField(
        key: 'ageRange',
        label: 'Recommended age',
        hint: 'e.g. 3–5 years',
      ),
      ListingAttributeField(key: 'brand', label: 'Brand', hint: 'Optional'),
      ListingAttributeField(
        key: 'includedParts',
        label: 'Included parts',
        hint: 'e.g. 24 blocks + storage box',
      ),
    ],
  ),
  ListingCategoryDefinition(
    name: 'Fashion',
    subtitle: 'Clothing, shoes, bags and accessories',
    attributes: [
      ListingAttributeField(key: 'brand', label: 'Brand', hint: 'Optional'),
      ListingAttributeField(
        key: 'size',
        label: 'Size',
        hint: 'e.g. M, NZ 10, EU 42',
      ),
      ListingAttributeField(
        key: 'material',
        label: 'Material',
        hint: 'e.g. Cotton, leather',
      ),
    ],
  ),
  ListingCategoryDefinition(
    name: 'Cars & Vehicles',
    subtitle: 'Cars and road vehicles with vehicle-specific details',
    attributes: [
      ListingAttributeField(key: 'make', label: 'Make', hint: 'e.g. Toyota'),
      ListingAttributeField(key: 'model', label: 'Model', hint: 'e.g. Corolla'),
      ListingAttributeField(
        key: 'year',
        label: 'Year',
        type: ListingAttributeInputType.year,
        min: 1900,
        max: 2100,
      ),
      ListingAttributeField(
        key: 'mileageKm',
        label: 'Mileage',
        type: ListingAttributeInputType.number,
        unit: 'km',
        min: 0,
        max: 2000000,
      ),
      ListingAttributeField(
        key: 'fuelType',
        label: 'Fuel / energy',
        type: ListingAttributeInputType.choice,
        options: [
          'Petrol',
          'Diesel',
          'Hybrid',
          'Plug-in Hybrid',
          'Electric',
          'LPG',
          'Other',
        ],
      ),
      ListingAttributeField(
        key: 'transmission',
        label: 'Transmission',
        type: ListingAttributeInputType.choice,
        options: ['Automatic', 'Manual', 'CVT', 'Other'],
      ),
      ListingAttributeField(
        key: 'bodyType',
        label: 'Body type',
        type: ListingAttributeInputType.choice,
        options: [
          'Hatchback',
          'Sedan',
          'SUV',
          'Wagon',
          'Ute',
          'Van',
          'Coupe',
          'Convertible',
          'Other',
        ],
      ),
      ListingAttributeField(
        key: 'engineSize',
        label: 'Engine / motor',
        hint: 'e.g. 2.0 L, 150 kW',
      ),
      ListingAttributeField(
        key: 'registration',
        label: 'Registration',
        hint: 'Optional plate / rego',
      ),
      ListingAttributeField(
        key: 'wofExpiry',
        label: 'WOF expiry',
        hint: 'Select expiry date',
        type: ListingAttributeInputType.date,
      ),
    ],
  ),
  ListingCategoryDefinition(
    name: 'Other',
    subtitle: 'Anything that does not fit another category',
  ),
];

final listingCategoryNames = List<String>.unmodifiable(
  listingCategoryDefinitions.map((category) => category.name),
);

ListingCategoryDefinition? listingCategoryDefinition(String? category) {
  if (category == null) return null;
  for (final definition in listingCategoryDefinitions) {
    if (definition.name == category) return definition;
  }
  return null;
}

ListingAttributeField? listingAttributeField(String category, String key) {
  final definition = listingCategoryDefinition(category);
  if (definition == null) return null;
  for (final field in definition.attributes) {
    if (field.key == key) return field;
  }
  return null;
}
