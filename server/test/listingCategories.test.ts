import {
  ListingAttributeValidationError,
  sanitizeListingAttributes
} from '../src/config/listingCategories';

describe('listing category attributes', () => {
  test('requires core vehicle fields for published car listings', () => {
    expect(() =>
      sanitizeListingAttributes(
        'Cars & Vehicles',
        {
          make: 'Toyota',
          model: 'Corolla',
          year: '2018',
          mileageKm: '85000',
          fuelType: 'Hybrid',
          transmission: 'Automatic',
          bodyType: 'Hatchback'
        },
        { requireRequired: true }
      )
    ).not.toThrow();

    expect(() =>
      sanitizeListingAttributes(
        'Cars & Vehicles',
        {
          make: 'Toyota',
          model: 'Corolla'
        },
        { requireRequired: true }
      )
    ).toThrow(ListingAttributeValidationError);
  });

  test('drops unknown fields and validates vehicle enumerations', () => {
    expect(
      sanitizeListingAttributes('Cars & Vehicles', {
        make: 'Toyota',
        madeUp: 'ignored'
      })
    ).toEqual({ make: 'Toyota' });

    expect(() =>
      sanitizeListingAttributes('Cars & Vehicles', {
        fuelType: 'Nuclear'
      })
    ).toThrow('Fuel / energy must be one of');
  });

  test('keeps allowed non-vehicle category attributes', () => {
    expect(
      sanitizeListingAttributes('Electronics', {
        brand: 'Apple',
        model: 'MacBook Air',
        storage: '256 GB',
        mileageKm: 'not applicable'
      })
    ).toEqual({
      brand: 'Apple',
      model: 'MacBook Air',
      storage: '256 GB'
    });
  });
});
