import 'package:flutter/foundation.dart';

import 'file_saver.dart';

class AppSettings extends ChangeNotifier {
  String lang = 'id';
  int zoom = 100;
  bool zoomLock = true; // true = pinch zoom dikunci
  bool pillRight = true;
  bool fullscreen = false;
  bool haptic = true;
  double pillY = 0.45;
  bool? waDark;

  Future<void> load() async {
    final p = await Native.prefs();
    lang = p['lang'] as String? ?? lang;
    zoom = p['zoom'] as int? ?? zoom;
    zoomLock = p['zoomLock'] as bool? ?? zoomLock;
    pillRight = p['pillRight'] as bool? ?? pillRight;
    fullscreen = p['fullscreen'] as bool? ?? fullscreen;
    haptic = p['haptic'] as bool? ?? haptic;
    pillY = double.tryParse(p['pillY']?.toString() ?? '') ?? pillY;
    waDark = p['waDark'] as bool?;
  }

  void _set(VoidCallback f, String k, Object v) {
    f();
    Native.setPref(k, v);
    notifyListeners();
  }

  void setLang(String v) => _set(() => lang = v, 'lang', v);

  void setZoom(int v) {
    final z = v.clamp(70, 160);
    _set(() => zoom = z, 'zoom', z);
  }

  void setZoomLock(bool v) => _set(() => zoomLock = v, 'zoomLock', v);
  void setPillRight(bool v) => _set(() => pillRight = v, 'pillRight', v);
  void setFullscreen(bool v) => _set(() => fullscreen = v, 'fullscreen', v);
  void setHaptic(bool v) => _set(() => haptic = v, 'haptic', v);

  // pillY disimpan sebagai string (di-parse lagi saat load)
  void setPillY(double v) => _set(() => pillY = v, 'pillY', v.toString());

  void setWaDark(bool v) => _set(() => waDark = v, 'waDark', v);
}
