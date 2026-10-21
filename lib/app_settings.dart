import 'package:flutter/foundation.dart';

import 'file_saver.dart';

const List<int> kZoomSteps = [
  40, 50, 60, 70, 80, 90, 100, 110, 125, 150, 175, 200, 250, 300
];

/// Lebar layout (CSS px) untuk zoom tertentu. 980 = lebar "desktop site".
int viewWidthFor(int zoom) => (980 * 100 / zoom).round();

class AppSettings extends ChangeNotifier {
  String lang = 'id';
  int zoom = 100; // zoom web dalam %, 100 = tampilan desktop
  bool zoomLock = true; // true = pinch zoom dikunci
  bool pillRight = true;
  bool fullscreen = false;
  bool haptic = true;
  double pillY = 0.45;
  bool? waDark;

  Future<void> load() async {
    final p = await Native.prefs();
    lang = p['lang'] as String? ?? lang;
    zoom = (p['webZoom'] as int? ?? zoom).clamp(kZoomSteps.first, kZoomSteps.last);
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
    final z = v.clamp(kZoomSteps.first, kZoomSteps.last);
    _set(() => zoom = z, 'webZoom', z);
  }

  void zoomIn() => setZoom(kZoomSteps.firstWhere((e) => e > zoom,
      orElse: () => kZoomSteps.last));

  void zoomOut() => setZoom(kZoomSteps.lastWhere((e) => e < zoom,
      orElse: () => kZoomSteps.first));

  void setZoomLock(bool v) => _set(() => zoomLock = v, 'zoomLock', v);
  void setPillRight(bool v) => _set(() => pillRight = v, 'pillRight', v);
  void setFullscreen(bool v) => _set(() => fullscreen = v, 'fullscreen', v);
  void setHaptic(bool v) => _set(() => haptic = v, 'haptic', v);

  // pillY disimpan sebagai string (di-parse lagi saat load)
  void setPillY(double v) => _set(() => pillY = v, 'pillY', v.toString());

  void setWaDark(bool v) => _set(() => waDark = v, 'waDark', v);
}
