import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import '../widgets/signature_pad_widget.dart';
import 'package:image_picker/image_picker.dart';

class GwsItemFormScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  final String type; // 'room' | 'area'
  final bool isExternalManager;

  const GwsItemFormScreen({
    super.key,
    required this.item,
    required this.type,
    this.isExternalManager = false,
  });

  @override
  State<GwsItemFormScreen> createState() => _GwsItemFormScreenState();
}

class _GwsItemFormScreenState extends State<GwsItemFormScreen> {
  final _workerNotes = TextEditingController();
  final _checkerNotes = TextEditingController();
  final _customerComment = TextEditingController();
  String? _checkerStatus;
  Map<String, bool> _checklist = {};
  List<String> _photos = [];
  String? _signatureBase64;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    final itm = widget.item;
    _workerNotes.text = itm['worker_notes'] ?? '';
    _checkerNotes.text = itm['checker_notes'] ?? '';
    _checkerStatus = itm['checker_status'] ?? 'pending';
    
    // Load checklist
    final data = itm['checklist_data'] as Map? ?? {};
    final defaultItems = widget.type == 'room' 
        ? ['Bett gemacht', 'Bad sauber', 'Müll geleert', 'Boden gesaugt']
        : ['Boden gewischt', 'Flächen desinfiziert', 'Glas gereinigt'];
    
    for (var label in defaultItems) {
      _checklist[label] = data[label] == true;
    }
    
    _photos = List<String>.from(itm['photos'] ?? []);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await SupabaseService.updateGwsItemDetails(
        type: widget.type,
        id: widget.item['id'],
        checklistData: _checklist,
        workerNotes: _workerNotes.text.trim(),
        photos: _photos,
        checkerStatus: _checkerStatus,
        checkerNotes: _checkerNotes.text.trim(),
        status: _checkerStatus == 'ok' ? 'checked' : 'done',
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (image != null) {
      // In a real app, upload to storage and get URL
      // For now, we simulate with a placeholder path or small base64
      setState(() => _photos.add('Sample photo path'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final itm = widget.item;
    final isWorker = !widget.isExternalManager && appState.role == 'mitarbeiter';
    final isLeader = !widget.isExternalManager && (appState.role == 'vorarbeiter' || appState.fullName == 'Fatma' || appState.role == 'bereichsleiter');

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.type == 'room' ? 'Zimmer ${itm['room_number']}' : '${itm['area_name']}'),
        backgroundColor: AppTheme.gwsColor,
        actions: [
          if (!widget.isExternalManager)
            IconButton(icon: const Icon(Icons.save), onPressed: _save),
        ],
      ),
      body: WebContentWrapper(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionHeader('Checkliste'),
            ..._checklist.keys.map((key) => CheckboxListTile(
              title: Text(key, style: const TextStyle(fontFamily: 'Inter')),
              value: _checklist[key],
              onChanged: widget.isExternalManager ? null : (v) => setState(() => _checklist[key] = v!),
              activeColor: AppTheme.gwsColor,
            )),
            
            const SizedBox(height: 16),
            _sectionHeader('Mitarbeiter Notizen'),
            TextField(
              controller: _workerNotes,
              readOnly: widget.isExternalManager || !isWorker,
              maxLines: 3,
              decoration: const InputDecoration(hintText: 'Hinweise zur Durchführung...'),
            ),

            const SizedBox(height: 16),
            _sectionHeader('Fotos'),
            Wrap(
              spacing: 8,
              children: [
                ..._photos.map((p) => Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.image, color: Colors.grey),
                )),
                if (isWorker)
                  InkWell(
                    onTap: _pickImage,
                    child: Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.add_a_photo, color: AppTheme.gwsColor),
                    ),
                  ),
              ],
            ),

            if (isLeader || widget.isExternalManager) ...[
              const Divider(height: 48),
              _sectionHeader('Kontrolle (Teamleiter)'),
              Row(
                children: [
                  _statusChip('ok', 'Kayıpsız / OK', Colors.green, _checkerStatus == 'ok', (sel) {
                    if (sel) setState(() => _checkerStatus = 'ok');
                  }),
                  const SizedBox(width: 8),
                  _statusChip('fehler', 'Hata Bildir', Colors.red, _checkerStatus == 'fehler', (sel) {
                    if (sel) setState(() => _checkerStatus = 'fehler');
                  }),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _checkerNotes,
                readOnly: widget.isExternalManager,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Kontrol notları...'),
              ),
            ],

            if (widget.isExternalManager) ...[
              const Divider(height: 48),
              _sectionHeader('Kundenfeedback & Unterschrift'),
              TextField(
                controller: _customerComment,
                maxLines: 3,
                decoration: const InputDecoration(hintText: 'Ihre Anmerkungen...'),
              ),
              const SizedBox(height: 16),
              const Text('Bitte hier unterschreiben:', style: TextStyle(fontSize: 12, color: AppTheme.textSub)),
              const SizedBox(height: 8),
              SignaturePadWidget(
                color: AppTheme.gwsColor,
                onSigned: (b64) => _signatureBase64 = b64,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.gwsColor, padding: const EdgeInsets.symmetric(vertical: 16)),
                onPressed: () async {
                  if (_signatureBase64 == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yolla butona basmadan önce imza atınız.')));
                    return;
                  }
                  // Burada tüm planı onaylama işlemi yapılır (planId lazım)
                  // Bu prototipte ana ekrana döner.
                  Navigator.pop(context);
                },
                child: const Text('Bitti ve Şirkete Geri Yolla', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(title.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textSub, letterSpacing: 0.5)),
    );
  }

  Widget _statusChip(String value, String label, Color color, bool selected, Function(bool) onSelected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: widget.isExternalManager ? null : onSelected,
      selectedColor: color.withOpacity(0.2),
      checkmarkColor: color,
      labelStyle: TextStyle(color: selected ? color : Colors.grey, fontWeight: selected ? FontWeight.bold : FontWeight.normal),
    );
  }
}
