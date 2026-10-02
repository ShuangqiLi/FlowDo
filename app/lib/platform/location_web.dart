import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<(double, double)?> readDeviceLocation() async {
  final geo = web.window.navigator.geolocation;
  final completer = Completer<(double, double)?>();
  geo.getCurrentPosition(
    (web.GeolocationPosition pos) {
      completer.complete((pos.coords.latitude, pos.coords.longitude));
    }.toJS,
    (web.GeolocationPositionError _) {
      completer.complete(null);
    }.toJS,
    web.PositionOptions(enableHighAccuracy: false, timeout: 5000, maximumAge: 600000),
  );
  return completer.future.timeout(
    const Duration(seconds: 6),
    onTimeout: () => null,
  );
}
