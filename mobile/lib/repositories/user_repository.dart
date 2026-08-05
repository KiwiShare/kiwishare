import '../models/user_model.dart';

abstract class UserRepository {
  Future<UserModel> fetchCurrentUser();
}

class MockUserRepository implements UserRepository {
  @override
  Future<UserModel> fetchCurrentUser() async {
    // Simulate 500ms network latency
    await Future.delayed(const Duration(milliseconds: 500));
    return const UserModel(
      id: 'user_1',
      displayName: 'Sam',
      avatarUrl: null, // Will use placeholder initials in the UI
      trustScore: 98,
      isVerified: true,
    );
  }
}
