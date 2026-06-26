import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:proyecto/core/theme/app_theme.dart';
import 'package:proyecto/core/utils/haptic_feedback_helper.dart';
import 'package:proyecto/presentation/providers/friends_provider.dart';
import 'package:proyecto/presentation/providers/auth_provider.dart';
import 'package:proyecto/presentation/providers/settings_provider.dart';
import 'package:proyecto/presentation/providers/chat_provider.dart';
import '../chat/chat_page.dart';

class FriendsPage extends StatefulWidget {
  const FriendsPage({super.key});

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _codeController = TextEditingController();
  final Set<String> _blockedUsers = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Carga inicial de datos
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.user != null) {
        Provider.of<FriendsProvider>(context, listen: false).loadData(auth.user!.id);
        // Cargar usuarios bloqueados
        try {
          final db = FirebaseFirestore.instance;
          final doc = await db.collection('users').doc(auth.user!.id).get();
          if (doc.exists) {
            final blocked = (doc.data()?['blockedUsers'] as List<dynamic>?) ?? [];
            _blockedUsers.addAll(blocked.cast<String>());
            if (mounted) setState(() {});
          }
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _confirmDeleteFriend(FriendsProvider provider, String friendUid, String friendName) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Eliminar amigo"),
        content: Text("¿Eliminar a \"$friendName\" de tu lista de amigos?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.removeFriend(auth.user!.id, friendUid);
            },
            child: const Text("Eliminar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _openPrivateChat(String friendUid, String friendName) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chatProv = Provider.of<ChatProvider>(context, listen: false);
    
    if (auth.user != null) {
      final privateChatId = chatProv.getPrivateChatId(auth.user!.id, friendUid);
      // Crear resumen del chat al abrirlo por primera vez
      chatProv.ensureChatSummary(privateChatId, [auth.user!.id, friendUid], friendName, auth.user!.id);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(
            chatId: privateChatId,
            chatName: friendName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final friendsProv = Provider.of<FriendsProvider>(context);
    final settings = Provider.of<SettingsProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(settings.translate('community'), style: const TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryBlue,
          indicatorColor: AppTheme.primaryBlue,
          tabs: [
            Tab(text: settings.locale.languageCode == 'es' ? 'Mis Amigos' : 'My Friends'),
            Tab(text: settings.locale.languageCode == 'es' ? 'Agregar' : 'Add'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(friendsProv, settings),
          _buildAddFriendView(friendsProv, settings),
        ],
      ),
    );
  }

  Widget _buildFriendsList(FriendsProvider provider, SettingsProvider settings) {
    if (provider.isLoading && provider.friends.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.friends.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey.withAlpha(77)),
            const SizedBox(height: 16),
            Text(settings.locale.languageCode == 'es' ? 'Aún no tienes amigos' : 'No friends yet'),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: provider.friends.length,
      itemBuilder: (context, index) {
        final friend = provider.friends[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ListTile(
            onTap: () => _openPrivateChat(friend.uid, friend.name),
            leading: CircleAvatar(
              backgroundColor: AppTheme.primaryBlue.withAlpha(26),
              backgroundImage: (friend.profilePhoto != null && friend.profilePhoto!.isNotEmpty) 
                  ? NetworkImage(friend.profilePhoto!) : null,
              child: (friend.profilePhoto == null || friend.profilePhoto!.isEmpty)
                  ? Text(friend.name[0].toUpperCase(), style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold))
                  : null,
            ),
            title: Text(friend.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(friend.email, style: const TextStyle(fontSize: 12)),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                final auth = Provider.of<AuthProvider>(context, listen: false);
                if (v == 'chat') _openPrivateChat(friend.uid, friend.name);
                else if (v == 'delete') _confirmDeleteFriend(provider, friend.uid, friend.name);
                else if (v == 'block') {
                  provider.blockUser(auth.user!.id, friend.uid);
                  setState(() => _blockedUsers.add(friend.uid));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${friend.name} bloqueado")));
                } else if (v == 'unblock') {
                  provider.unblockUser(auth.user!.id, friend.uid);
                  setState(() => _blockedUsers.remove(friend.uid));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${friend.name} desbloqueado")));
                }
              },
              itemBuilder: (_) {
                final isBlocked = _blockedUsers.contains(friend.uid);
                return [
                  const PopupMenuItem(value: 'chat', child: ListTile(leading: Icon(Icons.chat, color: AppTheme.primaryBlue), title: Text("Conversar"), dense: true)),
                  PopupMenuItem(
                    value: isBlocked ? 'unblock' : 'block',
                    child: ListTile(
                      leading: Icon(isBlocked ? Icons.person_add : Icons.block, color: isBlocked ? Colors.green : Colors.orange),
                      title: Text(isBlocked ? "Desbloquear" : "Bloquear", style: TextStyle(color: isBlocked ? Colors.green : Colors.orange)),
                      dense: true,
                    ),
                  ),
                  const PopupMenuItem(value: 'delete', child: ListTile(leading: Icon(Icons.person_remove, color: Colors.red), title: Text("Eliminar amigo", style: TextStyle(color: Colors.red)), dense: true)),
                ];
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildAddFriendView(FriendsProvider provider, SettingsProvider settings) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildShareCodeCard(provider, settings),
          const SizedBox(height: 32),
          
          SizedBox(
            width: double.infinity,
            height: 64,
            child: ElevatedButton.icon(
              onPressed: () => _showScannerOverlay(context, provider),
              icon: const Icon(Icons.qr_code_scanner, size: 28),
              label: Text(
                settings.locale.languageCode == 'es' ? 'ESCANEAR CÓDIGO QR' : 'SCAN QR CODE',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ),
          
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 30),
          
          Text(
            settings.translate('enter_manually'),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _codeController,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Ej: AB12CD',
              filled: true,
              fillColor: Theme.of(context).cardTheme.color,
              suffixIcon: IconButton(
                icon: const Icon(Icons.person_add, color: AppTheme.primaryBlue),
                onPressed: () => _processAddFriend(provider, _codeController.text),
              ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _processAddFriend(FriendsProvider provider, String code) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final error = await provider.addFriendByCode(auth.user!.id, code);
    
    if (!mounted) return;
    
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error), backgroundColor: Colors.redAccent));
    } else {
      // Refrescar lista de amigos inmediatamente
      await provider.loadData(auth.user!.id);
      _codeController.clear();
      _tabController.animateTo(0);
      HapticFeedbackHelper.success();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Amigo agregado!")));
    }
  }

  Widget _buildShareCodeCard(FriendsProvider provider, SettingsProvider settings) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10)],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppTheme.primaryBlue.withAlpha(26), shape: BoxShape.circle),
            child: const Icon(Icons.qr_code_2, color: AppTheme.primaryBlue, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(settings.locale.languageCode == 'es' ? 'Mi código QR' : 'My QR Code', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(provider.currentUserProfile?.inviteCode ?? '---', style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 22, letterSpacing: 2)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showQRModal(provider),
            icon: const Icon(Icons.fullscreen_rounded, color: AppTheme.primaryBlue, size: 30),
          ),
        ],
      ),
    );
  }

  void _showScannerOverlay(BuildContext context, FriendsProvider provider) {
    bool scanned = false; // Flag local para evitar múltiples escaneos rápidos
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (context) => Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          leading: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.pop(context)),
          title: const Text('Escanear QR', style: TextStyle(color: Colors.white)),
        ),
        body: MobileScanner(
          onDetect: (capture) async {
            if (scanned) return;
            final List<Barcode> barcodes = capture.barcodes;
            if (barcodes.isNotEmpty) {
              final code = barcodes.first.rawValue?.trim();
              if (code != null) {
                scanned = true;
                HapticFeedbackHelper.success();
                if (!context.mounted) return;
                Navigator.pop(context); // Cierra el scanner
                _processAddFriend(provider, code);
              }
            }
          },
        ),
      ),
    );
  }

  void _showQRModal(FriendsProvider provider) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Mi Código SeñaLink', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
              const SizedBox(height: 24),
              QrImageView(
                data: provider.currentUserProfile?.inviteCode ?? '',
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: AppTheme.primaryBlue),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: AppTheme.primaryBlue),
              ),
              const SizedBox(height: 24),
              Text(provider.currentUserProfile?.inviteCode ?? '', 
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4, color: AppTheme.primaryBlue)),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cerrar'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
