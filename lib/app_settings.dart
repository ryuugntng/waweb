import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings extends ChangeNotifier {
  late final SharedPreferences _p;

  String lang = 'id';
  int zoom = 100;
  bool pillRight = true;
  bool fullscreen = false;
  bool haptic = true;
  double pillY = 0.45;
  bool? waDark;

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    lang = _p.getString('lang') ?? lang;
    zoom = _p.getInt('zoom') ?? zoom;
    pillRight = _p.getBool('pillRight') ?? pillRight;
    fullscreen = _p.getBool('fullscreen') ?? fullscreen;
    haptic = _p.getBool('haptic') ?? haptic;
    pillY = _p.getDouble('pillY') ?? pillY;
    waDark = _p.getBool('waDark');
  }

  void setLang(String v) {
    lang = v;
    _p.setString('lang', v);
    notifyListeners();
  }

  void setZoom(int v) {
    zoom = v.clamp(70, 160);
    _p.setInt('zoom', zoom);
    notifyListeners();
  }

  void setPillRight(bool v) {
    pillRight = v;
    _p.setBool('pillRight', v);
    notifyListeners();
  }

  void setFullscreen(bool v) {
    fullscreen = v;
    _p.setBool('fullscreen', v);
    notifyListeners();
  }

  void setHaptic(bool v) {
    haptic = v;
    _p.setBool('haptic', v);
    notifyListeners();
  }

  void setPillY(double v) {
    pillY = v;
    _p.setDouble('pillY', v);
    notifyListeners();
  }

  void setWaDark(bool v) {
    waDark = v;
    _p.setBool('waDark', v);
    notifyListeners();
  }
}
