import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proyecto/data/datasources/remote/firestore_datasource.dart';
import 'package:proyecto/core/services/notification_helper.dart';

class ChatProvider with ChangeNotifier {
  final FirestoreDatasource _firestoreDatasource = FirestoreDatasource();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Genera un ID único para un chat privado entre dos usuarios
  String getPrivateChatId(String uid1, String uid2) {
    List<String> ids = [uid1, uid2];
    ids.sort(); // Ordenamos para que el ID sea el mismo sin importar quién inicie el chat
    return ids.join("_");
  }

  /// Escucha los mensajes de una sala específica
  Stream<QuerySnapshot> getMessagesStream(String chatId) {
    return _db.collection('chats').doc(chatId).collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  /// Envía un mensaje
  Future<void> sendNewMessage(
    String chatId, 
    String text, 
    String senderId, 
    {String? senderName, String? senderPhoto, List<String>? participants, String? messageType, String? sticker}
  ) async {
    final messageData = {
      'text': text,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'timestamp': FieldValue.serverTimestamp(),
    };
    if (messageType != null) messageData['type'] = messageType;
    if (sticker != null) messageData['sticker'] = sticker;
    // Enviamos el mensaje primero
    await _firestoreDatasource.sendMessage(chatId, messageData);

    // Actualizar resumen del chat (no crítico si falla)
    if (participants != null) {
      final chatName = senderName ?? 'Usuario';
      try {
        await _db.collection('user_chats').doc(chatId).set({
          'participants': participants,
          'lastMessage': text,
          'lastTimestamp': FieldValue.serverTimestamp(),
          'lastSender': chatName,
          'lastSenderId': senderId,
          'chatName': chatName,
        }, SetOptions(merge: true));
      } catch (_) {
        // Error no crítico: el mensaje ya se envió
      }

      // Notificar al destinatario del mensaje
      if (chatId != 'global_chat_senalink') {
        final recipientId = participants.where((p) => p != senderId).firstOrNull;
        if (recipientId != null) {
          NotificationHelper.sendNotification(
            recipientUid: recipientId,
            type: NotificationType.chatMessage,
            title: senderName ?? 'Mensaje',
            body: text,
            fromUid: senderId,
            fromName: senderName,
            channelName: chatId,
            extraData: chatName,
          );
        }
      }
    }

    // Al enviar mensaje, nos aseguramos de que el estado de 'escribiendo' sea false (no crítico)
    try {
      setTypingStatus(chatId, senderId, false);
    } catch (_) {}
  }

  /// Asegura que el resumen del chat exista (para mostrar nombre en lista)
  Future<void> ensureChatSummary(String chatId, List<String> participants, String chatName, String currentUid) async {
    await _db.collection('user_chats').doc(chatId).set({
      'participants': participants,
      'chatName': chatName,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'deletedBy': FieldValue.arrayRemove([currentUid]),
    }, SetOptions(merge: true));
  }

  /// Marcar chat como leído para el usuario
  Future<void> markAsRead(String chatId, String uid) async {
    await _db.collection('user_chats').doc(chatId).set({
      'lastRead': {uid: FieldValue.serverTimestamp()},
    }, SetOptions(merge: true));
  }

  /// Stream de resúmenes de chats del usuario
  Stream<QuerySnapshot> getUserChatsStream(String uid) {
    return _db.collection('user_chats')
        .where('participants', arrayContains: uid)
        .orderBy('lastTimestamp', descending: true)
        .snapshots();
  }

  /// Fijar o quitar fijado de un chat
  Future<void> togglePinChat(String chatId, String uid, bool pinned) async {
    if (pinned) {
      await _db.collection('user_chats').doc(chatId).update({
        'pinnedBy': FieldValue.arrayUnion([uid]),
      });
    } else {
      await _db.collection('user_chats').doc(chatId).update({
        'pinnedBy': FieldValue.arrayRemove([uid]),
      });
    }
  }

  /// Eliminar un chat del listado (solo para el usuario actual)
  Future<void> deleteChatSummary(String chatId, String uid) async {
    await _db.collection('user_chats').doc(chatId).set({
      'deletedBy': FieldValue.arrayUnion([uid]),
    }, SetOptions(merge: true));
  }

  /// Actualiza si el usuario está escribiendo o no
  Future<void> setTypingStatus(String chatId, String uid, bool isTyping) async {
    await _db.collection('chats').doc(chatId).set({
      'typingStatus': {
        uid: isTyping,
      }
    }, SetOptions(merge: true));
  }

  /// Escucha quién está escribiendo en el chat (que no sea el usuario actual)
  Stream<DocumentSnapshot> getTypingStream(String chatId) {
    return _db.collection('chats').doc(chatId).snapshots();
  }

  String getGeneralChatId() => "global_chat_senalink";

  Future<void> editMessage(String chatId, String messageId, String newText) async {
    await _db.collection('chats').doc(chatId).collection('messages').doc(messageId).update({
      'text': newText,
      'edited': true,
    });
  }

  /// Eliminar mensaje para todos
  Future<void> deleteMessage(String chatId, String messageId) async {
    await _db.collection('chats').doc(chatId).collection('messages').doc(messageId).delete();
  }

  /// Ocultar mensaje solo para el usuario actual (eliminar para mí)
  Future<void> hideMessage(String chatId, String messageId, String uid) async {
    await _db.collection('chats').doc(chatId).collection('messages').doc(messageId).set({
      'hiddenFor': FieldValue.arrayUnion([uid]),
    }, SetOptions(merge: true));
  }

  Future<void> clearChat(String chatId) async {
    final messages = await _db.collection('chats').doc(chatId).collection('messages').get();
    for (final doc in messages.docs) {
      await doc.reference.delete();
    }
  }
}
