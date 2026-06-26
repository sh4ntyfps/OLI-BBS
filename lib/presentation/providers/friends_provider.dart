import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/datasources/remote/firestore_datasource.dart';
import '../../data/models/user_model.dart';
import '../../core/services/notification_helper.dart';

class FriendsProvider with ChangeNotifier {
  final FirestoreDatasource _firestoreDatasource = FirestoreDatasource();
  
  List<UserModel> _friends = [];
  UserModel? _currentUserProfile;
  bool _isLoading = false;
  StreamSubscription? _friendsSubscription;

  List<UserModel> get friends => _friends;
  UserModel? get currentUserProfile => _currentUserProfile;
  bool get isLoading => _isLoading;

  @override
  void dispose() {
    _friendsSubscription?.cancel();
    super.dispose();
  }

  /// Carga el perfil del usuario actual e inicia la escucha en tiempo real
  Future<void> loadData(String uid) async {
    // Si ya estamos cargando, evitamos duplicar esfuerzos
    if (_isLoading && _friends.isNotEmpty) return;

    try {
      // 1. Obtener mi perfil (para el QR)
      _currentUserProfile = await _firestoreDatasource.getUserProfile(uid);

      // 2. Obtener lista de amigos reales desde Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('friends')
          .get();

      List<UserModel> tempFriends = [];
      for (var doc in snapshot.docs) {
        final friendProfile = await _firestoreDatasource.getUserProfile(doc.id);
        if (friendProfile != null) {
          tempFriends.add(friendProfile);
        }
      }
      _friends = tempFriends;
      
      // Iniciamos la escucha en tiempo real si no está activa
      _startListening(uid);
      
    } catch (e) {
      debugPrint("Error al cargar amigos: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Escucha cambios en Firestore para actualizar la lista automáticamente
  void _startListening(String uid) {
    if (_friendsSubscription != null) return;

    _friendsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('friends')
        .snapshots()
        .listen((snapshot) {
          // Cuando hay un cambio en la colección de amigos, recargamos la lista
          loadData(uid);
        });
  }

  /// Busca a un usuario por su código y lo agrega
  Future<String?> addFriendByCode(String currentUid, String code) async {
    if (code.isEmpty) return "El código está vacío";
    
    _isLoading = true;
    notifyListeners();

    try {
      final cleanCode = code.trim().toUpperCase();

      // Buscar usuario con ese inviteCode
      final query = await FirebaseFirestore.instance
          .collection('users')
          .where('inviteCode', isEqualTo: cleanCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        return "Código no encontrado";
      }

      final friendUid = query.docs.first.id;
      if (friendUid == currentUid) {
        return "No puedes agregarte a ti mismo";
      }

      // Verificar si ya son amigos
      final alreadyFriend = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUid)
          .collection('friends')
          .doc(friendUid)
          .get();
      
      if (alreadyFriend.exists) {
        return "Ya tienes a este amigo agregado";
      }

      // Agregar vínculo en Firestore
      await _firestoreDatasource.addFriend(currentUid, friendUid);

      // Notificar al amigo
      final myProfile = await _firestoreDatasource.getUserProfile(currentUid);
      NotificationHelper.sendNotification(
        recipientUid: friendUid,
        type: NotificationType.friendAdded,
        title: 'Nuevo amigo',
        body: '${myProfile?.name ?? "Alguien"} te agregó como amigo',
        fromUid: currentUid,
        fromName: myProfile?.name,
      );

      return null; // Éxito
    } catch (e) {
      return "Error al agregar amigo";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> removeFriend(String currentUid, String friendUid) async {
    try {
      await _firestoreDatasource.removeFriend(currentUid, friendUid);
      await loadData(currentUid);
    } catch (e) {
      debugPrint("Error al eliminar amigo: $e");
    }
  }

  Future<void> blockUser(String currentUid, String targetUid) async {
    try {
      await _firestoreDatasource.blockUser(currentUid, targetUid);
      await loadData(currentUid);
    } catch (e) {
      debugPrint("Error al bloquear: $e");
    }
  }

  Future<void> unblockUser(String currentUid, String targetUid) async {
    try {
      await _firestoreDatasource.unblockUser(currentUid, targetUid);
      await loadData(currentUid);
    } catch (e) {
      debugPrint("Error al desbloquear: $e");
    }
  }

  /// Verificar si un usuario está bloqueado
  Future<bool> isBlocked(String currentUid, String targetUid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(currentUid).get();
      if (doc.exists) {
        final blocked = (doc.data()?['blockedUsers'] as List<dynamic>?) ?? [];
        return blocked.contains(targetUid);
      }
    } catch (_) {}
    return false;
  }
}
