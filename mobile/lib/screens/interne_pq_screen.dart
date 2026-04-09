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

// Die vier Bereiche (Abteilungen), die bei jedem Eintrag gewählt werden müssen
const List<String> kDepartmentOptions = [
  'Gebäudedienstleistungen',
  'Rail Service',
  'Gastwirtschaftsservice',
  'Personalüberlassung',
];

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

  // ── Bereichsleiter-spezifische Filterung ─────────────────
  /// Gibt den Bereichsnamen des angemeldeten Bereichsleiters zurück.
  /// Für alle anderen Rollen → null (keine Filterung).
  String? _bereichsleiterDepartment(AppState appState) {
    if (!appState.isBereichsleiter) return null;
    // Der Bereichsname kommt aus department.name im Profil
    return appState.currentUser?['department']?['name'] as String?;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<AppState>().refreshProfile();
      _load();
    });
  }

  Future<void> _load() async {
    try {
      final appState = context.read<AppState>();
      final companyId = appState.companyId;
      final dept = _bereichsleiterDepartment(appState);
      final docs = await SupabaseService.getPqDocuments(
        companyId: companyId,
        category: _selectedCategory == 'Alle' ? null : _selectedCategory,
        department: dept, // null → alle Abteilungen sichtbar
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
    String? selectedDept = kDepartmentOptions.first;
    final appState = context.read<AppState>();

    // Falls Bereichsleiter → Abteilung vorbelegen und nicht änderbar
    final bereichDept = _bereichsleiterDepartment(appState);
    if (bereichDept != null) selectedDept = bereichDept;

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
              const SizedBox(height: 12),
              // Abteilung-Auswahl (für Bereichsleiter fest vorbelegt)
              if (bereichDept != null)
                InputDecorator(
                  decoration: InputDecoration(labelText: tr('Abteilung')),
                  child: Text(bereichDept, style: const TextStyle(fontSize: 14)),
                )
              else
                DropdownButtonFormField<String>(
                  value: selectedDept,
                  decoration: InputDecoration(labelText: '${tr('Abteilung')} *'),
                  items: kDepartmentOptions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setDState(() => selectedDept = v),
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
        'company_id': appState.companyId,
        'category': selectedCat,
        'title': titleCtrl.text.trim(),
        'file_url': url,
        'file_name': file.name,
        'file_size_kb': (file.size / 1024).round(),
        'uploaded_by': appState.userId,
        'department': selectedDept, // Pflichtfeld
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
    final appState = context.read<AppState>();
    final companyName = appState.currentUser?['company']?['name'] ?? tr('Interne PQ');
    return Scaffold(
      appBar: AppBar(
        title: Text(appState.isBereichsleiter ? '$companyName - PQ' : tr('Interne PQ')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _uploadDoc,
        icon: const Icon(Icons.upload_file),
        label: Text(tr('Dokument hochladen')),
      ),
      body: WebContentWrapper(
        child: Column(
          children: [
            // Kategorie-Filter
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
                          child: Builder(builder: (context) {
                            // Group by department
                            final groupedDocs = <String, List<Map<String, dynamic>>>{};
                            for (var d in _docs) {
                              final dep = d['department'] ?? 'Allgemein (Genel)';
                              groupedDocs.putIfAbsent(dep, () => []).add(d);
                            }
                            
                            return ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: groupedDocs.keys.length,
                              itemBuilder: (_, i) {
                                final dep = groupedDocs.keys.elementAt(i);
                                final depDocs = groupedDocs[dep]!;
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  child: ExpansionTile(
                                    leading: const Icon(Icons.folder, color: AppTheme.primary),
                                    title: Text(dep, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                                    subtitle: Text('${depDocs.length} ${tr('Dokumente')}', style: const TextStyle(fontSize: 12, color: AppTheme.textSub)),
                                    initiallyExpanded: true,
                                    children: depDocs.map((d) {
                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                        leading: Container(
                                          width: 40, height: 40,
                                          decoration: BoxDecoration(color: AppTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                          child: const Icon(Icons.insert_drive_file, color: AppTheme.primary, size: 20),
                                        ),
                                        title: Text(d['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Inter')),
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
                                      );
                                    }).toList(),
                                  ),
                                );
                              },
                            );
                          }),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
