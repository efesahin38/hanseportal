import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';

/// Interne PQ – Firmenunterlagen-Ablage
class InternePqScreen extends StatefulWidget {
  const InternePqScreen({super.key});
  @override
  State<InternePqScreen> createState() => _InternePqScreenState();
}

class _InternePqScreenState extends State<InternePqScreen> {
  List<Map<String, dynamic>> _docs = [];
  bool _loading = true;
  String _selectedCategory = 'Alle';

  final _categories = [
    'Alle',
    'Gewerbeschein',
    'Handelsregister',
    'Versicherungen',
    'Zertifizierungen',
    'Referenzen',
    'Präqualifikation',
    'Unbedenklichkeitsbescheinigungen',
    'Sonstige',
  ];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final companyId = context.read<AppState>().companyId;
      final docs = await SupabaseService.getPqDocuments(
        companyId: companyId,
        category: _selectedCategory == 'Alle' ? null : _selectedCategory,
      );
      if (mounted) setState(() { _docs = docs; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _uploadDoc() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;

    String? selectedCat = _selectedCategory == 'Alle' ? _categories[1] : _selectedCategory;
    final titleCtrl = TextEditingController(text: file.name.split('.').first);

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          title: Text(tr('Dokument hochladen')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: titleCtrl, decoration: InputDecoration(labelText: tr('Titel'))),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedCat,
                decoration: InputDecoration(labelText: tr('Kategorie')),
                items: _categories.where((c) => c != 'Alle').map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setDState(() => selectedCat = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('Abbrechen'))),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('Hochladen'))),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final url = await SupabaseService.uploadPqDocument(file.name, file.bytes!);
      await SupabaseService.createPqDocument({
        'company_id': context.read<AppState>().companyId,
        'category': selectedCat,
        'title': titleCtrl.text.trim(),
        'file_url': url,
        'file_name': file.name,
        'file_size_kb': (file.size / 1024).round(),
        'uploaded_by': context.read<AppState>().userId,
      });
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Fehler')}: $e')));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('Interne PQ'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploadDoc,
        icon: const Icon(Icons.upload_file),
        label: Text(tr('Dokument hochladen')),
      ),
      body: WebContentWrapper(
        child: Column(
          children: [
            // Category Filter
            SizedBox(
              height: 48,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: _categories.length,
                itemBuilder: (_, i) {
                  final cat = _categories[i];
                  final isSelected = _selectedCategory == cat;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8, top: 8),
                    child: ChoiceChip(
                      label: Text(cat, style: TextStyle(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      selected: isSelected,
                      onSelected: (_) { setState(() { _selectedCategory = cat; _loading = true; }); _load(); },
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _docs.isEmpty
                      ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.folder_open, size: 56, color: AppTheme.textSub),
                          const SizedBox(height: 12),
                          Text(tr('Keine Dokumente vorhanden'), style: const TextStyle(color: AppTheme.textSub)),
                        ]))
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: _docs.length,
                            itemBuilder: (_, i) {
                              final d = _docs[i];
                              return Card(
                                child: ListTile(
                                  leading: Container(
                                    width: 40, height: 40,
                                    decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.description, color: AppTheme.primary),
                                  ),
                                  title: Text(d['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, fontFamily: 'Inter')),
                                  subtitle: Text('${d['category'] ?? ''} • ${d['file_name'] ?? ''}', style: const TextStyle(fontSize: 11, color: AppTheme.textSub)),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (v) async {
                                      if (v == 'delete') {
                                        await SupabaseService.deletePqDocument(d['id'], d['file_url'] ?? '');
                                        _load();
                                      }
                                    },
                                    itemBuilder: (_) => [
                                      PopupMenuItem(value: 'delete', child: Text(tr('Löschen'), style: const TextStyle(color: AppTheme.error))),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
