import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<UserEntity?> signIn(String email, String password);
  Future<UserEntity?> signUp(String email, String password, String name);
  Future<UserEntity?> signInAnonymously();
  Future<void> signOut();
  Stream<UserEntity?> get onAuthStateChanged;
}
