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

  String translate(String key, {Map<String, String>? args}) {
    String value = _localizedStrings[key] ?? key;
    if (args != null) {
      args.forEach((k, v) {
        value = value.replaceAll('{$k}', v);
      });
    }
    return value;
  }
}

// Global helper function for easier access
String tr(String key, {Map<String, String>? args}) {
  return LocalizationService().translate(key, args: args);
}
