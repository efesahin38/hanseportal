import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import 'order_detail_screen.dart';

/// Bölüm 14 – Dijital Arşiv (Tamamlanan / Faturalanan)
class ArchiveScreen extends StatefulWidget {
  const ArchiveScreen({super.key});

  @override
  State<ArchiveScreen> createState() => _ArchiveScreenState();
}

class _ArchiveScreenState extends State<ArchiveScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _completedOrders = [];
  List<Map<String, dynamic>> _invoicedOrders = [];
  bool _loading = true;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    setState(() => _loading = true);
    try {
      final departmentId = !appState.canViewAllOrders ? appState.departmentId : null;
      
      final completed = await SupabaseService.getOrders(status: 'completed', departmentId: departmentId);
      final invoiced = await SupabaseService.getOrders(status: 'invoiced', departmentId: departmentId);
      final archived = await SupabaseService.getOrders(status: 'archived', departmentId: departmentId);
      
      if (mounted) {
        setState(() {
          _completedOrders = completed;
          // Eski arşiv kayıtları varsa onları da faturalanan listesine dahil edelim.
          _invoicedOrders = [...invoiced, ...archived]; 
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _filterList(List<Map<String, dynamic>> list) {
    if (_searchQuery.isEmpty) return list;
    final q = _searchQuery.toLowerCase();
    return list.where((o) {
      final title = (o['title'] ?? '').toLowerCase();
      final number = (o['order_number'] ?? '').toLowerCase();
      final customer = (o['customer']?['name'] ?? '').toLowerCase();
      return title.contains(q) || number.contains(q) || customer.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredCompleted = _filterList(_completedOrders);
    final filteredInvoiced = _filterList(_invoicedOrders);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Arşiv'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(104),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'İş no, müşteri veya başlık ara...',
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                tabs: const [
                  Tab(text: 'Tamamlanan İşler'),
                  Tab(text: 'Faturalanan İşler'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: WebContentWrapper(
        padding: EdgeInsets.zero,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildList(filteredCompleted, 'Tamamlanan iş bulunamadı', 'completed'),
                  _buildList(filteredInvoiced, 'Faturalanan iş bulunamadı', 'invoiced'),
                ],
              ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, String emptyMsg, String type) {
    return RefreshIndicator(
      onRefresh: _load,
      child: items.isEmpty
          ? Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(type == 'completed' ? Icons.check_circle_outline : Icons.receipt_long_outlined, size: 64, color: AppTheme.textSub.withOpacity(0.4)),
                const SizedBox(height: 16),
                Text(emptyMsg, style: const TextStyle(color: AppTheme.textSub, fontSize: 16, fontFamily: 'Inter')),
              ]),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              itemBuilder: (_, i) => _ArchiveCard(
                order: items[i], 
                type: type,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: items[i]['id'])),
                  ).then((_) => _load());
                },
              ),
            ),
    );
  }
}

class _ArchiveCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final String type; // completed or invoiced
  final VoidCallback onTap;
  
  const _ArchiveCard({required this.order, required this.type, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final customer = order['customer'];
    final address = order['site_address'] ?? '';
    final dateStr = order['planned_end_date'] ?? order['planned_start_date'];
    
    String formattedDate = '';
    if (dateStr != null) {
      try {
        final d = DateTime.parse(dateStr);
        formattedDate = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
      } catch (_) {}
    }

    final isCompleted = type == 'completed';
    final actualBadgeColor = isCompleted ? AppTheme.success : AppTheme.primary;
    final badgeText = isCompleted ? 'Tamamlandı' : 'Faturalandırıldı';
    final iconData = isCompleted ? Icons.check_circle : Icons.receipt_long;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: actualBadgeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconData, color: actualBadgeColor, size: 20),
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: actualBadgeColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(badgeText, style: TextStyle(fontSize: 11, color: actualBadgeColor, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              ),
            ]),
  
            if (customer != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.business, size: 14, color: AppTheme.textSub),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(customer['name'] ?? '',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter'), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
            
            if (address.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSub),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(address,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter'), maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ]),
            ],
  
            if (formattedDate.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: AppTheme.bg, borderRadius: BorderRadius.circular(6)),
                child: Text('Tarih: $formattedDate', style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter')),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
