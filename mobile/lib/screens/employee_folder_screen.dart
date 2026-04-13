import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../theme/web_utils.dart';
import '../providers/app_state.dart';
import '../services/supabase_service.dart';
import '../services/localization_service.dart';
import 'employee_folder_detail_screen.dart';

/// Yönetici Ekranı – Mitarbeiterdokumente
/// Çalışanları listeler, seçilen çalışanın 10 klasörünü gösterir.
class EmployeeFolderScreen extends StatefulWidget {
  final Map<String, dynamic>? initialEmployee;
  const EmployeeFolderScreen({super.key, this.initialEmployee});

  @override
  State<EmployeeFolderScreen> createState() => _EmployeeFolderScreenState();
}

class _EmployeeFolderScreenState extends State<EmployeeFolderScreen> {
  List<Map<String, dynamic>> _employees = [];
  Map<String, dynamic>? _selectedEmployee;
  List<Map<String, dynamic>> _folders = [];
  Map<String, int> _docCounts = {};
  bool _loadingEmployees = true;
  bool _loadingFolders = false;
  String _search = '';

  // Klasör simgeleri
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

  // Klasör renkleri
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
    if (widget.initialEmployee != null) {
      _selectEmployee(widget.initialEmployee!);
    }
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final data = await SupabaseService.getUsers(status: 'active');
      if (mounted) setState(() { _employees = data; _loadingEmployees = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingEmployees = false);
    }
  }

  Future<void> _selectEmployee(Map<String, dynamic> emp) async {
    setState(() {
      _selectedEmployee = emp;
      _loadingFolders = true;
      _folders = [];
      _docCounts = {};
    });

    try {
      final folders = await SupabaseService.getEmployeeFolders(emp['id']);
      final counts = await SupabaseService.getEmployeeDocumentCounts(emp['id']);
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

  List<Map<String, dynamic>> get _filteredEmployees {
    if (_search.isEmpty) return _employees;
    final q = _search.toLowerCase();
    return _employees.where((e) =>
      ('${e['first_name']} ${e['last_name']}').toLowerCase().contains(q) ||
      (e['email'] ?? '').toLowerCase().contains(q)
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.initialEmployee != null) {
      return _buildNarrowLayout();
    }
    final isWide = kIsWeb && WebUtils.isWide(context);
    if (isWide) return _buildWideLayout();
    return _buildNarrowLayout();
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        // Sol panel – Çalışan listesi
        Container(
          width: 300,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: AppTheme.divider)),
          ),
          child: _buildEmployeeList(),
        ),
        // Sağ panel – Klasörler
        Expanded(child: _buildFolderPanel()),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    if (_selectedEmployee == null) {
      return Scaffold(
        appBar: AppBar(title: Text(tr('Mitarbeiterdokumente'))),
        body: _buildEmployeeList(),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text('${_selectedEmployee!['first_name']} ${_selectedEmployee!['last_name']}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (widget.initialEmployee != null) {
              Navigator.pop(context);
            } else {
              setState(() => _selectedEmployee = null);
            }
          },
        ),
      ),
      body: _buildFolderPanel(),
    );
  }

  Widget _buildEmployeeList() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: TextField(
            onChanged: (v) => setState(() => _search = v),
            decoration: InputDecoration(
              hintText: tr('Mitarbeiter suchen...'),
              prefixIcon: const Icon(Icons.search, size: 18),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _loadingEmployees
              ? const Center(child: CircularProgressIndicator())
              : _filteredEmployees.isEmpty
                  ? Center(child: Text(tr('Kein Personal gefunden'), style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')))
                  : ListView.builder(
                      itemCount: _filteredEmployees.length,
                      itemBuilder: (_, i) {
                        final emp = _filteredEmployees[i];
                        final name = '${emp['first_name']} ${emp['last_name']}';
                        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                        final isSelected = _selectedEmployee?['id'] == emp['id'];
                        return ListTile(
                          selected: isSelected,
                          selectedTileColor: AppTheme.primary.withOpacity(0.08),
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: isSelected
                                ? AppTheme.primary
                                : AppTheme.primary.withOpacity(0.12),
                            child: Text(initial, style: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.primary,
                              fontWeight: FontWeight.bold, fontFamily: 'Inter', fontSize: 14,
                            )),
                          ),
                          title: Text(name, style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 13, fontFamily: 'Inter',
                            color: isSelected ? AppTheme.primary : AppTheme.textMain,
                          )),
                          subtitle: Text(
                            AppTheme.roleLabel(emp['role'] ?? ''),
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSub, fontFamily: 'Inter'),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.chevron_right, color: AppTheme.primary)
                              : null,
                          onTap: () => _selectEmployee(emp),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildFolderPanel() {
    if (_selectedEmployee == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_outlined, size: 72, color: AppTheme.textSub.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(tr('Bitte einen Mitarbeiter auswählen'),
                style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter', fontSize: 15)),
          ],
        ),
      );
    }

    final emp = _selectedEmployee!;
    final name = '${emp['first_name']} ${emp['last_name']}';

    return Column(
      children: [
        // Başlık bandı
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.primary, AppTheme.secondary],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, fontFamily: 'Inter')),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17, fontFamily: 'Inter')),
                    Text(AppTheme.roleLabel(emp['role'] ?? ''),
                        style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Inter')),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${tr('Ordner')}: ${_folders.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'Inter'),
                ),
              ),
            ],
          ),
        ),

        // Klasör grid'i
        Expanded(
          child: _loadingFolders
              ? const Center(child: CircularProgressIndicator())
              : () {
                  final appState = context.read<AppState>();
                  final isAdmin = appState.canManageEmployeeDocuments;
                  
                  // Eğer kullanıcı admin değilse ve kendi dosyalarına bakıyorsa 
                  // veya başkasının dosyalarına bakıyorsa (zaten başkasını seçemez ama güvenlik için)
                  // Hassas klasörleri filtrele.
                  final filteredFolders = _folders.where((f) {
                    if (isAdmin) return true;
                    final key = f['folder_key'] as String;
                    return key != 'arbeitsvertrag' && key != 'gehaltsabrechnung';
                  }).toList();

                  if (filteredFolders.isEmpty) {
                    return Center(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.folder_off_outlined, size: 56, color: AppTheme.textSub),
                        const SizedBox(height: 12),
                        Text(tr('Keine Ordner gefunden'), style: const TextStyle(color: AppTheme.textSub, fontFamily: 'Inter')),
                      ]),
                    );
                  }

                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: WebUtils.gridColumns(context, mobile: 2, tablet: 3, desktop: 4),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.8,
                      ),
                    itemCount: filteredFolders.length,
                    itemBuilder: (_, i) {
                      final folder = filteredFolders[i];
                      final key = folder['folder_key'] as String;
                      final color = _folderColors[key] ?? AppTheme.primary;
                      final icon = _folderIcons[key] ?? Icons.folder_outlined;
                      final count = _docCounts[folder['id'].toString()] ?? 0;

                      return _FolderCard(
                        folder: folder,
                        color: color,
                        icon: icon,
                        docCount: count,
                        employee: emp,
                        onRefresh: () => _selectEmployee(emp),
                      );
                    },
                  );
                }(),
        ),
      ],
    );
  }
}

class _FolderCard extends StatelessWidget {
  final Map<String, dynamic> folder;
  final Color color;
  final IconData icon;
  final int docCount;
  final Map<String, dynamic> employee;
  final VoidCallback onRefresh;

  const _FolderCard({
    required this.folder,
    required this.color,
    required this.icon,
    required this.docCount,
    required this.employee,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EmployeeFolderDetailScreen(
            folder: folder,
            employee: employee,
          ),
        ),
      ).then((_) => onRefresh()),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: color.withOpacity(0.15)),
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
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$docCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                folder['folder_name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, fontFamily: 'Inter', color: AppTheme.textMain),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                docCount == 0
                    ? tr('Keine Dokumente')
                    : '$docCount ${tr('Dokument(e)')}',
                style: TextStyle(fontSize: 9, color: AppTheme.textSub.withOpacity(0.8), fontFamily: 'Inter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
