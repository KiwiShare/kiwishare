import {
  ListingAttributeValidationError,
  sanitizeListingAttributes
} from '../src/config/listingCategories';

describe('listing category attributes', () => {
  test('keeps category-specific details optional for vehicle listings', () => {
    expect(sanitizeListingAttributes('Cars & Vehicles', undefined)).toEqual({});
    expect(
      sanitizeListingAttributes('Cars & Vehicles', {
        make: 'Toyota',
        model: 'Corolla'
      })
    ).toEqual({ make: 'Toyota', model: 'Corolla' });
  });

  test('validates optional vehicle year and WOF dates when supplied', () => {
    expect(
      sanitizeListingAttributes('Cars & Vehicles', {
        year: '2018',
        wofExpiry: '2027-06-30'
      })
    ).toEqual({ year: '2018', wofExpiry: '2027-06-30' });

    expect(() =>
      sanitizeListingAttributes('Cars & Vehicles', { wofExpiry: 'June 2027' })
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
