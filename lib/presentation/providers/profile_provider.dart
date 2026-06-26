import 'package:flutter/material.dart';
import 'package:proyecto/data/datasources/remote/firestore_datasource.dart';
import 'package:proyecto/data/models/user_model.dart';

class ProfileProvider with ChangeNotifier {
  final FirestoreDatasource _firestoreDatasource = FirestoreDatasource();
  
  UserModel? _userProfile;
  bool _isLoading = false;

  UserModel? get userProfile => _userProfile;
  bool get isLoading => _isLoading;

  /// Carga el perfil completo desde Firestore
  Future<void> loadProfile(String uid) async {
    _isLoading = true;
    notifyListeners();

    try {
      _userProfile = await _firestoreDatasource.getUserProfile(uid);
    } catch (e) {
      debugPrint("Error al cargar perfil: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Actualiza el contacto de emergencia
  Future<void> updateEmergencyContact(String uid, String newContact) async {
    try {
      await _firestoreDatasource.updateEmergencyContact(uid, newContact);
      if (_userProfile != null) {
        _userProfile = UserModel(
          uid: _userProfile!.uid,
          email: _userProfile!.email,
          name: _userProfile!.name,
          emergencyContact: newContact,
          inviteCode: _userProfile!.inviteCode,
          profilePhoto: _userProfile!.profilePhoto,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error al actualizar contacto: $e");
    }
  }

  /// Actualiza la foto de perfil
  Future<void> updateProfilePhoto(String uid, String photoUrl) async {
    try {
      await _firestoreDatasource.updateProfilePhoto(uid, photoUrl);
      if (_userProfile != null) {
        _userProfile = UserModel(
          uid: _userProfile!.uid,
          email: _userProfile!.email,
          name: _userProfile!.name,
          emergencyContact: _userProfile!.emergencyContact,
          inviteCode: _userProfile!.inviteCode,
          profilePhoto: photoUrl,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint("Error al actualizar foto: $e");
    }
  }
}
