import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiwishare/main.dart';
import 'package:kiwishare/models/item_model.dart';
import 'package:kiwishare/providers/watchlist_provider.dart';
import 'package:kiwishare/repositories/watchlist_repository.dart';

void main() {
  test(
    'login token is propagated before loading and mutating watchlist',
    () async {
      final repository = _RecordingWatchlistRepository();
      final provider = WatchlistProvider(repository: repository);

      expect(syncWatchlistAuth(provider, 'fresh-login-token'), same(provider));
      await Future<void>.delayed(Duration.zero);

      expect(repository.readTokens, ['fresh-login-token', 'fresh-login-token']);

      await provider.addToWatchlist('item-1');
      expect(repository.writeTokens, ['fresh-login-token']);
    },
  );

  test(
    'an old account response cannot replace the current watchlist',
    () async {
      final repository = _DelayedWatchlistRepository();
      final provider = WatchlistProvider(repository: repository);

      syncWatchlistAuth(provider, 'old-token');
      await Future<void>.delayed(Duration.zero);
      syncWatchlistAuth(provider, 'new-token');
      await Future<void>.delayed(Duration.zero);

      repository.completeOldRequest();
      await Future<void>.delayed(Duration.zero);

      expect(provider.watchedItemIds, {'new-item'});
    },
  );
}

class _RecordingWatchlistRepository implements WatchlistRepository {
  final readTokens = <String?>[];
  final writeTokens = <String?>[];

  @override
  Future<List<ItemModel>> fetchWatchlist({String? token}) async {
    readTokens.add(token);
    return [];
  }

  @override
  Future<Set<String>> fetchWatchedItemIds({String? token}) async {
    readTokens.add(token);
    return {};
  }

  @override
  Future<bool> addToWatchlist(String itemId, {String? token}) async {
    writeTokens.add(token);
    return true;
  }

  @override
  Future<bool> removeFromWatchlist(String itemId, {String? token}) async =>
      true;

  @override
  Future<bool> isWatched(String itemId, {String? token}) async => false;
}

class _DelayedWatchlistRepository implements WatchlistRepository {
  final _oldItems = Completer<List<ItemModel>>();

  void completeOldRequest() => _oldItems.complete([]);

  @override
  Future<List<ItemModel>> fetchWatchlist({String? token}) {
    return token == 'old-token' ? _oldItems.future : Future.value([]);
  }

  @override
  Future<Set<String>> fetchWatchedItemIds({String? token}) async {
    return token == 'new-token' ? {'new-item'} : {'old-item'};
  }

  @override
  Future<bool> addToWatchlist(String itemId, {String? token}) async => true;

  @override
  Future<bool> removeFromWatchlist(String itemId, {String? token}) async =>
      true;

  @override
  Future<bool> isWatched(String itemId, {String? token}) async => false;
}
