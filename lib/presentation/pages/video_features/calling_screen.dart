import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:proyecto/core/services/call_service.dart';
import 'package:proyecto/core/theme/app_theme.dart';
import 'package:proyecto/presentation/providers/auth_provider.dart';
import 'smart_video_call_page.dart';

class CallingScreen extends StatefulWidget {
  final String recipientId;
  final String recipientName;
  final String channelName;
  final String callerName;

  const CallingScreen({
    super.key,
    required this.recipientId,
    required this.recipientName,
    required this.channelName,
    required this.callerName,
  });

  @override
  State<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends State<CallingScreen> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    _listenForAnswer();
  }

  void _listenForAnswer() {
    _subscription = CallService.listenForIncomingCalls(widget.recipientId).listen((snapshot) {
      if (!mounted) return;
      if (!snapshot.exists) {
        _subscription?.cancel();
        if (Navigator.of(context).canPop()) Navigator.pop(context);
        return;
      }
      final data = snapshot.data() as Map<String, dynamic>;
      if (data['status'] == 'connected') {
        _subscription?.cancel();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SmartVideoCallPage(
              channelName: widget.channelName,
              remoteUserName: widget.recipientName,
              callDocKey: widget.recipientId,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 60,
              backgroundColor: AppTheme.primaryBlue.withAlpha(51),
              child: const Icon(Icons.person, size: 60, color: Colors.white54),
            ),
            const SizedBox(height: 30),
            Text(widget.recipientName, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text("Llamando...", style: TextStyle(color: Colors.white54, fontSize: 16)),
            const SizedBox(height: 60),
            const SizedBox(
              width: 80, height: 80,
              child: CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 4),
            ).animate().fadeIn().shake(),
            const SizedBox(height: 80),
            GestureDetector(
              onTap: () {
                CallService.endCall(widget.recipientId);
                _subscription?.cancel();
                Navigator.pop(context);
              },
              child: Container(
                width: 70, height: 70,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                child: const Icon(Icons.call_end, color: Colors.white, size: 30),
              ),
            ),
            const SizedBox(height: 10),
            const Text("Cancelar", style: TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class IncomingCallDialog extends StatefulWidget {
  final String callerName;
  final String myUid;
  final String channelName;

  const IncomingCallDialog({
    super.key,
    required this.callerName,
    required this.myUid,
    required this.channelName,
  });

  @override
  State<IncomingCallDialog> createState() => _IncomingCallDialogState();
}

class _IncomingCallDialogState extends State<IncomingCallDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: AppTheme.primaryBlue.withAlpha(51),
            child: const Icon(Icons.person, size: 40, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 16),
          const Text("Llamada entrante", style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(widget.callerName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: () {
                  CallService.endCall(widget.myUid);
                  Navigator.pop(context);
                },
                child: Container(
                  width: 60, height: 60,
                  decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                  child: const Icon(Icons.call_end, color: Colors.white, size: 26),
                ),
              ),
              GestureDetector(
                onTap: () {
                  CallService.acceptCall(widget.myUid);
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SmartVideoCallPage(
                        channelName: widget.channelName,
                        remoteUserName: widget.callerName,
                        callDocKey: widget.myUid,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 60, height: 60,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                  child: const Icon(Icons.call, color: Colors.white, size: 26),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
