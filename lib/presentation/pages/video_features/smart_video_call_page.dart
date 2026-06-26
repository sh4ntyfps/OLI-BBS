import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:agora_token_generator/agora_token_generator.dart';
import '../../../core/services/call_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/haptic_feedback_helper.dart';
import '../../providers/settings_provider.dart';

class SmartVideoCallPage extends StatefulWidget {
  final String channelName;
  final String remoteUserName;
  final String callDocKey;

  const SmartVideoCallPage({
    super.key, 
    required this.channelName, 
    this.remoteUserName = "Amigo",
    required this.callDocKey,
  });

  @override
  State<SmartVideoCallPage> createState() => _SmartVideoCallPageState();
}

class _SmartVideoCallPageState extends State<SmartVideoCallPage> {
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _muted = false;
  bool _videoDisabled = false;
  late RtcEngine _engine;
  
  // Para los subtítulos (simulados por ahora)
  String _currentSubtitles = "Esperando traducción...";
  bool _isSignDetectionActive = true;

  @override
  void initState() {
    super.initState();
    initAgora();
  }

  Future<void> _endCall() async {
    await CallService.endCall(widget.callDocKey);
    if (mounted) Navigator.pop(context);
  }

  Future<void> initAgora() async {
    // Solicitar permisos
    await [Permission.microphone, Permission.camera].request();

    // Crear el motor de Agora
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: "e428b5b2d4a547f9841d3e1051e96cd9",
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("✅ Local user joined channel ${connection.channelId}");
          setState(() {
            _localUserJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("✅ Remote user $remoteUid joined");
          setState(() {
            _remoteUid = remoteUid;
          });
          HapticFeedbackHelper.success();
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint("❌ Remote user offline: $reason");
          setState(() {
            _remoteUid = null;
          });
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              _endCall();
            }
          });
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint("❌ Agora error: $err - $msg");
        },
      ),
    );

    await _engine.enableVideo();
    await _engine.startPreview();

    // Generar token con el certificado
    const appId = "e428b5b2d4a547f9841d3e1051e96cd9";
    const cert = "0f978192e5ee447bb2bce29816ebbcf3";
    final token = RtcTokenBuilder.buildTokenWithUid(
      appId: appId,
      appCertificate: cert,
      channelName: widget.channelName,
      uid: 0,
      tokenExpireSeconds: 3600,
    );
    debugPrint("🔑 Token generado: ${token.substring(0, 20)}...");

    await _engine.joinChannel(
      token: token,
      channelId: widget.channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. VIDEO REMOTO (PANTALLA COMPLETA)
          Center(
            child: _remoteVideoView(),
          ),

          // 2. VIDEO LOCAL (VISTA PREVIA PEQUEÑA)
          Positioned(
            top: 50,
            right: 20,
            child: Container(
              width: 120,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white24),
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 10)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _localUserJoined 
                  ? AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: _engine,
                        canvas: const VideoCanvas(uid: 0),
                      ),
                    )
                  : Container(color: Colors.grey[900], child: const Icon(Icons.person, color: Colors.white54)),
              ),
            ),
          ),

          // 3. BARRA DE SUBTÍTULOS (IA)
          Positioned(
            bottom: 120,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.auto_awesome, color: Colors.cyanAccent, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        _isSignDetectionActive ? "IA TRADUCIENDO" : "TRADUCCIÓN PAUSADA",
                        style: const TextStyle(color: Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _currentSubtitles,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ).animate().slideY(begin: 1, end: 0),
          ),

          // 4. CONTROLES DE LLAMADA
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildControlButton(
                  icon: _muted ? Icons.mic_off : Icons.mic,
                  color: _muted ? Colors.red : Colors.white24,
                  onTap: () {
                    setState(() => _muted = !_muted);
                    _engine.muteLocalAudioStream(_muted);
                  },
                ),
                _buildControlButton(
                  icon: Icons.call_end,
                  color: Colors.red,
                  size: 70,
                  onTap: _endCall,
                ),
                _buildControlButton(
                  icon: _videoDisabled ? Icons.videocam_off : Icons.videocam,
                  color: _videoDisabled ? Colors.red : Colors.white24,
                  onTap: () {
                    setState(() => _videoDisabled = !_videoDisabled);
                    _engine.muteLocalVideoStream(_videoDisabled);
                  },
                ),
                _buildControlButton(
                  icon: Icons.switch_camera,
                  color: Colors.white24,
                  onTap: () => _engine.switchCamera(),
                ),
              ],
            ),
          ),

          // NOMBRE DEL CONTACTO
          Positioned(
            top: 60,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.remoteUserName,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const Row(
                  children: [
                    CircleAvatar(radius: 4, backgroundColor: Colors.green),
                    SizedBox(width: 8),
                    Text("Conectado", style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, required Color color, required VoidCallback onTap, double size = 55}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: size * 0.5),
      ),
    );
  }

  Widget _remoteVideoView() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: widget.channelName),
        ),
      );
    } else {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppTheme.primaryBlue),
          const SizedBox(height: 20),
          Text(
            "Esperando a ${widget.remoteUserName}...",
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ],
      );
    }
  }
}
