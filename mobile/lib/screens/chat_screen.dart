import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  List<Map<String, dynamic>> _rooms = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.getChatRooms(context.read<AppState>().userId);
      if (mounted) setState(() { _rooms = data; _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  void _newChat() async {
    final users = await SupabaseService.getAvailableChatUsers(context.read<AppState>().userId);
    if (!mounted) return;
    final selected = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Neuer Chat')),
        content: SizedBox(
          width: 300, height: 400,
          child: ListView.builder(
            itemCount: users.length,
            itemBuilder: (_, i) {
              final u = users[i];
              return ListTile(
                leading: CircleAvatar(backgroundColor: AppTheme.primary.withOpacity(0.1), child: Text('${u['first_name']?[0] ?? ''}${u['last_name']?[0] ?? ''}', style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold, fontSize: 12))),
                title: Text('${u['first_name']} ${u['last_name']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(AppTheme.roleLabel(u['role'] ?? ''), style: const TextStyle(fontSize: 11, color: AppTheme.textSub)),
                onTap: () => Navigator.pop(ctx, u),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('Abbrechen')))],
      ),
    );
    if (selected == null) return;
    final roomId = await SupabaseService.createChatRoom(
      name: '${selected['first_name']} ${selected['last_name']}',
      roomType: 'direct',
      createdBy: context.read<AppState>().userId,
      memberIds: [selected['id']],
    );
    if (mounted) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => _ChatDetailScreen(roomId: roomId, roomName: '${selected['first_name']} ${selected['last_name']}')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    floatingActionButton: FloatingActionButton(onPressed: _newChat, child: const Icon(Icons.chat_bubble_outline)),
    body: WebContentWrapper(
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.gradientBox().copyWith(borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24))),
          child: Row(children: [
            const Icon(Icons.chat, color: Colors.white, size: 28),
            const SizedBox(width: 14),
            Text(tr('Chatten'), style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          ]),
        ),
        Expanded(
          child: _loading ? const Center(child: CircularProgressIndicator())
            : _rooms.isEmpty ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.forum_outlined, size: 56, color: AppTheme.textSub),
                const SizedBox(height: 12),
                Text(tr('Keine Chats vorhanden'), style: const TextStyle(color: AppTheme.textSub)),
                const SizedBox(height: 8),
                TextButton.icon(onPressed: _newChat, icon: const Icon(Icons.add), label: Text(tr('Neuen Chat starten'))),
              ]))
            : RefreshIndicator(onRefresh: _load, child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _rooms.length,
                itemBuilder: (_, i) {
                  final r = _rooms[i];
                  final room = r['chat_rooms'];
                  if (room == null) return const SizedBox.shrink();
                  final msgs = room['chat_messages'] as List? ?? [];
                  final lastMsg = msgs.isNotEmpty ? msgs.first : null;
                  final unread = msgs.where((m) => m['is_read'] == false && m['sender_id'] != context.read<AppState>().userId).length;
                  return Card(child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: room['room_type'] == 'group' ? AppTheme.warning.withOpacity(0.1) : AppTheme.primary.withOpacity(0.1),
                      child: Icon(room['room_type'] == 'group' ? Icons.group : Icons.person, color: room['room_type'] == 'group' ? AppTheme.warning : AppTheme.primary, size: 20),
                    ),
                    title: Text(room['name'] ?? tr('Chat'), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(lastMsg?['message'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSub), maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: unread > 0 ? Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                      child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ) : null,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => _ChatDetailScreen(roomId: room['id'], roomName: room['name'] ?? ''))).then((_) => _load()),
                  ));
                },
              )),
        ),
      ]),
    ),
  );
}

class _ChatDetailScreen extends StatefulWidget {
  final String roomId, roomName;
  const _ChatDetailScreen({required this.roomId, required this.roomName});
  @override
  State<_ChatDetailScreen> createState() => _ChatDetailState();
}

class _ChatDetailState extends State<_ChatDetailScreen> {
  final _msgCtrl = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final data = await SupabaseService.getChatMessages(widget.roomId);
      await SupabaseService.markChatMessagesRead(widget.roomId, context.read<AppState>().userId);
      if (mounted) setState(() { _messages = data.reversed.toList(); _loading = false; });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _send() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty) return;
    _msgCtrl.clear();
    await SupabaseService.sendChatMessage(roomId: widget.roomId, senderId: context.read<AppState>().userId, message: text);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final myId = context.read<AppState>().userId;
    return Scaffold(
      appBar: AppBar(title: Text(widget.roomName)),
      body: Column(children: [
        Expanded(
          child: _loading ? const Center(child: CircularProgressIndicator())
            : _messages.isEmpty ? Center(child: Text(tr('Keine Nachrichten'), style: const TextStyle(color: AppTheme.textSub)))
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length,
                itemBuilder: (_, i) {
                  final m = _messages[i];
                  final isMe = m['sender_id'] == myId;
                  final sender = m['sender'];
                  return Align(
                    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
                      decoration: BoxDecoration(
                        color: isMe ? AppTheme.primary : Colors.grey.shade100,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16), topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isMe ? 16 : 4), bottomRight: Radius.circular(isMe ? 4 : 16),
                        ),
                      ),
                      child: Column(crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start, children: [
                        if (!isMe && sender != null) Text('${sender['first_name']} ${sender['last_name']}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isMe ? Colors.white70 : AppTheme.textSub)),
                        Text(m['message'] ?? '', style: TextStyle(color: isMe ? Colors.white : AppTheme.textMain, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(_formatTime(m['created_at']), style: TextStyle(fontSize: 9, color: isMe ? Colors.white54 : AppTheme.textSub)),
                      ]),
                    ),
                  );
                },
              ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppTheme.divider))),
          child: Row(children: [
            Expanded(child: TextField(
              controller: _msgCtrl,
              decoration: InputDecoration(hintText: tr('Nachricht schreiben...'), border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              onSubmitted: (_) => _send(),
            )),
            const SizedBox(width: 8),
            FloatingActionButton.small(onPressed: _send, child: const Icon(Icons.send, size: 18)),
          ]),
        ),
      ]),
    );
  }

  String _formatTime(String? ts) {
    if (ts == null) return '';
    final d = DateTime.tryParse(ts)?.toLocal();
    if (d == null) return '';
    return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}
