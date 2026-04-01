import 'package:flutter/material.dart';

class AppTheme {
  // ── Marka Renkleri ────────────────────────────────────────
  static const Color primary   = Color(0xFF1A237E);   // Koyu lacivert
  static const Color secondary = Color(0xFF283593);
  static const Color accent    = Color(0xFF42A5F5);   // Mavi vurgu
  static const Color success   = Color(0xFF2E7D32);
  static const Color warning   = Color(0xFFF57F17);
  static const Color error     = Color(0xFFC62828);
  static const Color info      = Color(0xFF0277BD);

  // ── Nötr Renkler ──────────────────────────────────────────
  static const Color bg        = Color(0xFFF0F2F5);
  static const Color surface   = Color(0xFFFFFFFF);
  static const Color textMain  = Color(0xFF1C1C1E);
  static const Color textSub   = Color(0xFF6E6E73);
  static const Color border    = Color(0xFFD1D1D6);
  static const Color divider   = Color(0xFFE5E5EA);

  // ── Hizmet Alanı Renkleri ─────────────────────────────────
  static const Map<String, Color> serviceAreaColors = {
    'gebaeudereinigung':    Color(0xFF1976D2),
    'gleisbausicherung':    Color(0xFFD32F2F),
    'hotelservice':         Color(0xFF7B1FA2),
    'personalueberlassung': Color(0xFF388E3C),
    'verwaltung':           Color(0xFF455A64),
    'other':                Color(0xFF757575),
  };

  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        secondary: accent,
        surface: surface,
      ),
      scaffoldBackgroundColor: bg,
      fontFamily: 'Inter',
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: divider, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: error),
        ),
        labelStyle: const TextStyle(color: textSub, fontFamily: 'Inter'),
        hintStyle: const TextStyle(color: textSub, fontFamily: 'Inter'),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: primary.withOpacity(0.08),
        selectedColor: primary,
        labelStyle: const TextStyle(fontFamily: 'Inter', fontSize: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(color: divider, thickness: 1),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textMain, fontFamily: 'Inter'),
        headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textMain, fontFamily: 'Inter'),
        titleLarge:    TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textMain, fontFamily: 'Inter'),
        titleMedium:   TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: textMain, fontFamily: 'Inter'),
        bodyLarge:     TextStyle(fontSize: 15, fontWeight: FontWeight.normal, color: textMain, fontFamily: 'Inter'),
        bodyMedium:    TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: textMain, fontFamily: 'Inter'),
        bodySmall:     TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: textSub, fontFamily: 'Inter'),
        labelLarge:    TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: textSub, fontFamily: 'Inter'),
      ),
    );
  }

  // ── Yardımcı Widgetlar ────────────────────────────────────
  static BoxDecoration gradientBox() => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)], // More vibrant blue gradient
    ),
  );

  static BoxDecoration glassBox({Color? color, double blur = 10}) => BoxDecoration(
    color: (color ?? Colors.white).withOpacity(0.1),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: Colors.white.withOpacity(0.2)),
  );

  static Color statusColor(String status) {
    switch (status) {
      case 'draft':            return textSub;
      case 'created':          return info;
      case 'pending_approval': return warning;
      case 'approved':         return Colors.teal;
      case 'planning':         return Colors.purple;
      case 'in_progress':      return primary;
      case 'completed':        return success;
      case 'invoiced':         return Colors.orange;
      case 'archived':         return textSub;
      case 'active':           return success;
      case 'inactive':         return error;
      default:                 return textSub;
    }
  }

  static String statusLabel(String status) {
    switch (status) {
      case 'draft':            return 'Taslak';
      case 'created':          return 'Oluşturuldu';
      case 'pending_approval': return 'Onay Bekliyor';
      case 'approved':         return 'Onaylandı';
      case 'planning':         return 'Planlamada';
      case 'in_progress':      return 'Devam Ediyor';
      case 'completed':        return 'Tamamlandı';
      case 'invoiced':         return 'Faturalandı';
      case 'archived':         return 'Arşivlendi';
      case 'active':           return 'Aktif';
      case 'inactive':         return 'Pasif';
      default:                 return status;
    }
  }

  static String roleLabel(String role) {
    switch (role) {
      case 'geschaeftsfuehrer':  return 'Geschäftsführer';
      case 'betriebsleiter':     return 'Betriebsleiter';
      case 'bereichsleiter':     return 'Bereichsleiter';
      case 'vorarbeiter':        return 'Vorarbeiter';
      case 'mitarbeiter':        return 'Mitarbeiter';
      case 'buchhaltung':        return 'Buchhaltung';
      case 'backoffice':         return 'Backoffice';
      case 'system_admin':       return 'System Admin';
      default:                   return role;
    }
  }
}
