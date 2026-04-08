import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
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
  List<Map<String, dynamic>> _departments = [];
  bool _loading = true;
  String _filterType = 'hepsi';
  String? _selectedFolderId; // Null means root/all, otherwise departmentId

  final List<_FilterOption> _typeFilters = [
    _FilterOption('hepsi', tr('Tümü')),
    _FilterOption('offer', tr('Teklif')),
    _FilterOption('contract', tr('Sözleşme')),
    _FilterOption('work_order', tr('İş Emri')),
    _FilterOption('photo', tr('Fotoğraf')),
    _FilterOption('pre_invoice', tr('Ön Fatura')),
    _FilterOption('final_invoice', tr('Fatura')),
    _FilterOption('other', tr('Diğer')),
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
      final depts = await SupabaseService.getDepartments();
      
      if (mounted) setState(() { 
        _docs = docs; 
        _departments = depts;
        _loading = false; 
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    var list = _docs;
    if (_filterType != 'hepsi') {
      list = list.where((d) => d['document_type'] == _filterType).toList();
    }
    if (_selectedFolderId != null) {
      list = list.where((d) {
        final docDeptId = d['department_id']?.toString() ?? d['order']?['department_id']?.toString();
        return docDeptId == _selectedFolderId;
      }).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedFolderId == null 
            ? tr('Belgeler Yönetimi') 
            : (_departments.firstWhere((d) => d['id'].toString() == _selectedFolderId, orElse: () => {'name': 'Klasör'})['name'] ?? 'Klasör')),
        leading: _selectedFolderId != null 
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => setState(() => _selectedFolderId = null))
            : null,
        actions: [
          if (appState.canManageDocuments)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: tr('Belge Ekle'),
              onPressed: () => _showAddDialog(context, appState),
            ),
        ],
      ),
      body: WebContentWrapper(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            // Filtre Şeridi
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

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedFolderId == null
                      ? _buildFoldersGrid(appState)
                      : _buildDocumentsList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoldersGrid(AppState appState) {
    // Sadece Bereichsleiter ise kendi departmanı, değilse tüm departmanlar
    var visibleDepts = _departments;
    if (appState.isBereichsleiter) {
        final assignedDeptName = appState.currentUser?['department']?['name'] as String?;
        final userSACompanies = appState.authorizedCompanyIds;
        visibleDepts = _departments.where((d) {
          final cid = d['company_id']?.toString() ?? '';
          if (userSACompanies.contains(cid)) return true;
          return assignedDeptName != null && d['name'].toString().toLowerCase().contains(assignedDeptName.toLowerCase());
        }).toList();
        if (visibleDepts.isEmpty && appState.departmentId.isNotEmpty) {
           visibleDepts = _departments.where((d) => d['id'].toString() == appState.departmentId).toList();
        }
    }

    if (visibleDepts.isEmpty) {
        return const Center(child: Text('Klasör bulunamadı'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: visibleDepts.length,
      itemBuilder: (context, index) {
        final dept = visibleDepts[index];
        final deptId = dept['id'].toString();
        // Count docs for this dept
        int docCount = _docs.where((d) {
           final dDept = d['department_id']?.toString() ?? d['order']?['department_id']?.toString();
           return dDept == deptId;
        }).length;

        return InkWell(
          onTap: () => setState(() => _selectedFolderId = deptId),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade200),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.folder_shared, size: 48, color: Colors.blue),
                const SizedBox(height: 12),
                Text(
                  dept['name'] ?? 'Bölüm',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueAccent),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '$docCount Belge',
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDocumentsList() {
    if (_filtered.isEmpty) {
      return Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.folder_open_outlined, size: 56, color: AppTheme.textSub.withOpacity(0.5)),
          const SizedBox(height: 12),
          Text(tr('Bu klasörde belge bulunamadı'), style: TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
        ]),
      );
    }

    return RefreshIndicator(
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
                  Text(tr('Yeni Belge Kaydı'),
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                  if (uploading)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: titleCtrl,
                enabled: !uploading,
                decoration: InputDecoration(labelText: tr('Belge Başlığı'), border: const OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedType,
                decoration: InputDecoration(labelText: tr('Belge Türü'), border: const OutlineInputBorder()),
                items: [
                  DropdownMenuItem(value: 'offer', child: Text(tr('Teklif'))),
                  DropdownMenuItem(value: 'approved_offer', child: Text(tr('Onaylı Teklif'))),
                  DropdownMenuItem(value: 'contract', child: Text(tr('Sözleşme'))),
                  DropdownMenuItem(value: 'addendum', child: Text(tr('Ek Protokol'))),
                  DropdownMenuItem(value: 'technical_spec', child: Text(tr('Teknik Şartname'))),
                  DropdownMenuItem(value: 'work_order', child: Text(tr('İş Emri'))),
                  DropdownMenuItem(value: 'work_report', child: Text(tr('İş Raporu'))),
                  DropdownMenuItem(value: 'photo', child: Text(tr('Fotoğraf'))),
                  DropdownMenuItem(value: 'pre_invoice', child: Text(tr('Ön Fatura'))),
                  DropdownMenuItem(value: 'final_invoice', child: Text(tr('Nihai Fatura'))),
                  DropdownMenuItem(value: 'other', child: Text(tr('Diğer'))),
                ],
                onChanged: uploading ? null : (v) => setM(() => selectedType = v!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: appState.isBereichsleiter ? appState.departmentId : null,
                decoration: InputDecoration(labelText: tr('Bölüm / Hizmet Alanı'), border: const OutlineInputBorder()),
                hint: Text(tr('Bölüm Seçin')),
                items: _departments.map((d) => DropdownMenuItem(
                  value: d['id'].toString(),
                  child: Text(d['name'] ?? ''),
                )).toList(),
                onChanged: (uploading || appState.isBereichsleiter) ? null : (v) => setM(() => _selectedFolderId = v),
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
                          selectedFile != null ? selectedFile!.name : tr('Dosya Seçin'),
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
                    child: Text(tr('İptal')),
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
                          'department_id': appState.isBereichsleiter ? appState.departmentId : _selectedFolderId,
                        };

                        await SupabaseService.createDocument(docData);

                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      } catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text('${tr('Hata')}: $e'))
                          );
                        }
                      } finally {
                        if (ctx.mounted) setM(() => uploading = false);
                      }
                    },
                    child: uploading 
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : Text(tr('Kaydet')),
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
      case 'offer':          return tr('Teklif');
      case 'approved_offer': return tr('Onaylı Teklif');
      case 'contract':       return tr('Sözleşme');
      case 'addendum':       return tr('Ek Protokol');
      case 'technical_spec': return tr('Teknik Şartname');
      case 'work_order':     return tr('İş Emri');
      case 'scope_list':     return tr('Kapsam Listesi');
      case 'excel':          return tr('Excel');
      case 'photo':          return tr('Fotoğraf');
      case 'video':          return tr('Video');
      case 'client_note':    return tr('Müşteri Notu');
      case 'delivery_form':  return tr('Teslim Formu');
      case 'work_report':     return tr('İş Raporu');
      case 'pre_invoice':    return tr('Ön Fatura');
      case 'final_invoice':  return tr('Nihai Fatura');
      default:               return tr('Diğer');
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
                      child: Text(tr('Eski Sürüm'),
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
        title: Text(tr('Silme Onayı'), style: const TextStyle(fontFamily: 'Inter')),
        content: Text(tr('Bu belgeyi kalıcı olarak silmek istediğinize emin misiniz? Sistemden ve depolama alanından tamamen kaldırılacaktır.'), style: const TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('İptal'))),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('Sil'), style: const TextStyle(color: AppTheme.error)),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Belge başarıyla silindi'))));
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
        SnackBar(content: Text(tr('Geçersiz dosya bağlantısı.')))
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(isShare ? tr('Paylaşım hazırlanıyor...') : tr('Belge indiriliyor...')), duration: const Duration(seconds: 2))
    );

    setState(() => _loading = true);
    try {
      final url = widget.doc['file_url'] as String;
      final fileName = widget.doc['file_name'] as String? ?? tr('belge');

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Hata')}: $e')));
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
          tooltip: tr('Ansehen / Teilen'), // Changing tooltip description to German directly or tr() if available,
          onPressed: () => _handleAction(context, true),
        ),
        if (context.read<AppState>().canManageDocuments)
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error),
            tooltip: tr('Sil'),
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
