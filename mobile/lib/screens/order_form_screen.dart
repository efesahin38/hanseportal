import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/supabase_service.dart';

/// Yeni iş / mevcut iş düzenleme formu
class OrderFormScreen extends StatefulWidget {
  final String? orderId; // null = yeni oluştur
  const OrderFormScreen({super.key, this.orderId});

  @override
  State<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends State<OrderFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _shortDesc = TextEditingController();
  final _siteAddress = TextEditingController();
  final _customerRef = TextEditingController();
  final _notes = TextEditingController();

  String? _selectedCompanyId;
  String? _selectedCustomerId;
  String? _selectedServiceAreaId;
  String _priority = 'normal';
  DateTime? _startDate;
  DateTime? _endDate;
  bool _saving = false;

  List<Map<String, dynamic>> _companies = [];
  List<Map<String, dynamic>> _customers = [];
  List<Map<String, dynamic>> _serviceAreas = [];

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
    if (widget.orderId != null) _loadOrder();
  }

  Future<void> _loadDropdowns() async {
    final companies = await SupabaseService.getCompanies(status: 'active');
    final customers = await SupabaseService.getCustomers(status: 'active');
    final serviceAreas = await SupabaseService.getServiceAreas();
    if (mounted) setState(() {
      _companies = companies;
      _customers = customers;
      _serviceAreas = serviceAreas;
    });
  }

  Future<void> _loadOrder() async {
    final order = await SupabaseService.getOrder(widget.orderId!);
    if (order != null && mounted) {
      setState(() {
        _title.text = order['title'] ?? '';
        _shortDesc.text = order['short_description'] ?? '';
        _siteAddress.text = order['site_address'] ?? '';
        _customerRef.text = order['customer_ref_number'] ?? '';
        _notes.text = order['notes'] ?? '';
        _selectedCompanyId = order['company_id'];
        _selectedCustomerId = order['customer_id'];
        _selectedServiceAreaId = order['service_area_id'];
        _priority = order['priority'] ?? 'normal';
        if (order['planned_start_date'] != null) _startDate = DateTime.parse(order['planned_start_date']);
        if (order['planned_end_date'] != null) _endDate = DateTime.parse(order['planned_end_date']);
      });
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => isStart ? _startDate = picked : _endDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCompanyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir şirket seçin')));
      return;
    }
    if (_selectedCustomerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir müşteri seçin')));
      return;
    }
    if (_selectedServiceAreaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen bir hizmet alanı seçin')));
      return;
    }
    setState(() => _saving = true);
    try {
      final data = {
        if (widget.orderId != null) 'id': widget.orderId,
        'title': _title.text.trim(),
        'short_description': _shortDesc.text.trim(),
        'site_address': _siteAddress.text.trim(),
        'customer_ref_number': _customerRef.text.trim(),
        'notes': _notes.text.trim(),
        'company_id': _selectedCompanyId,
        'customer_id': _selectedCustomerId,
        'service_area_id': _selectedServiceAreaId,
        'priority': _priority,
        'status': 'draft',
        if (_startDate != null) 'planned_start_date': _startDate!.toIso8601String().split('T')[0],
        if (_endDate != null) 'planned_end_date': _endDate!.toIso8601String().split('T')[0],
      };
      if (widget.orderId == null) {
        await SupabaseService.createOrder(data);
      } else {
        await SupabaseService.client.from('orders').update(data).eq('id', widget.orderId!);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.orderId == null ? 'Yeni İş' : 'İş Düzenle')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _section('Temel Bilgiler'),
            _textField('İş Başlığı *', _title, required: true),
            _textField('Kısa Açıklama', _shortDesc, maxLines: 2),
            _textField('Saha Adresi', _siteAddress),
            _textField('Müşteri Sipariş No', _customerRef),
            const SizedBox(height: 16),
            _section('Bağlantı'),
            _dropdown('Şirket *', _companies, _selectedCompanyId, 'name', (v) => setState(() => _selectedCompanyId = v)),
            const SizedBox(height: 12),
            _dropdown('Müşteri *', _customers, _selectedCustomerId, 'name', (v) => setState(() => _selectedCustomerId = v)),
            const SizedBox(height: 12),
            _dropdown('Hizmet Alanı *', _serviceAreas, _selectedServiceAreaId, 'name', (v) => setState(() => _selectedServiceAreaId = v)),
            const SizedBox(height: 16),
            _section('Öncelik & Tarih'),
            DropdownButtonFormField<String>(
              value: _priority,
              decoration: const InputDecoration(labelText: 'Öncelik'),
              items: [
                const DropdownMenuItem(value: 'low', child: Text('Düşük')),
                const DropdownMenuItem(value: 'normal', child: Text('Normal')),
                const DropdownMenuItem(value: 'high', child: Text('Yüksek')),
                const DropdownMenuItem(value: 'urgent', child: Text('🔴 Acil')),
              ],
              onChanged: (v) => setState(() => _priority = v!),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _dateTile('Başlangıç', _startDate, () => _pickDate(true))),
              const SizedBox(width: 12),
              Expanded(child: _dateTile('Bitiş', _endDate, () => _pickDate(false))),
            ]),
            const SizedBox(height: 16),
            _section('Notlar'),
            _textField('Notlar', _notes, maxLines: 4),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(widget.orderId == null ? 'İş Oluştur' : 'Kaydet'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _section(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.textSub, fontFamily: 'Inter')),
  );

  Widget _textField(String label, TextEditingController ctrl, {bool required = false, int maxLines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: required ? (v) => (v == null || v.isEmpty) ? 'Zorunlu alan' : null : null,
    ),
  );

  Widget _dropdown(String label, List<Map<String, dynamic>> items, String? value, String nameKey, ValueChanged<String?> onChanged) =>
    DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(labelText: label),
      isExpanded: true,
      items: items.map((i) => DropdownMenuItem<String>(
        value: i['id'].toString(),
        child: Text(i[nameKey] ?? '', style: const TextStyle(fontFamily: 'Inter', fontSize: 14), overflow: TextOverflow.ellipsis),
      )).toList(),
      onChanged: onChanged,
    );

  Widget _dateTile(String label, DateTime? date, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.border),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
        const SizedBox(height: 2),
        Text(
          date == null ? 'Seçiniz' : '${date.day}.${date.month.toString().padLeft(2, '0')}.${date.year}',
          style: TextStyle(fontSize: 14, fontFamily: 'Inter', color: date == null ? AppTheme.textSub : AppTheme.textMain),
        ),
      ]),
    ),
  );
}
