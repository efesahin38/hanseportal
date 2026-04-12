String formatCompanyName(String name) {
  // Ana şirket adını olduğu gibi bırak
  if (name.contains('Hanse Kollektiv')) return name;
  
  // Diğer şirketlerden ' GmbH' ekini kaldır
  return name.replaceAll(RegExp(r'\s+GmbH$', caseSensitive: false), '').trim();
}
