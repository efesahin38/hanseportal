import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../utils/platform_helper.dart'; // PlatformHelper ekle
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';

/// Bölüm 5 – Belge ve Dosya Yönetimi
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({super.key});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  List<Map<String, dynamic>> _docs = [];
  bool _loading = true;
  String _filterType = 'hepsi';

  final List<_FilterOption> _typeFilters = const [
    _FilterOption('hepsi', 'Tümü'),
    _FilterOption('offer', 'Teklif'),
    _FilterOption('contract', 'Sözleşme'),
    _FilterOption('work_order', 'İş Emri'),
    _FilterOption('photo', 'Fotoğraf'),
    _FilterOption('pre_invoice', 'Ön Fatura'),
    _FilterOption('work_report', 'İş Raporu'),
    _FilterOption('final_invoice', 'Fatura'),
    _FilterOption('other', 'Diğer'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final appState = context.read<AppState>();
    try {
      final departmentId = appState.isBereichsleiter ? appState.departmentId : null;
      final docs = await SupabaseService.getDocuments(
        departmentId: departmentId,
      );
      if (mounted) setState(() { _docs = docs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filterType == 'hepsi') return _docs;
    return _docs.where((d) => d['document_type'] == _filterType).toList();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Belgeler'),
        actions: [
          if (appState.canManageDocuments)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Belge Ekle',
              onPressed: () => _showAddDialog(context, appState),
            ),
        ],
      ),
      body: WebContentWrapper(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // ── Filtre Şeridi ──────────────────────────────────
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                itemCount: _typeFilters.length,
                itemBuilder: (_, i) {
                  final f = _typeFilters[i];
                  final selected = _filterType == f.value;
                  return GestureDetector(
                    onTap: () => setState(() => _filterType = f.value),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected ? AppTheme.primary : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected ? AppTheme.primary : AppTheme.border,
                        ),
                      ),
                      child: Text(
                        f.label,
                        style: TextStyle(
                          color: selected ? Colors.white : AppTheme.textSub,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),

            // ── Liste ──────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty
                      ? Center(
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.folder_open_outlined, size: 56, color: AppTheme.textSub.withOpacity(0.5)),
                            const SizedBox(height: 12),
                            const Text('Belge bulunamadı',
                                style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                          ]),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 4),
                            itemBuilder: (_, i) => _DocumentCard(
                              doc: _filtered[i],
                              onDeleted: _load,
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, AppState appState) async {
    final titleCtrl = TextEditingController();
    String selectedType = 'other';
    PlatformFile? selectedFile;
    bool uploading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !uploading,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Yeni Belge Kaydı',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                  if (uploading)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleCtrl,
                enabled: !uploading,
                decoration: const InputDecoration(labelText: 'Belge Başlığı', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: const InputDecoration(labelText: 'Belge Türü', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'offer', child: Text('Teklif')),
                  DropdownMenuItem(value: 'approved_offer', child: Text('Onaylı Teklif')),
                  DropdownMenuItem(value: 'contract', child: Text('Sözleşme')),
                  DropdownMenuItem(value: 'addendum', child: Text('Ek Protokol')),
                  DropdownMenuItem(value: 'technical_spec', child: Text('Teknik Şartname')),
                  DropdownMenuItem(value: 'work_order', child: Text('İş Emri')),
                  DropdownMenuItem(value: 'work_report', child: Text('İş Raporu')),
                  DropdownMenuItem(value: 'photo', child: Text('Fotoğraf')),
                  DropdownMenuItem(value: 'pre_invoice', child: Text('Ön Fatura')),
                  DropdownMenuItem(value: 'final_invoice', child: Text('Nihai Fatura')),
                  DropdownMenuItem(value: 'other', child: Text('Diğer')),
                ],
                onChanged: uploading ? null : (v) => setM(() => selectedType = v!),
              ),
              const SizedBox(height: 16),
              
              // Dosya Seçme Alanı
              InkWell(
                onTap: uploading ? null : () async {
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.any,
                    withData: true,
                  );
                  if (result != null) {
                    setM(() {
                      selectedFile = result.files.first;
                      if (titleCtrl.text.isEmpty) {
                        titleCtrl.text = selectedFile!.name;
                      }
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selectedFile != null ? AppTheme.primary : AppTheme.divider, style: BorderStyle.solid),
                  ),
                  child: Row(
                    children: [
                      Icon(selectedFile != null ? Icons.file_present : Icons.upload_file, 
                           color: selectedFile != null ? AppTheme.primary : AppTheme.textSub),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          selectedFile != null ? selectedFile!.name : 'Dosya Seçin',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            color: selectedFile != null ? AppTheme.textMain : AppTheme.textSub,
                            fontWeight: selectedFile != null ? FontWeight.w600 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (selectedFile != null)
                        const Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 20),
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: uploading ? null : () => Navigator.pop(ctx),
                    child: const Text('İptal'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (uploading || titleCtrl.text.trim().isEmpty || selectedFile == null) ? null : () async {
                      setM(() => uploading = true);
                      try {
                        // 1. Dosyayı Yükle
                        final fileUrl = await SupabaseService.uploadDocument(
                          selectedFile!.name,
                          selectedFile!.bytes!,
                        );

                        // 2. Kaydı Oluştur
                        final Map<String, dynamic> docData = {
                          'title': titleCtrl.text.trim(),
                          'document_type': selectedType,
                          'file_url': fileUrl,
                          'uploaded_by': appState.userId,
                          'file_name': selectedFile!.name,
                          'file_size_kb': (selectedFile!.size / 1024).round(),
                          'file_mime': selectedFile!.extension,
                          'visibility_roles': [
                            'geschaeftsfuehrer', 
                            'betriebsleiter', 
                            'bereichsleiter', 
                            'backoffice', 
                            'system_admin',
                            'buchhaltung'
                          ],
                        };

                        await SupabaseService.createDocument(docData);

                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('Hata: $e'))
                          );
                        }
                      } finally {
                        if (ctx.mounted) setM(() => uploading = false);
                      }
                    },
                    child: uploading 
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text('Kaydet'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onDeleted;
  const _DocumentCard({required this.doc, required this.onDeleted});

  String _typeLabel(String? t) {
    switch (t) {
      case 'offer':          return 'Teklif';
      case 'approved_offer': return 'Onaylı Teklif';
      case 'contract':       return 'Sözleşme';
      case 'addendum':       return 'Ek Protokol';
      case 'technical_spec': return 'Teknik Şartname';
      case 'work_order':     return 'İş Emri';
      case 'scope_list':     return 'Kapsam Listesi';
      case 'excel':          return 'Excel';
      case 'photo':          return 'Fotoğraf';
      case 'video':          return 'Video';
      case 'client_note':    return 'Müşteri Notu';
      case 'delivery_form':  return 'Teslim Formu';
      case 'work_report':     return 'İş Raporu';
      case 'pre_invoice':    return 'Ön Fatura';
      case 'final_invoice':  return 'Nihai Fatura';
      default:               return 'Diğer';
    }
  }

  Color _typeColor(String? t) {
    switch (t) {
      case 'contract':
      case 'approved_offer': return AppTheme.success;
      case 'offer':          return AppTheme.info;
      case 'photo':
      case 'video':          return Colors.purple;
      case 'pre_invoice':
      case 'final_invoice':  return AppTheme.warning;
      default:               return AppTheme.textSub;
    }
  }

  IconData _typeIcon(String? t) {
    switch (t) {
      case 'photo':          return Icons.image_outlined;
      case 'video':          return Icons.videocam_outlined;
      case 'excel':          return Icons.table_chart_outlined;
      case 'contract':
      case 'approved_offer': return Icons.gavel_outlined;
      case 'pre_invoice':
      case 'final_invoice':  return Icons.receipt_outlined;
      default:               return Icons.description_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = doc['document_type'] as String?;
    final uploader = doc['uploaded_by_user'];
    final uploaderName = uploader != null
        ? '${uploader['first_name'] ?? ''} ${uploader['last_name'] ?? ''}'.trim()
        : '';
    final version = doc['version'] as int? ?? 1;
    final isCurrent = doc['is_current'] as bool? ?? true;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _typeColor(type).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_typeIcon(type), color: _typeColor(type), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      doc['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Inter'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!isCurrent)
                    Container(
                      margin: const EdgeInsets.only(left: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.textSub.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('Eski Sürüm',
                          style: TextStyle(fontSize: 9, color: AppTheme.textSub, fontFamily: 'Inter')),
                    ),
                ]),
                const SizedBox(height: 4),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _typeColor(type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(_typeLabel(type),
                        style: TextStyle(fontSize: 10, color: _typeColor(type), fontWeight: FontWeight.w600, fontFamily: 'Inter')),
                  ),
                  if (version > 1) ...[ 
                    const SizedBox(width: 6),
                    Text('v$version', style: const TextStyle(fontSize: 10, color: AppTheme.textSub, fontFamily: 'Inter')),
                  ],
                ]),
                if (uploaderName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(uploaderName,
                      style: const TextStyle(fontSize: 10, color: AppTheme.textSub, fontFamily: 'Inter')),
                ],
              ]),
            ),
            
            // Aksiyon Butonları
            _ActionButtons(doc: doc, onDeleted: onDeleted),
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatefulWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onDeleted;
  const _ActionButtons({required this.doc, required this.onDeleted});

  @override
  State<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends State<_ActionButtons> {
  bool _loading = false;

  Future<void> _deleteDocument() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Silme Onayı', style: TextStyle(fontFamily: 'Inter')),
        content: const Text('Bu belgeyi kalıcı olarak silmek istediğinize emin misiniz? Sistemden ve depolama alanından tamamen kaldırılacaktır.', style: TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Sil', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final docId = widget.doc['id'].toString();
      final fileUrl = widget.doc['file_url'].toString();
      await SupabaseService.deleteDocument(docId, fileUrl);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Belge başarıyla silindi')));
        widget.onDeleted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silme işlemi başarısız: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAction(BuildContext context, bool isShare) async {
    final url = widget.doc['file_url'] as String?;
    final fileName = widget.doc['file_name'] as String? ?? 'belge';
    
    if (url == null || url.isEmpty || url == 'placeholder') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Geçersiz dosya bağlantısı.'))
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isShare ? 'Paylaşım hazırlanıyor...' : 'Belge indiriliyor...'), duration: const Duration(seconds: 2))
    );

    setState(() => _loading = true);
    try {
      final url = widget.doc['file_url'] as String;
      final fileName = widget.doc['file_name'] as String? ?? 'belge';

      if (kIsWeb) {
        await launchUrl(Uri.parse(url));
        if (mounted) setState(() => _loading = false);
        return;
      }

      // Mobil için devam
      final bytes = await SupabaseService.downloadDocument(url);
      if (!mounted) return;

      String safeFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9.]'), '_');
      if (!safeFileName.contains('.')) {
        final ext = url.split('.').last.split('?').first;
        safeFileName = '$safeFileName.$ext';
      }

      await PlatformHelper.saveAndOpenFile(
        bytes: Uint8List.fromList(bytes),
        fileName: safeFileName,
        title: widget.doc['title'] ?? 'Belge',
        isShare: isShare,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.share_outlined, size: 20, color: AppTheme.primary),
          tooltip: 'Görüntüle / Paylaş',
          onPressed: () => _handleAction(context, true),
        ),
        if (context.read<AppState>().canManageDocuments)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
            tooltip: 'Sil',
            onPressed: _deleteDocument,
          ),
      ],
    );
  }
}

class _FilterOption {
  final String value;
  final String label;
  const _FilterOption(this.value, this.label);
}
