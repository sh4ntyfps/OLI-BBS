import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_helper.dart';

class CallService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<void> initiateCall(String callerId, String callerName, String recipientId, String channelName) async {
    await _db.collection('calls').doc(recipientId).set({
      'callerId': callerId,
      'callerName': callerName,
      'channelName': channelName,
      'status': 'calling',
      'timestamp': FieldValue.serverTimestamp(),
    });

    NotificationHelper.sendNotification(
      recipientUid: recipientId,
      type: NotificationType.incomingCall,
      title: 'Llamada entrante',
      body: '$callerName te está llamando',
      fromUid: callerId,
      fromName: callerName,
      channelName: channelName,
    );
  }

  static Future<void> acceptCall(String recipientId) async {
    await _db.collection('calls').doc(recipientId).update({'status': 'connected'});
  }

  static Future<void> endCall(String recipientId) async {
    await _db.collection('calls').doc(recipientId).delete();
  }

  static Stream<DocumentSnapshot> listenForIncomingCalls(String myUid) {
    return _db.collection('calls').doc(myUid).snapshots();
  }
}
