import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:typed_data';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import '../utils/platform_helper.dart';

/// Çalışan Ekranı – Meine Dokumente
/// Kendi klasörlerini ve belgelerini görüntüler. Sadece okuma + indirme.
class MyDocumentsScreen extends StatefulWidget {
  const MyDocumentsScreen({super.key});

  @override
  State<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends State<MyDocumentsScreen> {
  List<Map<String, dynamic>> _folders = [];
  Map<String, dynamic>? _selectedFolder;
  List<Map<String, dynamic>> _docs = [];
  Map<String, int> _docCounts = {};
  bool _loadingFolders = true;
  bool _loadingDocs = false;

  // Klasör simgeleri ve renkler
  static const Map<String, IconData> _folderIcons = {
    'arbeitsvertrag':     Icons.description_outlined,
    'gehaltsabrechnung':  Icons.payments_outlined,
    'personaldokumente':  Icons.badge_outlined,
    'krankenversicherung':Icons.local_hospital_outlined,
    'steuerunterlagen':   Icons.receipt_long_outlined,
    'bescheinigungen':    Icons.verified_outlined,
    'fuehrerschein':      Icons.drive_eta_outlined,
    'arbeitszeit_urlaub': Icons.calendar_month_outlined,
    'abmahnungen':        Icons.warning_amber_outlined,
    'sonstige':           Icons.folder_special_outlined,
  };

  static const Map<String, Color> _folderColors = {
    'arbeitsvertrag':     Color(0xFF4A90D9),
    'gehaltsabrechnung':  Color(0xFF27AE60),
    'personaldokumente':  Color(0xFF8E44AD),
    'krankenversicherung':Color(0xFFE74C3C),
    'steuerunterlagen':   Color(0xFFF39C12),
    'bescheinigungen':    Color(0xFF16A085),
    'fuehrerschein':      Color(0xFF2980B9),
    'abmahnungen':        Color(0xFFE67E22),
    'arbeitszeit_urlaub': Color(0xFF1ABC9C),
    'sonstige':           Color(0xFF95A5A6),
  };

  @override
  void initState() {
    super.initState();
    _loadFolders();
  }

  Future<void> _loadFolders() async {
    final appState = context.read<AppState>();
    try {
      final folders = await SupabaseService.getEmployeeFolders(appState.userId);
      final counts = await SupabaseService.getEmployeeDocumentCounts(appState.userId);
      if (mounted) {
        setState(() {
          _folders = folders;
          _docCounts = counts;
          _loadingFolders = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingFolders = false);
    }
  }

  Future<void> _openFolder(Map<String, dynamic> folder) async {
    setState(() {
      _selectedFolder = folder;
      _loadingDocs = true;
      _docs = [];
    });
    try {
      final docs = await SupabaseService.getEmployeeDocuments(folder['id'].toString());
      if (mounted) setState(() { _docs = docs; _loadingDocs = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingDocs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingFolders) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Klasör listesi göster
    if (_selectedFolder == null) {
      return _buildFolderList();
    }
    // Klasör detayı göster
    return _buildDocumentList();
  }

  Widget _buildFolderList() {
    final appState = context.watch<AppState>();
    
    // Eğer webtesek ve shell içindeysen başlık gösterme (MainShell zaten gösteriyor)
    final bool showHeader = !kIsWeb;

    Widget content = WebContentWrapper(
      padding: const EdgeInsets.all(16),
      child: _folders.isEmpty
          ? Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.folder_off_outlined, size: 72, color: AppTheme.textSub.withOpacity(0.3)),
                const SizedBox(height: 16),
                Text(tr('Keine Ordner vorhanden'),
                    style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter', fontSize: 15)),
                const SizedBox(height: 8),
                Text(tr('Bitte wenden Sie sich an Ihren Vorgesetzten.'),
                    style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter', fontSize: 13)),
              ]),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showHeader) ...[
                  Text(tr('Meine Dokumentordner'),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter', color: AppTheme.textMain)),
                  const SizedBox(height: 4),
                  Text(tr('Tippen Sie auf einen Ordner, um die Dokumente anzuzeigen.'),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: kIsWeb && WebUtils.isWide(context) ? 6 : 2, // Web'de 6 sütun
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 1.3, // Daha basık, zarif kartlar
                    ),
                    itemCount: _folders.length,
                    itemBuilder: (_, i) {
                      final folder = _folders[i];
                      final key = folder['folder_key'] as String;
                      final color = _folderColors[key] ?? AppTheme.primary;
                      final icon = _folderIcons[key] ?? Icons.folder_outlined;
                      final count = _docCounts[folder['id'].toString()] ?? 0;

                      return _MyFolderCard(
                        folder: folder,
                        color: color,
                        icon: icon,
                        docCount: count,
                        onTap: () => _openFolder(folder),
                      );
                    },
                  ),
                ),
              ],
            ),
    );

    if (!showHeader) return content;

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Meine Dokumente')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppTheme.primary.withOpacity(0.9),
            child: Row(
              children: [
                const Icon(Icons.person_outlined, color: Colors.white70, size: 16),
                const SizedBox(width: 6),
                Text(appState.fullName,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontFamily: 'Inter', fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Text('· ${AppTheme.roleLabel(appState.role)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
              ],
            ),
          ),
        ),
      ),
      body: content,
    );
  }

  Widget _buildDocumentList() {
    final folder = _selectedFolder!;
    final key = folder['folder_key'] as String;
    final color = _folderColors[key] ?? AppTheme.primary;
    final icon = _folderIcons[key] ?? Icons.folder_outlined;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() { _selectedFolder = null; _docs = []; }),
        ),
        title: Row(
          children: [
            Icon(icon, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Text(folder['folder_name'] ?? '',
                style: const TextStyle(fontSize: 15, fontFamily: 'Inter', fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      body: WebContentWrapper(
        padding: EdgeInsets.zero,
        child: _loadingDocs
            ? const Center(child: CircularProgressIndicator())
            : _docs.isEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.folder_open_outlined, size: 64, color: color.withOpacity(0.3)),
                      const SizedBox(height: 16),
                      Text(tr('Keine Dokumente vorhanden'),
                          style: const TextStyle(fontSize: 15, color: AppTheme.textSub, fontFamily: 'Inter')),
                      const SizedBox(height: 8),
                      Text(tr('Dieser Ordner ist leer.'),
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSub, fontFamily: 'Inter')),
                    ]),
                  )
                : RefreshIndicator(
                    onRefresh: () => _openFolder(folder),
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _docs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _MyDocumentItem(doc: _docs[i]),
                    ),
                  ),
      ),
    );
  }
}

// ── Klasör Kartı ──────────────────────────────────────────────────────────────
class _MyFolderCard extends StatelessWidget {
  final Map<String, dynamic> folder;
  final Color color;
  final IconData icon;
  final int docCount;
  final VoidCallback onTap;

  const _MyFolderCard({
    required this.folder, required this.color, required this.icon,
    required this.docCount, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.12), blurRadius: 12, offset: const Offset(0, 4)),
          ],
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  if (docCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
                      child: Text('$docCount', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Inter')),
                    ),
                ],
              ),
              const Spacer(),
              Text(folder['folder_name'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, fontFamily: 'Inter', color: AppTheme.textMain),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Row(children: [
                Icon(docCount > 0 ? Icons.description_outlined : Icons.folder_open_outlined,
                    size: 10, color: AppTheme.textSub),
                const SizedBox(width: 3),
                Text(
                  docCount == 0 ? tr('Leer') : '$docCount ${tr('Dokument(e)')}',
                  style: TextStyle(fontSize: 9, color: AppTheme.textSub.withOpacity(0.8), fontFamily: 'Inter'),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Belge Satırı (Çalışan – Sadece Okuma) ────────────────────────────────────
class _MyDocumentItem extends StatefulWidget {
  final Map<String, dynamic> doc;
  const _MyDocumentItem({required this.doc});

  @override
  State<_MyDocumentItem> createState() => _MyDocumentItemState();
}

class _MyDocumentItemState extends State<_MyDocumentItem> {
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

  Future<void> _handleOpen() async => _handleAction(false);
  Future<void> _handleDownload() async => _handleAction(false);
  Future<void> _handleShare() async => _handleAction(true);

  Future<void> _handleAction(bool isShare) async {
    final url = widget.doc['file_url'] as String?;
    if (url == null || url.isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isShare ? tr('Teilen wird vorbereitet...') : tr('Dokument wird geöffnet...')),
        duration: const Duration(seconds: 2),
      ),
    );

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
          isShare: isShare,
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${tr('Fehler')}: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploadedAt = widget.doc['uploaded_at'] as String?;
    String dateStr = '';
    if (uploadedAt != null) {
      try {
        final dt = DateTime.parse(uploadedAt).toLocal();
        dateStr = '${dt.day.toString().padLeft(2,'0')}.${dt.month.toString().padLeft(2,'0')}.${dt.year}';
      } catch (_) {}
    }
    final sizeKb = widget.doc['file_size_kb'] as int?;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: AppTheme.divider.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _mimeColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_mimeIcon, color: _mimeColor, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.doc['title'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, fontFamily: 'Inter'),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 1),
                  Row(children: [
                    if (dateStr.isNotEmpty) ...[
                      const Icon(Icons.calendar_today_outlined, size: 9, color: AppTheme.textSub),
                      const SizedBox(width: 3),
                      Text(dateStr, style: const TextStyle(fontSize: 9, color: AppTheme.textSub, fontFamily: 'Inter')),
                    ],
                    if (sizeKb != null) ...[
                      const SizedBox(width: 6),
                      Text('$sizeKb KB', style: const TextStyle(fontSize: 9, color: AppTheme.textSub, fontFamily: 'Inter')),
                    ],
                  ]),
                ],
              ),
            ),
            if (_loading)
              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.visibility_outlined, size: 18, color: AppTheme.primary),
                    tooltip: tr('Öffnen'),
                    onPressed: _handleOpen,
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: const Icon(Icons.download_outlined, size: 18, color: AppTheme.success),
                    tooltip: tr('Laden'),
                    onPressed: _handleDownload,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
