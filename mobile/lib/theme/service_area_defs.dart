import 'package:flutter/material.dart';

/// v17.0 – 6 Hizmet Alanı Tanımı (Gastwirtschaftsservice kaldırıldı)
/// Tüm form ekranları bu sabitten okur.
class ServiceAreaDefs {
  /// 6 hizmet alanı kategorisi
  static const List<Map<String, dynamic>> categories = [
    {
      'key': 'Gebäude',
      'label': 'Gebäudedienstleistungen',
      'emoji': '🏗️',
      'color': Color(0xFF3B82F6), // Mavi
      'kw': ['gebäud', 'reinigung'],
    },
    {
      'key': 'Rail',
      'label': 'DB-Gleisbausicherung',
      'emoji': '🚂',
      'color': Color(0xFF10B981), // Yeşil
      'kw': ['rail', 'gleis', 'db-gleis', 'db gleis'],
    },
    {
      'key': 'Personal',
      'label': 'Personalüberlassung',
      'emoji': '👥',
      'color': Color(0xFF8B5CF6), // Mor
      'kw': ['personal', 'über', 'verwal'],
    },
    {
      'key': 'BauLogistik',
      'label': 'Bau-Logistik',
      'emoji': '🚧',
      'color': Color(0xFFF97316), // Turuncu
      'kw': ['bau-logistik', 'baulogistik', 'bau logistik', 'logistik'],
    },
    {
      'key': 'Hausmeister',
      'label': 'Hausmeisterservice',
      'emoji': '🔧',
      'color': Color(0xFFEF4444), // Kırmızı
      'kw': ['hausmeister'],
    },
    {
      'key': 'Garten',
      'label': 'Gartenpflege',
      'emoji': '🌿',
      'color': Color(0xFF22C55E), // Açık yeşil
      'kw': ['garten', 'grün', 'grünanlagen'],
    },
    {
      'key': 'Gastwirtschaft',
      'label': 'Gastwirtschaftsservice',
      'emoji': '🍴',
      'color': Color(0xFFD946EF), // Pembe/Mor
      'kw': ['gast', 'gastro', 'hospitality', 'restaurant'],
    },
  ];

  /// Bir müşteri'nin hizmet alanı adına göre kategori rengi döner
  static Color colorForServiceAreaName(String? name) {
    if (name == null) return const Color(0xFF94A3B8);
    final n = name.toLowerCase();
    for (final cat in categories) {
      final kws = cat['kw'] as List<String>;
      if (kws.any((kw) => n.contains(kw))) return cat['color'] as Color;
      if (n.contains((cat['label'] as String).toLowerCase())) return cat['color'] as Color;
    }
    return const Color(0xFF94A3B8);
  }

  /// Hizmet alanı adı için emoji döner
  static String emojiForServiceAreaName(String? name) {
    if (name == null) return '🏢';
    final n = name.toLowerCase();
    for (final cat in categories) {
      final kws = cat['kw'] as List<String>;
      if (kws.any((kw) => n.contains(kw))) return cat['emoji'] as String;
      if (n.contains((cat['label'] as String).toLowerCase())) return cat['emoji'] as String;
    }
    return '🏢';
  }
}
