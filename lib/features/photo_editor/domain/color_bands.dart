import 'dart:math' as math;

/// Centre hue (degrees) of each of the 8 HSL mixer bands: red, orange,
/// yellow, green, aqua, blue, purple, magenta.
const kHslBandCenters = <double>[0, 30, 60, 120, 180, 240, 270, 300];

/// Hue in degrees (0..360) of an sRGB colour (channels 0..255), or null for
/// greys.
double? hueOf(double r, double g, double b) {
  final mx = math.max(r, math.max(g, b));
  final mn = math.min(r, math.min(g, b));
  final d = mx - mn;
  if (d < 1e-6) return null;
  double h;
  if (mx == r) {
    h = ((g - b) / d) % 6;
  } else if (mx == g) {
    h = (b - r) / d + 2;
  } else {
    h = (r - g) / d + 4;
  }
  h *= 60;
  return h < 0 ? h + 360 : h;
}

/// The HSL band whose centre is closest to the colour's hue (circular).
/// Greys map to red (band 0) since no band affects them anyway.
int hslBandForRgb(double r, double g, double b) {
  final h = hueOf(r, g, b);
  if (h == null) return 0;
  var best = 0;
  var bestD = double.infinity;
  for (var i = 0; i < kHslBandCenters.length; i++) {
    final d = (h - kHslBandCenters[i]).abs();
    final circ = math.min(d, 360 - d);
    if (circ < bestD) {
      bestD = circ;
      best = i;
    }
  }
  return best;
}
