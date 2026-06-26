import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/datasources/remote/firestore_datasource.dart';
import '../../data/models/user_model.dart';
import '../../domain/entities/user_entity.dart';
import '../../core/services/notification_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository = AuthRepositoryImpl();
  final FirestoreDatasource _firestoreDatasource = FirestoreDatasource();
  
  UserEntity? _user;
  bool _isLoading = false;
  String? _errorMessage;

  UserEntity? get user => _user;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _authRepository.onAuthStateChanged.listen((UserEntity? user) {
      final wasLoggedIn = _user != null;
      _user = user;
      if (user != null) {
        _updateDeviceToken(user.id);
        if (!wasLoggedIn) _setOnlinePresence(user.id, true);
      } else if (wasLoggedIn) {
        _setOnlinePresence(_user?.id ?? '', false);
      }
      notifyListeners();
    });
  }

  Future<void> _setOnlinePresence(String uid, bool online) async {
    try {
      final doc = FirebaseFirestore.instance.collection('users').doc(uid);
      await doc.set({
        'isOnline': online,
        if (!online) 'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _updateDeviceToken(String uid) async {
    try {
      String? token = await NotificationService.getToken();
      if (token != null) {
        await _firestoreDatasource.updateFCMToken(uid, token);
      }
    } catch (e) {
      debugPrint("Error token: $e");
    }
  }

  Future<bool> login(String email, String password) async {
    _setLoading(true);
    try {
      _user = await _authRepository.signIn(email, password);
      if (_user != null) await _updateDeviceToken(_user!.id);
      return true;
    } catch (e) {
      _errorMessage = "Correo o contraseña incorrectos";
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> register(String email, String password, String name) async {
    _setLoading(true);
    try {
      final userEntity = await _authRepository.signUp(email, password, name);
      if (userEntity != null) {
        String? token = await NotificationService.getToken();
        final newUserProfile = UserModel(
          uid: userEntity.id,
          email: email,
          name: name,
          emergencyContact: "972913326",
          inviteCode: _firestoreDatasource.generateInviteCode(),
          fcmToken: token,
        );
        await _firestoreDatasource.createUserProfile(newUserProfile);
        _user = userEntity;
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = "Error al crear la cuenta";
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> loginGuest() async {
    _setLoading(true);
    try {
      _user = await _authRepository.signInAnonymously();
      if (_user != null) {
        // CREAMOS UN PERFIL BÁSICO PARA EL INVITADO
        final guestProfile = UserModel(
          uid: _user!.id,
          email: "invitado@senalink.com",
          name: "Invitado SeñaLink",
          emergencyContact: "972913326",
          inviteCode: "GUEST-${_user!.id.substring(0,4)}",
        );
        await _firestoreDatasource.createUserProfile(guestProfile);
        await _updateDeviceToken(_user!.id);
      }
      return true;
    } catch (e) {
      _errorMessage = "Error al entrar como invitado";
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> logout() async {
    if (_user != null) await _setOnlinePresence(_user!.id, false);
    await _authRepository.signOut();
    _user = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
