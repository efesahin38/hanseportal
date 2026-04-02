import 'dart:convert';
import 'package:flutter/services.dart';

class LocalizationService {
  static final LocalizationService _instance = LocalizationService._internal();
  factory LocalizationService() => _instance;
  LocalizationService._internal();

  Map<String, String> _localizedStrings = {};

  Future<void> load(String locale) async {
    try {
      String jsonString = await rootBundle.loadString('assets/l10n/$locale.json');
      Map<String, dynamic> jsonMap = json.decode(jsonString);
      _localizedStrings = jsonMap.map((key, value) => MapEntry(key, value.toString()));
    } catch (e) {
      print('Localization load error: $e');
      _localizedStrings = {};
    }
  }

  String translate(String key) {
    return _localizedStrings[key] ?? key;
  }
}

// Global helper function for easier access
String tr(String key) {
  return LocalizationService().translate(key);
}
