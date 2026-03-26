import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = context.read<AppState>().userId;
    try {
      final data = await SupabaseService.getNotifications(userId);
      if (mounted) setState(() { _notifications = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markRead(String id) async {
    await SupabaseService.markNotificationRead(id);
    context.read<AppState>().decrementUnread();
    _load();
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'task_assignment': return Icons.assignment_ind;
      case 'task_update':     return Icons.update;
      case 'task_cancelled':  return Icons.cancel;
      case 'reminder':        return Icons.alarm;
      default:                return Icons.notifications;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty
              ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.notifications_none, size: 56, color: AppTheme.textSub),
                  SizedBox(height: 12),
                  Text('Bildirim yok', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                ]))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
                      final isRead = n['is_read'] == true;
                      final type = n['notification_type'] ?? 'system';
                      final createdAt = n['created_at'] != null
                          ? DateTime.parse(n['created_at']).toLocal()
                          : null;

                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: isRead ? Colors.white : AppTheme.primary.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isRead ? AppTheme.divider : AppTheme.primary.withOpacity(0.2),
                          ),
                        ),
                        child: ListTile(
                          leading: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: (isRead ? AppTheme.textSub : AppTheme.primary).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(_iconFor(type),
                              color: isRead ? AppTheme.textSub : AppTheme.primary, size: 20),
                          ),
                          title: Text(
                            n['title'] ?? '',
                            style: TextStyle(
                              fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                              fontFamily: 'Inter',
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (n['body'] != null)
                                Text(n['body'], style: const TextStyle(fontSize: 12, fontFamily: 'Inter', color: AppTheme.textSub), maxLines: 2, overflow: TextOverflow.ellipsis),
                              if (createdAt != null)
                                Text(
                                  '${createdAt.day}.${createdAt.month}.${createdAt.year} ${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter'),
                                ),
                            ],
                          ),
                          isThreeLine: true,
                          trailing: !isRead
                              ? IconButton(
                                  icon: const Icon(Icons.done, size: 18, color: AppTheme.primary),
                                  onPressed: () => _markRead(n['id']),
                                  tooltip: 'Okundu işaretle',
                                )
                              : null,
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
