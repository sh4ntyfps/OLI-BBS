import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:proyecto/core/theme/app_theme.dart';
import 'package:proyecto/core/utils/haptic_feedback_helper.dart';
import 'package:proyecto/presentation/providers/settings_provider.dart';
import 'package:proyecto/presentation/providers/auth_provider.dart';
import 'package:proyecto/presentation/providers/chat_provider.dart';
import 'package:proyecto/presentation/providers/profile_provider.dart';
import 'package:proyecto/core/services/call_service.dart';
import '../video_features/calling_screen.dart';
import 'package:proyecto/core/data/all_signs.dart';

class ChatPage extends StatefulWidget {
  final String? chatId;
  final String? chatName;

  const ChatPage({super.key, this.chatId, this.chatName});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _textController = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _currentWords = '';
  double _soundLevel = 0.0;
  Timer? _typingTimer;
  bool _iBlockedThem = false;
  bool _theyBlockedMe = false;
  final List<_QuickPhrase> _quickPhrases = [
    _QuickPhrase('Estoy bien, ¿y tú?'),
    _QuickPhrase('Sí, claro'),
    _QuickPhrase('No, gracias'),
    _QuickPhrase('Nos vemos luego'),
    _QuickPhrase('¿Cómo estás?'),
  ];
  final Map<String, int> _messageCount = {};

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _checkBlocked();
  }

  void _checkBlocked() async {
    final chatId = _getCurrentChatId();
    if (chatId.startsWith('global')) return;
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final myUid = authProv.user?.id ?? '';
    final parts = chatId.split('_');
    final otherUid = parts[0] == myUid ? parts[1] : parts[0];
    try {
      final db = FirebaseFirestore.instance;
      // Check if I blocked them
      final myDoc = await db.collection('users').doc(myUid).get();
      bool iBlocked = false;
      if (myDoc.exists) {
        final blocked = (myDoc.data()?['blockedUsers'] as List<dynamic>?) ?? [];
        iBlocked = blocked.contains(otherUid);
      }
      // Check if they blocked me
      bool theyBlocked = false;
      final theirDoc = await db.collection('users').doc(otherUid).get();
      if (theirDoc.exists) {
        final blocked = (theirDoc.data()?['blockedUsers'] as List<dynamic>?) ?? [];
        theyBlocked = blocked.contains(myUid);
      }
      if (mounted) setState(() { _iBlockedThem = iBlocked; _theyBlockedMe = theyBlocked; });
    } catch (_) {}
  }

  void _sendQuickPhrase(String text) {
    _sendMessage(text);
    Navigator.pop(context);
  }

  void _addQuickPhrase() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Nueva frase rápida"),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Escribe tu frase...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(onPressed: () {
            final t = ctrl.text.trim();
            if (t.isNotEmpty && !_quickPhrases.any((q) => q.text == t)) {
              setState(() => _quickPhrases.add(_QuickPhrase(t)));
            }
            Navigator.pop(ctx);
          }, child: const Text("Guardar")),
        ],
      ),
    );
  }

  void _trackMessage(String text) {
    final key = text.trim().toLowerCase();
    _messageCount[key] = (_messageCount[key] ?? 0) + 1;
    if (_messageCount[key]! >= 3 && !_quickPhrases.any((q) => q.text.toLowerCase() == key)) {
      setState(() => _quickPhrases.add(_QuickPhrase(text.trim(), esAutomatica: true)));
    }
  }

  void _showQuickPhrases() {
    HapticFeedbackHelper.light();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flash_on, color: AppTheme.primaryBlue),
                  const SizedBox(width: 8),
                  const Text("Frases rápidas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      _addQuickPhrase();
                      Navigator.pop(ctx);
                    },
                    child: const CircleAvatar(
                      radius: 18,
                      backgroundColor: AppTheme.primaryBlue,
                      child: Icon(Icons.add, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_quickPhrases.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text("Envía un mensaje 3 veces para que aparezca aquí", style: TextStyle(color: Colors.grey))),
                ),
              ..._quickPhrases.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: ListTile(
                  dense: true,
                  title: Text(p.text, style: const TextStyle(fontWeight: FontWeight.w500)),
                  subtitle: p.esAutomatica ? const Text("Auto-aprendida", style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.send, color: AppTheme.primaryBlue, size: 20),
                        onPressed: () => _sendQuickPhrase(p.text),
                      ),
                      GestureDetector(
                        onTap: () {
                          setState(() => _quickPhrases.remove(p));
                          Navigator.pop(ctx);
                        },
                        child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                      ),
                    ],
                  ),
                ),
              )),
            ],
          ),
        ),
      ),
    );
  }

  void _initSpeech() async {
    try {
      await _speech.initialize(
        onStatus: (status) {
          if ((status == 'notListening' || status == 'done') && mounted) {
            setState(() => _isListening = false);
          }
        },
      );
    } catch (e) {
      debugPrint("Error STT: $e");
    }
  }

  String _getCurrentChatId() {
    final chatProv = Provider.of<ChatProvider>(context, listen: false);
    return widget.chatId ?? chatProv.getGeneralChatId();
  }

  String _getOtherUid() {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final myUid = authProv.user?.id ?? '';
    final chatId = _getCurrentChatId();
    if (chatId.startsWith('global') || chatId.isEmpty || myUid.isEmpty) return '';
    final parts = chatId.split('_');
    return parts[0] == myUid ? parts[1] : parts[0];
  }

  void _onTextChanged(String text) {
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final chatProv = Provider.of<ChatProvider>(context, listen: false);
    if (authProv.user != null) {
      chatProv.setTypingStatus(_getCurrentChatId(), authProv.user!.id, true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 2), () {
        chatProv.setTypingStatus(_getCurrentChatId(), authProv.user!.id, false);
      });
    }
  }

  final List<Map<String, String>> _stickerList = [
    {'name': 'feliz', 'file': 'feliz.webp'},
    {'name': 'amor', 'file': 'amor.webp'},
    {'name': 'gracias', 'file': 'gracias.webp'},
    {'name': 'ok', 'file': 'ok.webp'},
    {'name': 'triste', 'file': 'triste.webp'},
    {'name': 'enojado', 'file': 'enojado.webp'},
    {'name': 'sorpresa', 'file': 'sorpresa.webp'},
    {'name': 'risa', 'file': 'risa.webp'},
    {'name': 'llorar', 'file': 'llorar.webp'},
    {'name': 'fiesta', 'file': 'fiesta.webp'},
    {'name': 'genial', 'file': 'genial.webp'},
    {'name': 'hola', 'file': 'hola.webp'},
    {'name': 'abrazar', 'file': 'abrazar.webp'},
    {'name': 'beso', 'file': 'beso.webp'},
    {'name': 'cafe', 'file': 'cafe.webp'},
    {'name': 'cumpleanos', 'file': 'cumpleanos.webp'},
    {'name': 'dulce', 'file': 'dulce.webp'},
    {'name': 'familia', 'file': 'familia.webp'},
    {'name': 'frio', 'file': 'frio.webp'},
    {'name': 'hambre', 'file': 'hambre.webp'},
    {'name': 'helado', 'file': 'helado.webp'},
    {'name': 'lluvia', 'file': 'lluvia.webp'},
    {'name': 'luna', 'file': 'luna.webp'},
    {'name': 'mar', 'file': 'mar.webp'},
    {'name': 'musica', 'file': 'musica.webp'},
    {'name': 'noche', 'file': 'noche.webp'},
    {'name': 'perro', 'file': 'perro.webp'},
    {'name': 'playa', 'file': 'playa.webp'},
    {'name': 'sol', 'file': 'sol.webp'},
    {'name': 'te_amo', 'file': 'te_amo.webp'},
    {'name': 'telefono', 'file': 'telefono.webp'},
    {'name': 'triste_2', 'file': 'triste_2.webp'},
    {'name': 'viaje', 'file': 'viaje.webp'},
    {'name': 'bien', 'file': 'bien.webp'},
    {'name': 'mal', 'file': 'mal.webp'},
    {'name': 'pensar', 'file': 'pensar.webp'},
    {'name': 'que_haces', 'file': 'que_haces.webp'},
    {'name': 'salud', 'file': 'salud.webp'},
    {'name': 'sueno', 'file': 'sueno.webp'},
    {'name': 'tiempo', 'file': 'tiempo.webp'},
    {'name': 'que_asco', 'file': 'que_asco.webp'},
    {'name': 'que_pena', 'file': 'que_pena.webp'},
    {'name': 'bueno', 'file': 'bueno.webp'},
    {'name': 'malo', 'file': 'malo.webp'},
    {'name': 'que_rico', 'file': 'que_rico.webp'},
    {'name': 'que_lindo', 'file': 'que_lindo.webp'},
    {'name': 'no_me_gusta', 'file': 'no_me_gusta.webp'},
    {'name': 'me_encanta', 'file': 'me_encanta.webp'},
    {'name': 'lo_siento', 'file': 'lo_siento.webp'},
    {'name': 'feliz_2', 'file': 'feliz_2.webp'},
    {'name': 'enojado_2', 'file': 'enojado_2.webp'},
    {'name': 'sorpresa_2', 'file': 'sorpresa_2.webp'},
  ];

  void _showStickerPicker() {
    HapticFeedbackHelper.light();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _StickerPickerPanel(
          stickerList: _stickerList,
          onStickerTap: (name, file) {
            Navigator.pop(context);
            _sendSticker(name, file);
          },
          onSenaTap: (word) {
            Navigator.pop(context);
            _sendSenaSticker(word);
          },
        ),
      ),
    );
  }

  void _showEnlargedSena(String word) {
    HapticFeedbackHelper.light();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: Hero(
              tag: 'sena_$word',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: _SenaImage(word: word, size: MediaQuery.of(context).size.width * 0.75),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showEnlargedSticker(String file, String fallbackText) {
    HapticFeedbackHelper.light();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Center(
            child: Hero(
              tag: 'sticker_$file',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset(
                  file,
                  width: MediaQuery.of(context).size.width * 0.75,
                  height: MediaQuery.of(context).size.width * 0.75,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Text(fallbackText, style: const TextStyle(fontSize: 48)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sendSticker(String name, String file) async {
    final chatProv = Provider.of<ChatProvider>(context, listen: false);
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final profileProv = Provider.of<ProfileProvider>(context, listen: false);
    if (authProv.user == null) return;

    final chatId = _getCurrentChatId();
    List<String>? participants;
    if (!chatId.startsWith('global')) {
      final parts = chatId.split('_');
      participants = [parts[0], parts[1]];
    }

    try {
      await chatProv.sendNewMessage(
        chatId, '[$name]', authProv.user!.id,
        senderName: profileProv.userProfile?.name ?? authProv.user?.name ?? 'Usuario',
        senderPhoto: profileProv.userProfile?.profilePhoto ?? '',
        participants: participants,
        messageType: 'sticker',
        sticker: name,
      );
      HapticFeedbackHelper.success();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al enviar sticker")));
      }
    }
  }

  Future<void> _sendSenaSticker(String word) async {
    final chatProv = Provider.of<ChatProvider>(context, listen: false);
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final profileProv = Provider.of<ProfileProvider>(context, listen: false);
    if (authProv.user == null) return;

    final chatId = _getCurrentChatId();
    List<String>? participants;
    if (!chatId.startsWith('global')) {
      final parts = chatId.split('_');
      participants = [parts[0], parts[1]];
    }

    try {
      await chatProv.sendNewMessage(
        chatId, '[$word]', authProv.user!.id,
        senderName: profileProv.userProfile?.name ?? authProv.user?.name ?? 'Usuario',
        senderPhoto: profileProv.userProfile?.profilePhoto ?? '',
        participants: participants,
        messageType: 'sena',
        sticker: word,
      );
      HapticFeedbackHelper.success();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al enviar seña")));
      }
    }
  }

  Future<void> _sendMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) return;

    _trackMessage(cleanText);

    final chatProv = Provider.of<ChatProvider>(context, listen: false);
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final profileProv = Provider.of<ProfileProvider>(context, listen: false);

    if (authProv.user != null) {
      try {
        final chatId = _getCurrentChatId();
        List<String>? participants;
        if (!chatId.startsWith('global')) {
          final parts = chatId.split('_');
          participants = [parts[0], parts[1]];
        }
        await chatProv.sendNewMessage(
          chatId,
          cleanText,
          authProv.user!.id,
          senderName: profileProv.userProfile?.name ?? authProv.user?.name ?? 'Usuario',
          senderPhoto: profileProv.userProfile?.profilePhoto ?? '',
          participants: participants,
        );
        HapticFeedbackHelper.success();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error al enviar: Permiso denegado o sin red"))
          );
        }
      }
    }
  }

  void _startListening(SettingsProvider settings) async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() {
        _isListening = true;
        _currentWords = '';
        _soundLevel = 0.0;
      });
      HapticFeedbackHelper.light();
      await _speech.listen(
        onResult: (result) {
          if (mounted) setState(() => _currentWords = result.recognizedWords);
        },
        onSoundLevelChange: (level) {
          if (mounted) {
            setState(() {
              _soundLevel = (level + 2) / 12;
              if (_soundLevel < 0) _soundLevel = 0;
              if (_soundLevel > 1) _soundLevel = 1;
            });
          }
        },
        localeId: settings.locale.languageCode == 'es' ? 'es_PE' : 'en_US',
        listenMode: stt.ListenMode.dictation,
        partialResults: true,
      );
    }
  }

  void _stopListening() async {
    await Future.delayed(const Duration(milliseconds: 500));
    final String finalPhrase = _currentWords;
    await _speech.stop();
    if (mounted) {
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
        _currentWords = '';
      });
    }
    if (finalPhrase.isNotEmpty) {
      await _sendMessage(finalPhrase);
    }
  }

  void _showHelp(SettingsProvider settings) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.lightbulb_rounded, color: Colors.amber),
            const SizedBox(width: 10),
            Text(settings.translate('how_to_use')),
          ],
        ),
        content: Text(settings.translate('instr_chat')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<SettingsProvider>(context);
    final authProv = Provider.of<AuthProvider>(context);
    final chatProv = Provider.of<ChatProvider>(context);
    final currentChatId = _getCurrentChatId();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.chatName ?? "Chat Global SeñaLink", 
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            StreamBuilder<DocumentSnapshot>(
              stream: widget.chatId != null && !widget.chatId!.startsWith('global')
                  ? FirebaseFirestore.instance.collection('users').doc(_getOtherUid()).snapshots()
                  : null,
              builder: (context, presenceSnap) {
                final isGlobal = widget.chatId?.startsWith('global') ?? true;
                if (!isGlobal && presenceSnap.hasData && presenceSnap.data!.exists) {
                  final data = presenceSnap.data!.data() as Map<String, dynamic>;
                  final isOnline = data['isOnline'] == true;
                  if (!isOnline) {
                    final lastSeen = data['lastSeen'] as Timestamp?;
                    String lastSeenText = 'Desconectado';
                    if (lastSeen != null) {
                      final diff = DateTime.now().difference(lastSeen.toDate());
                      if (diff.inMinutes < 1) lastSeenText = 'Ahora';
                      else if (diff.inMinutes < 60) lastSeenText = 'Hace ${diff.inMinutes}m';
                      else if (diff.inHours < 24) lastSeenText = 'Hace ${diff.inHours}h';
                      else lastSeenText = 'Hace ${diff.inDays}d';
                    }
                    return Text(lastSeenText, style: const TextStyle(color: Colors.white60, fontSize: 11));
                  }
                }
                return StreamBuilder<DocumentSnapshot>(
                  stream: chatProv.getTypingStream(currentChatId),
                  builder: (context, snapshot) {
                    if (snapshot.hasData && snapshot.data!.exists) {
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      final typingMap = data['typingStatus'] as Map<String, dynamic>?;
                      if (typingMap != null) {
                        bool anyoneTyping = false;
                        typingMap.forEach((uid, isTyping) {
                          if (uid != authProv.user?.id && isTyping == true) anyoneTyping = true;
                        });
                        if (anyoneTyping) return const Text("Escribiendo...", style: TextStyle(color: Colors.white, fontSize: 11, fontStyle: FontStyle.italic));
                      }
                    }
                    if (!isGlobal) return const Text("En línea", style: TextStyle(color: Colors.greenAccent, fontSize: 11));
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ],
        ),
        actions: [
          // BOTÓN DE VIDEOLLAMADA (solo en chats privados)
          if (widget.chatId != null && !widget.chatId!.startsWith('global'))
            IconButton(
              icon: const Icon(Icons.videocam_rounded, color: Colors.white),
              onPressed: () async {
                HapticFeedbackHelper.light();
                final parts = widget.chatId!.split('_');
                final recipientId = parts[0] == authProv.user?.id ? parts[1] : parts[0];
                try {
                  await CallService.initiateCall(
                    authProv.user!.id,
                    authProv.user?.name ?? "Usuario",
                    recipientId,
                    widget.chatId!,
                  );
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("❌ Error de conexión: revisa reglas de Firestore (colección 'calls')"), duration: Duration(seconds: 4)),
                    );
                  }
                  return;
                }
                if (!mounted) return;
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CallingScreen(
                      recipientId: recipientId,
                      recipientName: widget.chatName ?? "Amigo",
                      channelName: widget.chatId!,
                      callerName: authProv.user?.name ?? "Usuario",
                    ),
                  ),
                );
              },
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (v) {
              if (v == 'clear') _confirmClearChat();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'clear', child: ListTile(leading: Icon(Icons.delete_sweep, color: Colors.red), title: Text("Borrar conversación", style: TextStyle(color: Colors.red)), dense: true)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.lightbulb_outline_rounded, color: Colors.white),
            onPressed: () => _showHelp(settings),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: chatProv.getMessagesStream(currentChatId),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Error de conexión", style: TextStyle(color: Colors.red)));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                final allMessages = snapshot.data?.docs ?? [];
                final uid = authProv.user?.id ?? '';
                final messages = allMessages.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final hiddenFor = (data['hiddenFor'] as List<dynamic>?) ?? [];
                  return !hiddenFor.contains(uid);
                }).toList();
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(20),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final data = messages[index].data() as Map<String, dynamic>;
                    final bool isMe = data['senderId'] == authProv.user?.id;
                    final Timestamp? ts = data['timestamp'] as Timestamp?;
                    final String msgId = messages[index].id;
                    final String msgType = data['type'] as String? ?? 'text';
                    return _buildMessageBubble(data['text'] ?? '', isMe, data['senderPhoto'] ?? '', data['senderName'] ?? 'Usuario', ts, msgId, data['edited'] == true, msgType, data['sticker'] as String?);
                  },
                );
              },
            ),
          ),
          if (_iBlockedThem)
            Container(
              width: double.infinity, color: Colors.orange.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Row(children: [
                Icon(Icons.block, color: Colors.orange, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text("Has bloqueado a este usuario", style: TextStyle(color: Colors.orange, fontSize: 13, fontWeight: FontWeight.w500))),
              ]),
            ),
          if (_theyBlockedMe)
            Container(
              width: double.infinity, color: Colors.red.shade50,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: const Row(children: [
                Icon(Icons.block, color: Colors.red, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text("Te han bloqueado", style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500))),
              ]),
            ),
          if (_isListening || _currentWords.isNotEmpty) _buildListeningOverlay(settings),
          _buildInputSection(settings, chatProv, authProv),
        ],
      ),
    );
  }

  Widget _buildListeningOverlay(SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.mic, color: _isListening ? Colors.red : AppTheme.primaryBlue, size: 24).animate(target: _isListening ? 1 : 0).shake(),
              const SizedBox(width: 12),
              Expanded(child: Text(_currentWords.isEmpty ? "Escuchando..." : _currentWords, style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 15))),
            ],
          ),
          if (_isListening)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(value: _soundLevel, minHeight: 8),
              ),
            ),
        ],
      ),
    );
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate().toLocal();
    final now = DateTime.now().toLocal();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Ayer ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showMessageOptions(String msgId, String text, bool isMe) {
    if (!isMe) return;
    final chatProv = Provider.of<ChatProvider>(context, listen: false);
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final chatId = _getCurrentChatId();
    final uid = authProv.user?.id ?? '';
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.primaryBlue),
              title: const Text("Editar mensaje"),
              onTap: () {
                Navigator.pop(ctx);
                final ctrl = TextEditingController(text: text);
                showDialog(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    title: const Text("Editar mensaje"),
                    content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(border: OutlineInputBorder())),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text("Cancelar")),
                      ElevatedButton(onPressed: () {
                        final t = ctrl.text.trim();
                        if (t.isNotEmpty && t != text) chatProv.editMessage(chatId, msgId, t);
                        Navigator.pop(dCtx);
                      }, child: const Text("Guardar")),
                    ],
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined, color: Colors.orange),
              title: const Text("Eliminar para mí", style: TextStyle(color: Colors.orange)),
              onTap: () {
                Navigator.pop(ctx);
                if (uid.isNotEmpty) chatProv.hideMessage(chatId, msgId, uid);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text("Eliminar para todos", style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                chatProv.deleteMessage(chatId, msgId);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClearChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Borrar conversación"),
        content: const Text("¿Eliminar todos los mensajes de este chat?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Borrar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirmed == true) {
      await Provider.of<ChatProvider>(context, listen: false).clearChat(_getCurrentChatId());
      HapticFeedbackHelper.success();
    }
  }

  Widget _buildMessageBubble(String text, bool isMe, String photoUrl, String name, [Timestamp? ts, String? msgId, bool edited = false, String msgType = 'text', String? sticker]) {
    if (msgType == 'sena') {
      final String senaWord = sticker ?? '';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) _buildAvatar(photoUrl),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showEnlargedSena(senaWord),
              onLongPress: msgId != null && isMe ? () => _showMessageOptions(msgId, text, isMe) : null,
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(name, style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue.withAlpha(180), fontWeight: FontWeight.w600)),
                    ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _SenaImage(word: senaWord, size: 120),
                  ),
                  if (ts != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_formatTime(ts), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isMe) _buildAvatar(photoUrl),
          ],
        ),
      );
    }

    if (msgType == 'sticker') {
      final String stickerFile = sticker != null ? 'assets/stickers/$sticker.webp' : '';
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) _buildAvatar(photoUrl),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showEnlargedSticker(stickerFile, text),
              onLongPress: msgId != null && isMe ? () => _showMessageOptions(msgId, text, isMe) : null,
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(name, style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue.withAlpha(180), fontWeight: FontWeight.w600)),
                    ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(stickerFile, width: 120, height: 120, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Text(text, style: const TextStyle(fontSize: 48))),
                  ),
                  if (ts != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(_formatTime(ts), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isMe) _buildAvatar(photoUrl),
          ],
        ),
      );
    }

    return GestureDetector(
      onLongPress: msgId != null ? () => _showMessageOptions(msgId, text, isMe) : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) _buildAvatar(photoUrl),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(name, style: TextStyle(fontSize: 12, color: AppTheme.primaryBlue.withAlpha(180), fontWeight: FontWeight.w600)),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe ? AppTheme.primaryBlue : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF334155) : const Color(0xFFF3F4F6)),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(text, style: TextStyle(color: isMe ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87))),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (edited) Text("editado • ", style: TextStyle(fontSize: 10, color: isMe ? Colors.white60 : Colors.grey)),
                            if (ts != null) Text(_formatTime(ts), style: TextStyle(fontSize: 10, color: isMe ? Colors.white60 : Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isMe) _buildAvatar(photoUrl),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String url) {
    return CircleAvatar(
      radius: 14,
      backgroundImage: (url.isNotEmpty && url.startsWith('http')) ? NetworkImage(url) : null,
      child: url.isEmpty ? const Icon(Icons.person, size: 16) : null,
    );
  }

  Widget _buildInputSection(SettingsProvider settings, ChatProvider chatProv, AuthProvider authProv) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: !_iBlockedThem && !_theyBlockedMe,
              onChanged: _onTextChanged,
              decoration: InputDecoration(
                hintText: _iBlockedThem ? 'Chat bloqueado' : (_theyBlockedMe ? 'Te han bloqueado' : 'Escribe un mensaje...'),
                filled: true,
                fillColor: Theme.of(context).cardTheme.color,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(width: 6),
          if (!_iBlockedThem && !_theyBlockedMe) ...[
            GestureDetector(
              onTap: _showQuickPhrases,
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryBlue,
                child: Icon(Icons.flash_on, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: _showStickerPicker,
              child: const CircleAvatar(
                radius: 18,
                backgroundColor: AppTheme.primaryBlue,
                child: Icon(Icons.emoji_emotions, color: Colors.white, size: 20),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onLongPressStart: (_) => _startListening(settings),
              onLongPressEnd: (_) => _stopListening(),
              child: CircleAvatar(
                backgroundColor: _isListening ? Colors.red : AppTheme.primaryBlue,
                child: Icon(_isListening ? Icons.mic : Icons.mic_none, color: Colors.white),
              ),
            ),
            IconButton(icon: const Icon(Icons.send, color: AppTheme.primaryBlue), onPressed: () {
              _sendMessage(_textController.text);
              _textController.clear();
            }),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
  }
}

class _QuickPhrase {
  final String text;
  final bool esAutomatica;
  _QuickPhrase(this.text, {this.esAutomatica = false});
}

class _SenaImage extends StatelessWidget {
  final String word;
  final double size;
  const _SenaImage({required this.word, this.size = 120});

  static const List<String> _folders = ['santiago', 'mari', 'andre', 'carlos', 'andryck', 'cinthia', 'anahy', 'juan'];

  @override
  Widget build(BuildContext context) {
    return _tryFolder(0);
  }

  Widget _tryFolder(int index) {
    if (index >= _folders.length) {
      return Container(
        width: size, height: size,
        color: Colors.grey.withAlpha(20),
        child: Icon(Icons.image_not_supported, color: Colors.grey[400], size: size * 0.3),
      );
    }
    return Image.asset(
      "assets/senas/${_folders[index]}/$word.webp",
      width: size, height: size,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Image.asset(
        "assets/senas/${_folders[index]}/$word.png",
        width: size, height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _tryFolder(index + 1),
      ),
    );
  }
}

class _StickerPickerPanel extends StatefulWidget {
  final List<Map<String, String>> stickerList;
  final void Function(String name, String file) onStickerTap;
  final void Function(String word) onSenaTap;

  const _StickerPickerPanel({
    required this.stickerList,
    required this.onStickerTap,
    required this.onSenaTap,
  });

  @override
  State<_StickerPickerPanel> createState() => _StickerPickerPanelState();
}

class _StickerPickerPanelState extends State<_StickerPickerPanel> {
  int _tabIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<String> _filteredSenas = AllSigns.words;

  @override
  void initState() {
    super.initState();
    _filteredSenas = List.from(AllSigns.words);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
      if (_searchQuery.isEmpty) {
        _filteredSenas = List.from(AllSigns.words);
      } else {
        _filteredSenas = AllSigns.words.where((w) => w.contains(_searchQuery)).toList();
      }
    });
  }

  String _formatWord(String word) {
    return word
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.75,
      expand: false,
      builder: (_, scrollController) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTabButton(0, 'Stickers'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildTabButton(1, 'Señas reales'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_tabIndex == 0)
              Expanded(
                child: Scrollbar(
                  controller: scrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: scrollController,
                    child: Wrap(
                      spacing: 8, runSpacing: 8,
                      children: widget.stickerList.map((s) => _buildStickerItem(s['name']!, s['file']!)).toList(),
                    ),
                  ),
                ),
              ),
            if (_tabIndex == 1) ...[
              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar seña...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  filled: true,
                  fillColor: Theme.of(context).cardTheme.color,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Scrollbar(
                  controller: scrollController,
                  thumbVisibility: true,
                  child: GridView.builder(
                    controller: scrollController,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      childAspectRatio: 0.85,
                    ),
                    itemCount: _filteredSenas.length,
                    itemBuilder: (_, index) {
                      final word = _filteredSenas[index];
                      return _buildSenaItem(word);
                    },
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(int index, String label) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue : Colors.grey.withAlpha(25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStickerItem(String name, String file) {
    return GestureDetector(
      onTap: () => widget.onStickerTap(name, file),
      child: Container(
        width: 70, height: 70,
        decoration: BoxDecoration(
          color: Colors.grey.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset("assets/stickers/$file", fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _buildSenaItem(String word) {
    return GestureDetector(
      onTap: () => widget.onSenaTap(word),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _SenaImage(word: word, size: double.infinity),
            ),
          ),
          const SizedBox(height: 3),
          Text(
            _formatWord(word),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 9),
          ),
        ],
      ),
    );
  }
}
