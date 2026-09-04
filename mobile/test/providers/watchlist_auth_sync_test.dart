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

  test('account switch clears the previous account immediately', () async {
    final provider = WatchlistProvider(
      repository: _DelayedWatchlistRepository(),
      initialToken: 'old-token',
      initialWatchedIds: {'old-item'},
    );

    syncWatchlistAuth(provider, 'new-token');

    expect(provider.watchedItemIds, isEmpty);
    expect(provider.watchlistItems, isEmpty);
    await Future<void>.delayed(Duration.zero);
  });

  test(
    'failed add from an old session cannot remove a new account item',
    () async {
      final repository = _DelayedMutationWatchlistRepository();
      final provider = WatchlistProvider(
        repository: repository,
        initialToken: 'old-token',
      );

      final oldAdd = provider.addToWatchlist('shared-item');
      syncWatchlistAuth(provider, 'new-token');
      await Future<void>.delayed(Duration.zero);

      repository.completeOldAdd(false);
      await oldAdd;

      expect(provider.watchedItemIds, {'shared-item'});
    },
  );

  test(
    'failed removal from an old session cannot restore into a new account',
    () async {
      final repository = _DelayedMutationWatchlistRepository();
      final provider = WatchlistProvider(
        repository: repository,
        initialToken: 'old-token',
        initialWatchedIds: {'old-item'},
      );

      final oldRemoval = provider.removeFromWatchlist('old-item');
      syncWatchlistAuth(provider, 'new-token');
      await Future<void>.delayed(Duration.zero);

      repository.completeOldRemoval(false);
      await oldRemoval;

      expect(provider.watchedItemIds, {'shared-item'});
    },
  );

  test('stale load cannot remove a successful same-session add', () async {
    final repository = _SameSessionRaceWatchlistRepository(serverIds: {});
    final provider = WatchlistProvider(
      repository: repository,
      initialToken: 'valid-token',
    );

    final loading = provider.loadWatchlist();
    await provider.addToWatchlist('new-item');
    repository.completeLoad();
    await loading;

    expect(provider.watchedItemIds, {'new-item'});
  });

  test('stale load cannot restore a successful same-session removal', () async {
    final repository = _SameSessionRaceWatchlistRepository(
      serverIds: {'old-item'},
    );
    final provider = WatchlistProvider(
      repository: repository,
      initialToken: 'valid-token',
      initialWatchedIds: {'old-item'},
    );

    final loading = provider.loadWatchlist();
    await provider.removeFromWatchlist('old-item');
    repository.completeLoad();
    await loading;

    expect(provider.watchedItemIds, isEmpty);
  });

  test('older same-session load cannot replace a newer result', () async {
    final repository = _ConcurrentLoadWatchlistRepository();
    final provider = WatchlistProvider(
      repository: repository,
      initialToken: 'valid-token',
    );

    final olderLoad = provider.loadWatchlist();
    final newerLoad = provider.loadWatchlist();

    repository.completeNewerLoad();
    await newerLoad;
    expect(provider.watchedItemIds, {'new-item'});

    repository.completeOlderLoad();
    await olderLoad;
    expect(provider.watchedItemIds, {'new-item'});
  });
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

class _DelayedMutationWatchlistRepository implements WatchlistRepository {
  final _oldAdd = Completer<bool>();
  final _oldRemoval = Completer<bool>();

  void completeOldAdd(bool success) => _oldAdd.complete(success);
  void completeOldRemoval(bool success) => _oldRemoval.complete(success);

  @override
  Future<List<ItemModel>> fetchWatchlist({String? token}) async => [];

  @override
  Future<Set<String>> fetchWatchedItemIds({String? token}) async =>
      token == 'new-token' ? {'shared-item'} : {};

  @override
  Future<bool> addToWatchlist(String itemId, {String? token}) =>
      token == 'old-token' ? _oldAdd.future : Future.value(true);

  @override
  Future<bool> removeFromWatchlist(String itemId, {String? token}) =>
      token == 'old-token' ? _oldRemoval.future : Future.value(true);

  @override
  Future<bool> isWatched(String itemId, {String? token}) async => false;
}

class _SameSessionRaceWatchlistRepository implements WatchlistRepository {
  _SameSessionRaceWatchlistRepository({required this.serverIds});

  final Set<String> serverIds;
  final _loadGate = Completer<List<ItemModel>>();

  void completeLoad() => _loadGate.complete([]);

  @override
  Future<List<ItemModel>> fetchWatchlist({String? token}) => _loadGate.future;

  @override
  Future<Set<String>> fetchWatchedItemIds({String? token}) async => serverIds;

  @override
  Future<bool> addToWatchlist(String itemId, {String? token}) async => true;

  @override
  Future<bool> removeFromWatchlist(String itemId, {String? token}) async =>
      true;

  @override
  Future<bool> isWatched(String itemId, {String? token}) async => false;
}

class _ConcurrentLoadWatchlistRepository implements WatchlistRepository {
  final _olderItems = Completer<List<ItemModel>>();
  final _newerItems = Completer<List<ItemModel>>();
  int _itemRequestCount = 0;
  int _idRequestCount = 0;

  void completeOlderLoad() => _olderItems.complete([]);
  void completeNewerLoad() => _newerItems.complete([]);

  @override
  Future<List<ItemModel>> fetchWatchlist({String? token}) {
    _itemRequestCount += 1;
    return _itemRequestCount == 1 ? _olderItems.future : _newerItems.future;
  }

  @override
  Future<Set<String>> fetchWatchedItemIds({String? token}) async {
    _idRequestCount += 1;
    return _idRequestCount == 1 ? {'new-item'} : {'old-item'};
  }

  @override
  Future<bool> addToWatchlist(String itemId, {String? token}) async => true;

  @override
  Future<bool> removeFromWatchlist(String itemId, {String? token}) async =>
      true;

  @override
  Future<bool> isWatched(String itemId, {String? token}) async => false;
}
