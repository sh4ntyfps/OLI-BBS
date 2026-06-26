import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:proyecto/core/theme/app_theme.dart';
import 'package:proyecto/core/utils/haptic_feedback_helper.dart';
import 'package:proyecto/presentation/providers/auth_provider.dart';
import 'package:proyecto/presentation/providers/chat_provider.dart';
import 'package:proyecto/presentation/providers/settings_provider.dart';
import 'package:proyecto/presentation/providers/profile_provider.dart';
import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  Future<String> _resolveChatName(String chatId, List<dynamic> participants, String defaultName) async {
    if (chatId.startsWith('global') || participants.length != 2) return defaultName;
    final authProv = Provider.of<AuthProvider>(context, listen: false);
    final myUid = authProv.user?.id ?? '';
    final otherUid = participants.where((p) => p != myUid).firstOrNull?.toString() ?? '';
    if (otherUid.isEmpty) return defaultName;
    try {
      final db = FirebaseFirestore.instance;
      final doc = await db.collection('users').doc(otherUid).get();
      if (doc.exists) {
        final name = doc.data()?['name'] as String?;
        if (name != null && name.isNotEmpty) return name;
      }
    } catch (_) {}
    return defaultName;
  }

  void _openChat(String chatId, String chatName) {
    final myUid = Provider.of<AuthProvider>(context, listen: false).user?.id ?? '';
    if (myUid.isNotEmpty) {
      Provider.of<ChatProvider>(context, listen: false).markAsRead(chatId, myUid);
    }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ChatPage(chatId: chatId, chatName: chatName),
    ));
  }

  void _openGlobalChat() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const ChatPage(chatName: "Chat Global SeñaLink"),
    ));
  }

  String _formatLastTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate().toLocal();
    final now = DateTime.now().toLocal();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Ayer';
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    final authProv = Provider.of<AuthProvider>(context);
    final chatProv = Provider.of<ChatProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);
    final myUid = authProv.user?.id ?? '';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        title: Text(settings.locale.languageCode == 'es' ? 'Conversaciones' : 'Chats', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: AppTheme.primaryBlue.withAlpha(26),
                child: const Icon(Icons.language, color: AppTheme.primaryBlue),
              ),
              title: const Text("Chat Global SeñaLink", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text("Conversación abierta con todos", style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _openGlobalChat,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              Text("Chats privados", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 13)),
              Divider(),
            ]),
          ),

          if (myUid.isEmpty)
            const Expanded(child: Center(child: Text("Inicia sesión para ver tus chats")))
          else
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: chatProv.getUserChatsStream(myUid),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return const Center(child: Text("Error de conexión"));
                  if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                  
                  final docs = snapshot.data?.docs ?? [];
                  // Filtrar chats eliminados por el usuario actual
                  final visible = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final deletedBy = (data['deletedBy'] as List<dynamic>?) ?? [];
                    return !deletedBy.contains(myUid);
                  }).toList();

                  if (visible.isEmpty) {
                    return const Center(child: Text("No tienes conversaciones\nAgrega amigos para chatear", textAlign: TextAlign.center));
                  }

                  final pinned = <QueryDocumentSnapshot>[];
                  final others = <QueryDocumentSnapshot>[];
                  for (final doc in visible) {
                    final data = doc.data() as Map<String, dynamic>;
                    final pinnedBy = (data['pinnedBy'] as List<dynamic>?) ?? [];
                    if (pinnedBy.contains(myUid)) pinned.add(doc);
                    else others.add(doc);
                  }

                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (pinned.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(bottom: 4),
                          child: Row(children: [
                            Icon(Icons.push_pin, size: 14, color: Colors.grey),
                            SizedBox(width: 4),
                            Text("Fijados", style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
                          ]),
                        ),
                        ...pinned.map((doc) => _buildChatTile(doc, myUid, chatProv)),
                        const SizedBox(height: 8),
                      ],
                      ...others.map((doc) => _buildChatTile(doc, myUid, chatProv)),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatTile(QueryDocumentSnapshot doc, String myUid, ChatProvider chatProv) {
    final data = doc.data() as Map<String, dynamic>;
    final participants = (data['participants'] as List<dynamic>?) ?? [];
    final defaultName = data['chatName'] as String? ?? 'Chat';
    final lastMessage = data['lastMessage'] as String? ?? '';
    final lastSender = data['lastSender'] as String? ?? '';
    final lastTimestamp = data['lastTimestamp'] as Timestamp?;
    final pinnedBy = (data['pinnedBy'] as List<dynamic>?) ?? [];
    final isPinned = pinnedBy.contains(myUid);
    final String chatId = doc.id;

    // Verificar si hay mensajes no leídos
    final lastReadMap = (data['lastRead'] as Map<String, dynamic>?) ?? {};
    final lastReadTs = lastReadMap[myUid] is Timestamp ? (lastReadMap[myUid] as Timestamp) : null;
    final hasUnread = lastTimestamp != null && (lastReadTs == null || lastTimestamp.toDate().isAfter(lastReadTs.toDate()));

    return FutureBuilder<String>(
      future: _resolveChatName(chatId, participants, defaultName),
      builder: (context, snap) {
        final chatName = snap.data ?? defaultName;
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: hasUnread ? AppTheme.primaryBlue.withAlpha(13) : null,
          elevation: hasUnread ? 4 : 1,
          shadowColor: hasUnread ? AppTheme.primaryBlue.withAlpha(51) : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryBlue.withAlpha(26),
              child: Text(
                chatName.isNotEmpty ? chatName[0].toUpperCase() : '?',
                style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
              ),
            ),
            title: Row(
              children: [
                if (isPinned) const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Icon(Icons.push_pin, size: 14, color: Colors.grey),
                ),
            Expanded(child: Text(chatName, style: TextStyle(fontWeight: FontWeight.bold, color: hasUnread ? AppTheme.primaryBlue : null))),
            if (hasUnread)
              Container(margin: const EdgeInsets.only(right: 6), width: 10, height: 10, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
            if (lastTimestamp != null)
              Text(_formatLastTime(lastTimestamp), style: TextStyle(fontSize: 11, color: hasUnread ? AppTheme.primaryBlue : Colors.grey)),
              ],
            ),
            subtitle: Text(
              lastMessage.isNotEmpty ? "$lastSender: $lastMessage" : "Sin mensajes",
              maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12),
            ),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'pin') chatProv.togglePinChat(doc.id, myUid, !isPinned);
                else if (v == 'delete') _confirmDeleteChat(doc.id, chatName);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'pin', child: Text(isPinned ? "Quitar fijado" : "Fijar chat")),
                const PopupMenuItem(value: 'delete', child: Text("Eliminar chat", style: TextStyle(color: Colors.red))),
              ],
            ),
            onTap: () => _openChat(doc.id, chatName),
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteChat(String chatId, String chatName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Eliminar chat"),
        content: Text("¿Eliminar la conversación con $chatName?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Eliminar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      final myUid = Provider.of<AuthProvider>(context, listen: false).user?.id ?? '';
      if (myUid.isNotEmpty) {
        await Provider.of<ChatProvider>(context, listen: false).deleteChatSummary(chatId, myUid);
        HapticFeedbackHelper.light();
      }
    }
  }
}
