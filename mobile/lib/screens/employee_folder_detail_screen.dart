import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import '../utils/platform_helper.dart';

/// Yönetici Ekranı – Seçilen klasörün belgeleri (yükle / sil / görüntüle)
class EmployeeFolderDetailScreen extends StatefulWidget {
  final Map<String, dynamic> folder;
  final Map<String, dynamic> employee;

  const EmployeeFolderDetailScreen({
    super.key,
    required this.folder,
    required this.employee,
  });

  @override
  State<EmployeeFolderDetailScreen> createState() => _EmployeeFolderDetailScreenState();
}

class _EmployeeFolderDetailScreenState extends State<EmployeeFolderDetailScreen> {
  List<Map<String, dynamic>> _docs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final docs = await SupabaseService.getEmployeeDocuments(widget.folder['id'].toString());
      if (mounted) setState(() { _docs = docs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showUploadDialog(BuildContext context, AppState appState) async {
    final titleCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    PlatformFile? selectedFile;
    bool uploading = false;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setM) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('Dokument hochladen'),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                      Text(widget.folder['folder_name'] ?? '',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSub, fontFamily: 'Inter')),
                    ],
                  ),
                  if (uploading)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ],
              ),
              const SizedBox(height: 20),

              // Belge başlığı
              TextField(
                controller: titleCtrl,
                enabled: !uploading,
                decoration: InputDecoration(
                  labelText: tr('Dokumenttitel'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 12),

              // Notlar
              TextField(
                controller: notesCtrl,
                enabled: !uploading,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: tr('Notizen (optional)'),
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.note_outlined),
                ),
              ),
              const SizedBox(height: 12),

              // Dosya seçimi
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
                        titleCtrl.text = selectedFile!.name.split('.').first;
                      }
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: selectedFile != null
                        ? AppTheme.primary.withOpacity(0.05)
                        : AppTheme.bg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selectedFile != null ? AppTheme.primary : AppTheme.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selectedFile != null ? Icons.file_present : Icons.upload_file,
                        color: selectedFile != null ? AppTheme.primary : AppTheme.textSub,
                        size: 26,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedFile != null ? selectedFile!.name : tr('Datei auswählen'),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: selectedFile != null ? FontWeight.w600 : FontWeight.normal,
                                color: selectedFile != null ? AppTheme.textMain : AppTheme.textSub,
                              ),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                            if (selectedFile != null)
                              Text(
                                '${(selectedFile!.size / 1024).round()} KB',
                                style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter'),
                              ),
                          ],
                        ),
                      ),
                      if (selectedFile != null)
                        const Icon(Icons.check_circle, color: AppTheme.success, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Butonlar
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: uploading ? null : () => Navigator.pop(ctx),
                    child: Text(tr('Abbrechen')),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: (uploading || titleCtrl.text.trim().isEmpty || selectedFile == null)
                        ? null
                        : () async {
                            setM(() => uploading = true);
                            try {
                              final fileUrl = await SupabaseService.uploadEmployeeDocument(
                                selectedFile!.name,
                                selectedFile!.bytes!,
                              );
                              await SupabaseService.createEmployeeDocument({
                                'employee_id': widget.employee['id'],
                                'folder_id': widget.folder['id'],
                                'title': titleCtrl.text.trim(),
                                'file_url': fileUrl,
                                'file_name': selectedFile!.name,
                                'file_size_kb': (selectedFile!.size / 1024).round(),
                                'file_mime': selectedFile!.extension,
                                'uploaded_by': appState.userId,
                                'notes': notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
                              });
                              if (ctx.mounted) Navigator.pop(ctx);
                              _load();
                            } catch (e) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(content: Text('${tr('Fehler')}: $e')),
                                );
                              }
                            } finally {
                              if (ctx.mounted) setM(() => uploading = false);
                            }
                          },
                    child: uploading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text(tr('Hochladen')),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final folderName = widget.folder['folder_name'] ?? '';
    final empName = '${widget.employee['first_name']} ${widget.employee['last_name']}';

    final isAdmin = appState.canManageEmployeeDocuments;
    final currentUserId = appState.userId.trim();
    final employeeId = (widget.employee['id'] ?? '').toString().trim();
    final isSelf = employeeId == currentUserId;
    final folderKey = (widget.folder['folder_key'] ?? '').toString().toLowerCase().trim();
    
    // Hassas klasör mü?
    final isSensitive = folderKey == 'arbeitsvertrag' || folderKey == 'gehaltsabrechnung';
    
    // Yükleme yetkisi: (Admin ise her yere) VEYA (Kendi profilindeyse ve hassas klasör değilse)
    final canUploadDocs = isAdmin || (isSelf && !isSensitive);



    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(folderName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
            Text(empName, style: const TextStyle(fontSize: 11, color: Colors.white70, fontFamily: 'Inter')),
          ],
        ),
        actions: [
          if (canUploadDocs)
            IconButton(
              icon: const Icon(Icons.upload_file),
              tooltip: tr('Dokument hochladen'),
              onPressed: () => _showUploadDialog(context, appState),
            ),
        ],
      ),
      body: WebContentWrapper(
        padding: EdgeInsets.zero,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _docs.isEmpty
                ? _buildEmptyState(canUploadDocs, appState)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: _docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _DocumentItem(
                        doc: _docs[i],
                        canDelete: isAdmin || (isSelf && !isSensitive),
                        onDeleted: _load,
                      ),
                    ),
                  ),
      ),

      // Yönetici ise FAB de göster
      floatingActionButton: canUploadDocs
          ? FloatingActionButton.extended(
              onPressed: () => _showUploadDialog(context, appState),
              icon: const Icon(Icons.upload_file),
              label: Text(tr('Hochladen'), style: const TextStyle(fontFamily: 'Inter')),
            )
          : null,
    );
  }

  Widget _buildEmptyState(bool canUploadDocs, AppState appState) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_outlined, size: 72, color: AppTheme.textSub.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(tr('Keine Dokumente vorhanden'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textSub, fontFamily: 'Inter')),
          const SizedBox(height: 8),
          Text(tr('Noch keine Dokumente in diesem Ordner.'),
              style: const TextStyle(fontSize: 13, color: AppTheme.textSub, fontFamily: 'Inter')),
          if (canUploadDocs) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showUploadDialog(context, appState),
              icon: const Icon(Icons.upload_file),
              label: Text(tr('Erstes Dokument hochladen')),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Belge Kartı ──────────────────────────────────────────────────────────────
class _DocumentItem extends StatefulWidget {
  final Map<String, dynamic> doc;
  final bool canDelete;
  final VoidCallback onDeleted;

  const _DocumentItem({required this.doc, required this.canDelete, required this.onDeleted});

  @override
  State<_DocumentItem> createState() => _DocumentItemState();
}

class _DocumentItemState extends State<_DocumentItem> {
  bool _loading = false;

  IconData get _mimeIcon {
    final mime = (widget.doc['file_mime'] ?? '').toString().toLowerCase();
    if (mime == 'pdf') return Icons.picture_as_pdf_outlined;
    if (['jpg', 'jpeg', 'png', 'webp'].contains(mime)) return Icons.image_outlined;
    if (['xls', 'xlsx', 'csv'].contains(mime)) return Icons.table_chart_outlined;
    if (['doc', 'docx'].contains(mime)) return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Color get _mimeColor {
    final mime = (widget.doc['file_mime'] ?? '').toString().toLowerCase();
    if (mime == 'pdf') return const Color(0xFFE53E3E);
    if (['jpg', 'jpeg', 'png'].contains(mime)) return const Color(0xFF805AD5);
    if (['xls', 'xlsx'].contains(mime)) return const Color(0xFF38A169);
    if (['doc', 'docx'].contains(mime)) return const Color(0xFF3182CE);
    return AppTheme.textSub;
  }

  Future<void> _open() async {
    final url = widget.doc['file_url'] as String?;
    if (url == null || url.isEmpty) return;
    setState(() => _loading = true);
    try {
      if (kIsWeb) {
        await launchUrl(Uri.parse(url));
      } else {
        final bytes = await SupabaseService.downloadDocument(url);
        if (!mounted) return;
        final fileName = widget.doc['file_name'] ?? 'dokument';
        await PlatformHelper.saveAndOpenFile(
          bytes: Uint8List.fromList(bytes),
          fileName: fileName,
          title: widget.doc['title'] ?? 'Dokument',
          isShare: false,
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Fehler')}: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('Dokument löschen?'), style: const TextStyle(fontFamily: 'Inter')),
        content: Text(tr('Dieses Dokument wird dauerhaft gelöscht. Fortfahren?'),
            style: const TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('Abbrechen'))),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('Löschen'), style: const TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _loading = true);
    try {
      await SupabaseService.deleteEmployeeDocument(
        widget.doc['id'].toString(),
        widget.doc['file_url'].toString(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('Dokument erfolgreich gelöscht'))));
        widget.onDeleted();
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Fehler')}: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploader = widget.doc['uploaded_by_user'];
    final uploaderName = uploader != null
        ? '${uploader['first_name'] ?? ''} ${uploader['last_name'] ?? ''}'.trim()
        : '';
    final uploadedAt = widget.doc['uploaded_at'] as String?;
    String dateStr = '';
    if (uploadedAt != null) {
      try {
        final dt = DateTime.parse(uploadedAt).toLocal();
        dateStr = '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}';
      } catch (_) {}
    }

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppTheme.divider.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Dosya ikonu
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _mimeColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_mimeIcon, color: _mimeColor, size: 20),
            ),
            const SizedBox(width: 12),
            // Başlık + meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.doc['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Inter', color: AppTheme.textMain),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(children: [
                    if (uploaderName.isNotEmpty) ...[
                      const Icon(Icons.person_outline, size: 10, color: AppTheme.textSub),
                      const SizedBox(width: 3),
                      Text(uploaderName, style: const TextStyle(fontSize: 9, color: AppTheme.textSub, fontFamily: 'Inter')),
                      const SizedBox(width: 8),
                    ],
                    if (dateStr.isNotEmpty) ...[
                      const Icon(Icons.calendar_today_outlined, size: 10, color: AppTheme.textSub),
                      const SizedBox(width: 3),
                      Text(dateStr, style: const TextStyle(fontSize: 9, color: AppTheme.textSub, fontFamily: 'Inter')),
                    ],
                  ]),
                ],
              ),
            ),
            // Aksiyonlar
            if (_loading)
              const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.open_in_browser_outlined, size: 18, color: AppTheme.primary),
                    tooltip: tr('Öffnen'),
                    onPressed: _open,
                  ),
                  if (widget.canDelete)
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                      tooltip: tr('Löschen'),
                      onPressed: _delete,
                  ),
              ],
            ),
        ],
      ),
    ),
  );
}
}
