import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SelectionModel extends ChangeNotifier {
  String? bgPath;
  String? butsudanPath;
  String? ihaiPath;
  String? portraitPath;

  static const _kBg = 'sel_bg';
  static const _kButsudan = 'sel_butsudan';
  static const _kIhai = 'sel_ihai';
  static const _kPortrait = 'sel_portrait';

  Future<void> load() async {
    final pref = await SharedPreferences.getInstance();
    bgPath = pref.getString(_kBg);
    butsudanPath = pref.getString(_kButsudan);
    ihaiPath = pref.getString(_kIhai);
    portraitPath = pref.getString(_kPortrait);
    notifyListeners();
  }

  Future<void> setBg(String path) async {
    bgPath = path;
    final pref = await SharedPreferences.getInstance();
    await pref.setString(_kBg, path);
    notifyListeners();
  }

  Future<void> setButsudan(String path) async {
    butsudanPath = path;
    final pref = await SharedPreferences.getInstance();
    await pref.setString(_kButsudan, path);
    notifyListeners();
  }

  Future<void> setIhai(String path) async {
    ihaiPath = path;
    final pref = await SharedPreferences.getInstance();
    await pref.setString(_kIhai, path);
    notifyListeners();
  }

  Future<void> setPortrait(String path) async {
    portraitPath = path;
    final pref = await SharedPreferences.getInstance();
    await pref.setString(_kPortrait, path);
    notifyListeners();
  }
}
