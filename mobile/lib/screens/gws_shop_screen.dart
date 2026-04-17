import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';

/// GWS Shop / Bestellmodul
/// Kunden / Externer Manager buradan malzeme sipariş edebilir.
class GwsShopScreen extends StatefulWidget {
  final List<Map<String, dynamic>> objects;
  const GwsShopScreen({super.key, required this.objects});
  @override
  State<GwsShopScreen> createState() => _GwsShopScreenState();
}

class _GwsShopScreenState extends State<GwsShopScreen> with SingleTickerProviderStateMixin {
  static const Color _color = AppTheme.gwsColor;

  late TabController _tabController;

  String? _selectedObjectId;
  final List<Map<String, dynamic>> _cart = [];
  String _searchQuery = '';
  String _selectedCategory = 'Alle';
  bool _saving = false;
  int _tabIndex = 0; // 0=Shop, 1=Bestellungen

  List<Map<String, dynamic>> _shopOrders = [];
  bool _loadingOrders = false;

  static const List<Map<String, dynamic>> _catalog = [
    {'name': 'Allzweckreiniger', 'category': 'Reinigungsprodukte', 'price': 8.50, 'unit': 'Flasche', 'icon': Icons.cleaning_services},
    {'name': 'Desinfektionsmittel', 'category': 'Reinigungsprodukte', 'price': 12.00, 'unit': 'Flasche', 'icon': Icons.local_pharmacy},
    {'name': 'Glasreiniger', 'category': 'Reinigungsprodukte', 'price': 6.50, 'unit': 'Flasche', 'icon': Icons.window},
    {'name': 'WC-Reiniger', 'category': 'Reinigungsprodukte', 'price': 5.00, 'unit': 'Flasche', 'icon': Icons.bathroom},
    {'name': 'Toilettenpapier (12er)', 'category': 'Hygieneartikel', 'price': 9.90, 'unit': 'Packung', 'icon': Icons.book},
    {'name': 'Seifenspender-Nachfüllpack', 'category': 'Hygieneartikel', 'price': 11.50, 'unit': 'Stk.', 'icon': Icons.soap},
    {'name': 'Papierhandtücher', 'category': 'Hygieneartikel', 'price': 7.20, 'unit': 'Pack', 'icon': Icons.receipt_long},
    {'name': 'Einweghandschuhe (100 Stk.)', 'category': 'Hygieneartikel', 'price': 8.00, 'unit': 'Box', 'icon': Icons.back_hand},
    {'name': 'Müllbeutel (50 Stk.)', 'category': 'Verbrauchsmaterialien', 'price': 6.00, 'unit': 'Rolle', 'icon': Icons.delete_outline},
    {'name': 'Microfasertücher (10er)', 'category': 'Verbrauchsmaterialien', 'price': 14.50, 'unit': 'Set', 'icon': Icons.dry_cleaning},
    {'name': 'Gästeseife (50g)', 'category': 'Gästematerialien', 'price': 1.20, 'unit': 'Stk.', 'icon': Icons.spa},
    {'name': 'Shampoo-Miniflasche', 'category': 'Gästematerialien', 'price': 0.90, 'unit': 'Stk.', 'icon': Icons.shower},
    {'name': 'Duschgel-Miniflasche', 'category': 'Gästematerialien', 'price': 0.95, 'unit': 'Stk.', 'icon': Icons.shower},
    {'name': 'Zahnstocher', 'category': 'Frühstücks-/Servicebedarf', 'price': 2.50, 'unit': 'Pack', 'icon': Icons.fork_right},
    {'name': 'Servietten (100 Stk.)', 'category': 'Frühstücks-/Servicebedarf', 'price': 4.50, 'unit': 'Pack', 'icon': Icons.book_outlined},
  ];

  static const List<String> _categories = ['Alle', 'Reinigungsprodukte', 'Hygieneartikel', 'Verbrauchsmaterialien', 'Gästematerialien', 'Frühstücks-/Servicebedarf'];

  List<Map<String, dynamic>> get _filteredCatalog {
    return _catalog.where((item) {
      final matchesCategory = _selectedCategory == 'Alle' || item['category'] == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty || (item['name'] as String).toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  double get _cartTotal => _cart.fold(0, (s, i) => s + ((i['price'] as double) * (i['qty'] as int)));
  int get _cartCount => _cart.fold(0, (s, i) => s + (i['qty'] as int));

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadOrders();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadOrders() async {
    setState(() => _loadingOrders = true);
    try {
      final orders = await SupabaseService.getGwsShopOrders();
      if (mounted) setState(() { _shopOrders = orders; _loadingOrders = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingOrders = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _color,
        title: const Text('🛒 Shop / Bestellungen', style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Shop (${_filteredCatalog.length})'),
            Tab(text: 'Bestellungen (${_shopOrders.length})'),
          ],
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_cartCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                onPressed: _showCart,
                icon: Badge(
                  label: Text('$_cartCount'),
                  child: const Icon(Icons.shopping_cart),
                ),
              ),
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildShopTab(),
          _buildOrdersTab(),
        ],
      ),
    );
  }

  Widget _buildShopTab() {
    return Column(
      children: [
        // Objekt + Suche
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _selectedObjectId,
                decoration: const InputDecoration(labelText: 'Lieferung an Objekt', prefixIcon: Icon(Icons.hotel), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                items: widget.objects.map((o) => DropdownMenuItem<String>(value: o['id'].toString(), child: Text(o['name'] ?? '', style: const TextStyle(fontFamily: 'Inter')))).toList(),
                onChanged: (v) => setState(() => _selectedObjectId = v),
              ),
              const SizedBox(height: 8),
              TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Produkt suchen...',
                  prefixIcon: const Icon(Icons.search),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _categories.map((cat) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(cat, style: const TextStyle(fontFamily: 'Inter', fontSize: 12)),
                      selected: _selectedCategory == cat,
                      onSelected: (v) => setState(() => _selectedCategory = cat),
                      selectedColor: _color,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(color: _selectedCategory == cat ? Colors.white : AppTheme.textMain),
                    ),
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        // Ürün Listesi
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 200, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 0.75),
            itemCount: _filteredCatalog.length,
            itemBuilder: (ctx, i) {
              final item = _filteredCatalog[i];
              final cartItem = _cart.firstWhere((c) => c['name'] == item['name'], orElse: () => {});
              final qty = cartItem.isEmpty ? 0 : (cartItem['qty'] as int);

              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: qty > 0 ? _color : AppTheme.divider, width: qty > 0 ? 2 : 1),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(color: _color.withOpacity(0.08), borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(item['icon'] as IconData, size: 36, color: _color),
                            const SizedBox(height: 4),
                            Text(item['category'] as String, style: TextStyle(fontSize: 10, color: _color.withOpacity(0.7), fontFamily: 'Inter'), textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter', fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('€ ${(item['price'] as double).toStringAsFixed(2)}', style: TextStyle(color: _color, fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 12)),
                              Text(item['unit'] as String, style: const TextStyle(color: AppTheme.textSub, fontSize: 10, fontFamily: 'Inter')),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (qty == 0)
                            SizedBox(
                              width: double.infinity,
                              height: 30,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: _color, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                                onPressed: () => _addToCart(item),
                                child: const Text('+ Warenkorb', style: TextStyle(fontSize: 11, fontFamily: 'Inter')),
                              ),
                            )
                          else
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                IconButton(icon: const Icon(Icons.remove_circle, color: AppTheme.error, size: 20), onPressed: () => _decrementCart(item), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                                const SizedBox(width: 8),
                                Text('$qty', style: TextStyle(fontWeight: FontWeight.bold, color: _color, fontSize: 16, fontFamily: 'Inter')),
                                const SizedBox(width: 8),
                                IconButton(icon: Icon(Icons.add_circle, color: _color, size: 20), onPressed: () => _addToCart(item), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        if (_cartCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: _color,
              boxShadow: [BoxShadow(color: _color.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, -4))],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  const Icon(Icons.shopping_cart, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('$_cartCount Artikel', style: const TextStyle(color: Colors.white, fontFamily: 'Inter')),
                  const Spacer(),
                  Text('€ ${_cartTotal.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Inter')),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: _color, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: _showCart,
                    child: const Text('Bestellen', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOrdersTab() {
    if (_loadingOrders) return const Center(child: CircularProgressIndicator());
    if (_shopOrders.isEmpty) return const Center(child: Text('Noch keine Bestellungen', style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _shopOrders.length,
      itemBuilder: (ctx, i) {
        final order = _shopOrders[i];
        final items = (order['items'] as List?) ?? [];
        final obj = order['object'] as Map<String, dynamic>?;
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.divider)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: _color.withOpacity(0.05), borderRadius: const BorderRadius.vertical(top: Radius.circular(14))),
                child: Row(
                  children: [
                    Icon(Icons.shopping_cart_outlined, color: _color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(obj?['name'] ?? 'Objekt', style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter'))),
                    _statusBadge(order['status']),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${items.length} Artikel', style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter', fontSize: 13)),
                    if (order['notes'] != null && (order['notes'] as String).isNotEmpty)
                      Padding(padding: const EdgeInsets.only(top: 6), child: Text(order['notes'], style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter'))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statusBadge(String? status) {
    final labels = {'draft': 'Entwurf', 'bestellt': 'Bestellt', 'intern_geprüft': 'Geprüft', 'freigegeben': 'Freigegeben', 'geliefert': 'Geliefert', 'storniert': 'Storniert'};
    final colors = {'draft': AppTheme.textSub, 'bestellt': Colors.blue, 'intern_geprüft': Colors.orange, 'freigegeben': AppTheme.success, 'geliefert': AppTheme.success, 'storniert': AppTheme.error};
    final c = colors[status] ?? AppTheme.textSub;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(labels[status] ?? status ?? '', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w600, fontFamily: 'Inter')),
    );
  }

  void _addToCart(Map<String, dynamic> item) {
    setState(() {
      final idx = _cart.indexWhere((c) => c['name'] == item['name']);
      if (idx >= 0) {
        _cart[idx]['qty'] = (_cart[idx]['qty'] as int) + 1;
      } else {
        _cart.add({...item, 'qty': 1});
      }
    });
  }

  void _decrementCart(Map<String, dynamic> item) {
    setState(() {
      final idx = _cart.indexWhere((c) => c['name'] == item['name']);
      if (idx >= 0) {
        if ((_cart[idx]['qty'] as int) <= 1) {
          _cart.removeAt(idx);
        } else {
          _cart[idx]['qty'] = (_cart[idx]['qty'] as int) - 1;
        }
      }
    });
  }

  void _showCart() {
    final notesCtrl = TextEditingController();
    DateTime? desiredDate;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.4,
          expand: false,
          builder: (ctx, sc) => Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Icon(Icons.shopping_cart, color: _color),
                    const SizedBox(width: 8),
                    Text('Warenkorb ($_cartCount Artikel)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _color, fontFamily: 'Inter')),
                    const Spacer(),
                    TextButton(onPressed: () { setState(() => _cart.clear()); Navigator.pop(ctx); }, child: const Text('Leeren', style: TextStyle(color: AppTheme.error))),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: sc,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ..._cart.map((c) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(c['icon'] as IconData, color: _color),
                      title: Text(c['name'] as String, style: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600, fontSize: 14)),
                      subtitle: Text('${c['qty']} × € ${(c['price'] as double).toStringAsFixed(2)}', style: const TextStyle(fontFamily: 'Inter')),
                      trailing: Text('€ ${((c['price'] as double) * (c['qty'] as int)).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: _color, fontFamily: 'Inter')),
                    )),
                    const Divider(height: 24),
                    InkWell(
                      onTap: () async {
                        final d = await showDatePicker(context: context, initialDate: desiredDate ?? DateTime.now().add(const Duration(days: 1)), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 30)));
                        if (d != null) setLocal(() => desiredDate = d);
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Gewünschtes Lieferdatum', prefixIcon: Icon(Icons.local_shipping)),
                        child: Text(desiredDate == null ? 'Datum auswählen' : '${desiredDate!.day}.${desiredDate!.month}.${desiredDate!.year}', style: const TextStyle(fontFamily: 'Inter')),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(controller: notesCtrl, maxLines: 3, decoration: InputDecoration(labelText: 'Lieferhinweis / Notiz', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: _color.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gesamtbetrag:', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 15)),
                          Text('€ ${_cartTotal.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, color: _color, fontFamily: 'Inter', fontSize: 18)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: _color, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: _saving ? null : () async {
                      Navigator.pop(ctx);
                      await _submitOrder(notesCtrl.text, desiredDate);
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Bestellung absenden', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitOrder(String notes, DateTime? desiredDate) async {
    if (_selectedObjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte ein Objekt auswählen!'), backgroundColor: AppTheme.error));
      return;
    }
    setState(() => _saving = true);
    try {
      final appState = context.read<AppState>();
      await SupabaseService.createGwsShopOrder(
        {
          'object_id': _selectedObjectId,
          'ordered_by': appState.userId,
          'status': 'bestellt',
          'notes': notes.isEmpty ? null : notes,
          'desired_date': desiredDate?.toIso8601String().split('T')[0],
        },
        _cart.map((c) => {
          'product_name': c['name'],
          'category': c['category'],
          'quantity': c['qty'],
          'unit': c['unit'],
          'price': c['price'],
        }).toList(),
      );
      setState(() { _cart.clear(); _saving = false; });
      await _loadOrders();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bestellung abgeschickt ✓'), backgroundColor: AppTheme.success));
    } catch (e) {
      if (mounted) { setState(() => _saving = false); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e'), backgroundColor: AppTheme.error)); }
    }
  }
}
