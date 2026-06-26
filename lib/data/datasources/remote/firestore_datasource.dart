import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:proyecto/data/models/user_model.dart';

class FirestoreDatasource {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Colección de Usuarios
  Future<void> createUserProfile(UserModel user) async {
    await _firestore.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<UserModel?> getUserProfile(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromMap(doc.data()!);
    }
    return null;
  }

  // Actualizar token de notificaciones (NUEVO)
  Future<void> updateFCMToken(String uid, String token) async {
    await _firestore.collection('users').doc(uid).update({
      'fcmToken': token,
    });
  }

  // Actualizar contacto de emergencia
  Future<void> updateEmergencyContact(String uid, String newContact) async {
    await _firestore.collection('users').doc(uid).update({
      'emergencyContact': newContact,
    });
  }

  // Bloquear/desbloquear usuario
  Future<void> blockUser(String currentUid, String targetUid) async {
    await _firestore.collection('users').doc(currentUid).update({
      'blockedUsers': FieldValue.arrayUnion([targetUid]),
    });
  }

  Future<void> unblockUser(String currentUid, String targetUid) async {
    await _firestore.collection('users').doc(currentUid).update({
      'blockedUsers': FieldValue.arrayRemove([targetUid]),
    });
  }

  // Actualizar foto de perfil (NUEVO)
  Future<void> updateProfilePhoto(String uid, String photoUrl) async {
    await _firestore.collection('users').doc(uid).update({
      'profilePhoto': photoUrl,
    });
  }

  // Generar un código único de 6 dígitos
  String generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return String.fromCharCodes(Iterable.generate(
        6, (_) => chars.codeUnitAt(Random().nextInt(chars.length))));
  }

  // Colección de Amigos
  Future<void> addFriend(String currentUid, String friendUid) async {
    await _firestore.collection('users').doc(currentUid).collection('friends').doc(friendUid).set({
      'addedAt': FieldValue.serverTimestamp()
    });
    await _firestore.collection('users').doc(friendUid).collection('friends').doc(currentUid).set({
      'addedAt': FieldValue.serverTimestamp()
    });
  }

  Future<void> removeFriend(String currentUid, String friendUid) async {
    await _firestore.collection('users').doc(currentUid).collection('friends').doc(friendUid).delete();
    await _firestore.collection('users').doc(friendUid).collection('friends').doc(currentUid).delete();
  }

  // Colección de Mensajes (Chat)
  Future<void> sendMessage(String chatId, Map<String, dynamic> messageData) async {
    await _firestore.collection('chats').doc(chatId).collection('messages').add(messageData);
    
    // Aquí es donde en una app profesional se dispara una notificación.
    // Guardamos una bandera de 'unread' para el otro usuario (no crítico)
    try {
      await _firestore.collection('chats').doc(chatId).set({
        'lastMessage': messageData['text'],
        'lastTimestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Stream<QuerySnapshot> getMessages(String chatId) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  // ─── Presencia (online / offline) ────────────────────────────────────
  Future<void> setOnline(String uid, bool isOnline) async {
    await _firestore.collection('users').doc(uid).update({
      'isOnline': isOnline,
      if (!isOnline) 'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Stream<DocumentSnapshot> getUserPresence(String uid) {
    return _firestore.collection('users').doc(uid).snapshots();
  }
}
