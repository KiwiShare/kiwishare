import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/services/recommendation_service.dart';

import '../support/test_item_repository.dart';

void main() {
  test('similar recommendations prefer the current category and exclude self', () async {
    final repository = TestItemRepository();
    final service = RecommendationService(repository);
    final current = testCatalogItems.firstWhere((item) => item.id == 'item_4');

    final similar = await service.similarTo(current, limit: 3);

    expect(similar, hasLength(3));
    expect(similar.any((item) => item.id == current.id), isFalse);
    expect(similar.every((item) => item.category == 'Camping'), isTrue);
  });

  test('featured and for-you recommendation surfaces use the shared module', () async {
    final repository = TestItemRepository();
    final service = RecommendationService(repository);

    final featured = await service.featured(limit: 2);
    final forYou = await service.forYou(limit: 2);

    expect(featured, hasLength(2));
    expect(forYou, hasLength(2));
    expect(featured.first.isSustainable, isTrue);
    expect(forYou.first.isSustainable, isTrue);
  });
}
