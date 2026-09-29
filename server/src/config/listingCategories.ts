export const LISTING_CATEGORIES = [
  'Furniture',
  'Electronics',
  'Books',
  'Home',
  'Sports',
  'Kids',
  'Fashion',
  'Cars & Vehicles',
  'Other'
] as const;

export type ListingCategory = typeof LISTING_CATEGORIES[number];

export interface ListingAttributeSpec {
  key: string;
  label: string;
  required?: boolean;
  options?: readonly string[];
  numeric?: boolean;
  dateKind?: 'date' | 'year';
  min?: number;
  max?: number;
}

export const LISTING_CATEGORY_ATTRIBUTES: Record<ListingCategory, readonly ListingAttributeSpec[]> = {
  Furniture: [
    { key: 'material', label: 'Material' },
    { key: 'dimensions', label: 'Dimensions' },
    { key: 'brand', label: 'Brand / maker' }
  ],
  Electronics: [
    { key: 'brand', label: 'Brand' },
    { key: 'model', label: 'Model' },
    { key: 'storage', label: 'Storage / capacity' }
  ],
  Books: [
    { key: 'author', label: 'Author' },
    { key: 'isbn', label: 'ISBN' },
    { key: 'edition', label: 'Edition' }
  ],
  Home: [
    {
      key: 'room',
      label: 'Best for',
      options: ['Kitchen', 'Bedroom', 'Living', 'Bathroom', 'Laundry', 'Garden', 'Other']
    },
    { key: 'material', label: 'Material' },
    { key: 'dimensions', label: 'Dimensions' }
  ],
  Sports: [
    { key: 'sport', label: 'Sport / activity' },
    { key: 'brand', label: 'Brand' },
    { key: 'size', label: 'Size' }
  ],
  Kids: [
    { key: 'ageRange', label: 'Recommended age' },
    { key: 'brand', label: 'Brand' },
    { key: 'includedParts', label: 'Included parts' }
  ],
  Fashion: [
    { key: 'brand', label: 'Brand' },
    { key: 'size', label: 'Size' },
    { key: 'material', label: 'Material' }
  ],
  'Cars & Vehicles': [
    { key: 'make', label: 'Make' },
    { key: 'model', label: 'Model' },
    { key: 'year', label: 'Year', numeric: true, dateKind: 'year', min: 1900, max: 2100 },
    {
      key: 'mileageKm',
      label: 'Mileage',
      numeric: true,
      min: 0,
      max: 2_000_000
    },
    {
      key: 'fuelType',
      label: 'Fuel / energy',
      options: ['Petrol', 'Diesel', 'Hybrid', 'Plug-in Hybrid', 'Electric', 'LPG', 'Other']
    },
    {
      key: 'transmission',
      label: 'Transmission',
      options: ['Automatic', 'Manual', 'CVT', 'Other']
    },
    {
      key: 'bodyType',
      label: 'Body type',
      options: ['Hatchback', 'Sedan', 'SUV', 'Wagon', 'Ute', 'Van', 'Coupe', 'Convertible', 'Other']
    },
    { key: 'engineSize', label: 'Engine / motor' },
    { key: 'registration', label: 'Registration' },
    { key: 'wofExpiry', label: 'WOF expiry', dateKind: 'date' }
  ],
  Other: []
};

export const ALL_LISTING_ATTRIBUTE_KEYS = Array.from(
  new Set(
    Object.values(LISTING_CATEGORY_ATTRIBUTES)
      .flat()
      .map((field) => field.key)
  )
);

export class ListingAttributeValidationError extends Error {}

function cleanText(value: unknown, label: string): string {
  if (typeof value !== 'string' && typeof value !== 'number') {
    throw new ListingAttributeValidationError(`${label} must be text or a number.`);
  }
  const text = String(value).trim();
  if (text.length > 120) {
    throw new ListingAttributeValidationError(`${label} must be 120 characters or fewer.`);
  }
  return text;
}

export function sanitizeListingAttributes(
  category: string,
  value: unknown,
  { requireRequired = false }: { requireRequired?: boolean } = {}
): Record<string, string> {
  if (!LISTING_CATEGORIES.includes(category as ListingCategory)) {
    return {};
  }
  const specs = LISTING_CATEGORY_ATTRIBUTES[category as ListingCategory];

  if (value == null) {
    if (requireRequired && specs.some((spec) => spec.required)) {
      const first = specs.find((spec) => spec.required)!;
      throw new ListingAttributeValidationError(`${first.label} is required for ${category}.`);
    }
    return {};
  }
  if (typeof value !== 'object' || Array.isArray(value)) {
    throw new ListingAttributeValidationError('Listing attributes must be an object.');
  }

  const source = value as Record<string, unknown>;
  const result: Record<string, string> = {};

  for (const spec of specs) {
    const raw = source[spec.key];
    const text = raw == null ? '' : cleanText(raw, spec.label);

    if (!text) {
      if (requireRequired && spec.required) {
        throw new ListingAttributeValidationError(`${spec.label} is required for ${category}.`);
      }
      continue;
    }

    let normalized = text;
    if (spec.options) {
      const canonical = spec.options.find(
        (option) => option.toLowerCase() === text.toLowerCase()
      );
      if (!canonical) {
        throw new ListingAttributeValidationError(
          `${spec.label} must be one of: ${spec.options.join(', ')}.`
        );
      }
      normalized = canonical;
    }

    if (spec.numeric) {
      const numeric = Number(text);
      if (!Number.isFinite(numeric)) {
        throw new ListingAttributeValidationError(`${spec.label} must be a valid number.`);
      }
      if (spec.min != null && numeric < spec.min) {
        throw new ListingAttributeValidationError(`${spec.label} is below the allowed range.`);
      }
      if (spec.max != null && numeric > spec.max) {
        throw new ListingAttributeValidationError(`${spec.label} is above the allowed range.`);
      }
    }

    if (spec.dateKind === 'year' && !/^\d{4}$/.test(text)) {
      throw new ListingAttributeValidationError(`${spec.label} must be a four-digit year.`);
    }

    if (spec.dateKind === 'date') {
      if (!/^\d{4}-\d{2}-\d{2}$/.test(text) || Number.isNaN(Date.parse(`${text}T00:00:00Z`))) {
        throw new ListingAttributeValidationError(`${spec.label} must be a valid date.`);
      }
    }

    result[spec.key] = normalized;
  }

  return result;
}
