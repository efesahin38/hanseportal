import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';

/// Bölüm 14 – Dijital Arşivleme
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> {
  List<Map<String, dynamic>> _archives = [];
  List<Map<String, dynamic>> _archivedOrders = [];
  bool _loading = true;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    try {
      final departmentId = !appState.canViewAllOrders ? appState.departmentId : null;
      final archives = await SupabaseService.getArchiveRecords();
      final archivedOrders = await SupabaseService.getOrders(
        status: 'archived',
        departmentId: departmentId,
      );
      if (mounted) {
        setState(() {
          _archives = archives;
          _archivedOrders = archivedOrders;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredOrders {
    if (_searchQuery.isEmpty) return _archivedOrders;
    final q = _searchQuery.toLowerCase();
    return _archivedOrders.where((o) {
      final title = (o['title'] ?? '').toLowerCase();
      final number = (o['order_number'] ?? '').toLowerCase();
      final customer = (o['customer']?['name'] ?? '').toLowerCase();
      return title.contains(q) || number.contains(q) || customer.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dijital Arşiv'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _searchQuery = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'İş numarası, müşteri veya başlık ara...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                prefixIcon: const Icon(Icons.search, color: Colors.white70),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.white70),
                        onPressed: () => setState(() {
                          _searchQuery = '';
                          _searchCtrl.clear();
                        }),
                      )
                    : null,
                filled: true,
                fillColor: Colors.white.withOpacity(0.15),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              ),
            ),
          ),
        ),
      ),
      body: WebContentWrapper(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: _filteredOrders.isEmpty
                    ? Center(
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.archive_outlined, size: 64, color: AppTheme.textSub.withOpacity(0.4)),
                          const SizedBox(height: 16),
                          const Text('Arşivlenmiş iş bulunamadı',
                              style: TextStyle(color: AppTheme.textSub, fontSize: 16, fontFamily: 'Inter')),
                          const SizedBox(height: 8),
                          const Text(
                            'Tamamlanan işler "Arşivlendi" durumuna\nalındığında burada görünür.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.textSub, fontSize: 13, fontFamily: 'Inter'),
                          ),
                        ]),
                      )
                    : Column(
                        children: [
                          // Özet Bant
                          Container(
                            color: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            child: Row(
                              children: [
                                _ArchiveStat(
                                  label: 'Toplam Arşiv',
                                  value: '${_archivedOrders.length}',
                                  icon: Icons.folder_outlined,
                                  color: AppTheme.primary,
                                ),
                                const SizedBox(width: 16),
                                _ArchiveStat(
                                  label: 'Arşiv Kaydı',
                                  value: '${_archives.length}',
                                  icon: Icons.storage_outlined,
                                  color: AppTheme.success,
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
  
                          Expanded(
                            child: ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _filteredOrders.length,
                              itemBuilder: (_, i) {
                                final order = _filteredOrders[i];
                                final archiveRecord = _archives.firstWhere(
                                  (a) => a['order_id'] == order['id'],
                                  orElse: () => {},
                                );
                                return _ArchiveCard(
                                  order: order,
                                  archiveRecord: archiveRecord,
                                  canManage: appState.canManageArchive,
                                  onArchive: () => _createArchive(order, appState),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
      ),
    );
  }

  Future<void> _createArchive(Map<String, dynamic> order, AppState appState) async {
    try {
      final orderId = order['id'] as String;
      final orderNum = order['order_number'] ?? orderId;
      final customer = order['customer']?['name'] ?? 'Müşteri';
      final now = DateTime.now();
      final folderPath = '${now.year}/$customer/$orderNum';

      await SupabaseService.upsertArchiveRecord({
        'order_id': orderId,
        'archive_folder_path': folderPath,
        'archived_at': now.toIso8601String(),
        'status': 'archived',
        'created_by': appState.userId,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Arşiv kaydı oluşturuldu'), backgroundColor: AppTheme.success),
        );
        _load();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Arşiv oluşturulurken hata oluştu'), backgroundColor: AppTheme.error),
        );
      }
    }
  }
}

class _ArchiveStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _ArchiveStat({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 18),
      ),
      const SizedBox(width: 8),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color, fontFamily: 'Inter')),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
      ]),
    ]);
  }
}

class _ArchiveCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final Map<String, dynamic> archiveRecord;
  final bool canManage;
  final VoidCallback onArchive;
  const _ArchiveCard({
    required this.order,
    required this.archiveRecord,
    required this.canManage,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final customer = order['customer'];
    final hasRecord = archiveRecord.isNotEmpty;
    final folderPath = archiveRecord['archive_folder_path'] as String?;
    final archivedAt = archiveRecord['archived_at'] != null
        ? DateTime.tryParse(archiveRecord['archived_at'])
        : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: hasRecord
                    ? AppTheme.success.withOpacity(0.1)
                    : AppTheme.textSub.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                hasRecord ? Icons.folder : Icons.folder_open_outlined,
                color: hasRecord ? AppTheme.success : AppTheme.textSub,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(order['title'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter'),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(order['order_number'] ?? '',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
              ]),
            ),
            if (hasRecord)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('Arşivlendi',
                    style: TextStyle(fontSize: 11, color: AppTheme.success, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              ),
          ]),

          if (customer != null) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.business, size: 14, color: AppTheme.textSub),
              const SizedBox(width: 4),
              Text(customer['name'] ?? '',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
            ]),
          ],

          if (folderPath != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.folder_copy_outlined, size: 14, color: AppTheme.textSub),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(folderPath,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter'),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ),
          ],

          if (archivedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Arşiv tarihi: ${archivedAt.day.toString().padLeft(2, '0')}.${archivedAt.month.toString().padLeft(2, '0')}.${archivedAt.year}',
              style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter'),
            ),
          ],

          if (!hasRecord && canManage) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onArchive,
                icon: const Icon(Icons.archive_outlined, size: 16),
                label: const Text('Arşiv Kaydı Oluştur',
                    style: TextStyle(fontFamily: 'Inter', fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: const BorderSide(color: AppTheme.primary),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
