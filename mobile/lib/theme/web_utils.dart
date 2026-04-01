import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Web sayfalarının maksimum genişliğini belirler.
/// İçerik çok geniş ekranlarda ortalar.
class WebUtils {
  static bool get isWeb => kIsWeb;

  /// Geniş ekran mı? (>= 900px)
  static bool isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  /// Orta ekran mı? (>= 600px)
  static bool isMedium(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600;

  /// Maksimum içerik genişliği
  static double maxContentWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1400) return 1280;
    if (w >= 1200) return 1100;
    if (w >= 900) return 900;
    return w;
  }

  /// Web'de içeriği ortalar ve max-width uygular
  static Widget center(BuildContext context, Widget child,
      {double? maxWidth, EdgeInsets? padding}) {
    if (!isWeb) return child;
    final mw = maxWidth ?? maxContentWidth(context);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mw),
        child: Padding(
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );
  }

  /// Ekran genişliğine göre grid column sayısı
  static int gridColumns(BuildContext context, {int mobile = 2, int tablet = 3, int desktop = 4}) {
    final w = MediaQuery.of(context).size.width;
    if (!isWeb || w < 600) return mobile;
    if (w < 900) return tablet;
    return desktop;
  }

  /// Sidebar genişliği (web)
  static const double sidebarWidth = 240;
}

/// Tüm web ekranları için içerik sarmalayıcı.
/// Web'de içeriği ortalar ve yatay padding ekler.
/// Mobilde doğrudan child döndürür.
class WebContentWrapper extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsets? padding;

  const WebContentWrapper({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return child;
    final w = MediaQuery.of(context).size.width;
    final mw = maxWidth ?? (w >= 1400 ? 1280.0 : w >= 1200 ? 1100.0 : w >= 900 ? 900.0 : w);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mw),
        child: Padding(
          padding: padding ?? const EdgeInsets.symmetric(horizontal: 24),
          child: child,
        ),
      ),
    );
  }
}
