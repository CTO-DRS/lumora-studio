#version 460 core
// Lumora Studio – global "develop" pass.
// Tone (exposure, contrast, highlights/shadows, whites/blacks), white balance
// (temperature/tint), color (vibrance/saturation, 8-band HSL), split toning,
// fade, RGB + per-channel curves (256x1 texture) and 3D LUT (atlas texture).
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform vec4 uTone;     // exposure EV, contrast, highlights, shadows   (-1..1, EV -5..5)
uniform vec4 uTone2;    // whites, blacks, temperature, tint            (-1..1)
uniform vec4 uColor;    // vibrance, saturation, fade, lutIntensity
uniform vec4 uHslHue0;  // red, orange, yellow, green   hue shift (-1..1 => +-30deg)
uniform vec4 uHslHue1;  // aqua, blue, purple, magenta
uniform vec4 uHslSat0;
uniform vec4 uHslSat1;
uniform vec4 uHslLum0;
uniform vec4 uHslLum1;
uniform vec4 uSplit;    // shadowHue(0..1), shadowSat, highlightHue, highlightSat
uniform vec4 uFlags;    // curvesEnabled, lutEnabled, lutSize, splitBalance(-1..1)

uniform sampler2D uImage;
uniform sampler2D uCurves; // 256x1, r,g,b channel curves, a = master (RGB) curve
uniform sampler2D uLut;    // (N*N) x N atlas, red fastest, blue = slice

out vec4 fragColor;

const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);

vec3 toLinear(vec3 c) { return pow(max(c, vec3(0.0)), vec3(2.2)); }
vec3 toGamma(vec3 c) { return pow(max(c, vec3(0.0)), vec3(1.0 / 2.2)); }

vec3 rgb2hsl(vec3 c) {
  float mx = max(c.r, max(c.g, c.b));
  float mn = min(c.r, min(c.g, c.b));
  float l = (mx + mn) * 0.5;
  float h = 0.0;
  float s = 0.0;
  float d = mx - mn;
  if (d > 1e-5) {
    s = l > 0.5 ? d / (2.0 - mx - mn) : d / (mx + mn);
    if (mx == c.r) {
      h = (c.g - c.b) / d + (c.g < c.b ? 6.0 : 0.0);
    } else if (mx == c.g) {
      h = (c.b - c.r) / d + 2.0;
    } else {
      h = (c.r - c.g) / d + 4.0;
    }
    h /= 6.0;
  }
  return vec3(h, s, l);
}

float hue2rgb(float p, float q, float t) {
  if (t < 0.0) t += 1.0;
  if (t > 1.0) t -= 1.0;
  if (t < 1.0 / 6.0) return p + (q - p) * 6.0 * t;
  if (t < 0.5) return q;
  if (t < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - t) * 6.0;
  return p;
}

vec3 hsl2rgb(vec3 hsl) {
  if (hsl.y <= 1e-5) return vec3(hsl.z);
  float q = hsl.z < 0.5 ? hsl.z * (1.0 + hsl.y) : hsl.z + hsl.y - hsl.z * hsl.y;
  float p = 2.0 * hsl.z - q;
  return vec3(hue2rgb(p, q, hsl.x + 1.0 / 3.0), hue2rgb(p, q, hsl.x),
              hue2rgb(p, q, hsl.x - 1.0 / 3.0));
}

// Smooth weight of hue `h` (0..1) belonging to band centered at `c` (degrees).
float bandWeight(float h, float c, float width) {
  float d = abs(h * 360.0 - c);
  d = min(d, 360.0 - d);
  return clamp(1.0 - d / width, 0.0, 1.0);
}

vec3 applyHsl(vec3 c) {
  vec3 hsl = rgb2hsl(c);
  if (hsl.y < 0.01) return c;
  // Centers: red 0, orange 30, yellow 60, green 120, aqua 180, blue 225,
  // purple 270, magenta 315.
  float w0 = bandWeight(hsl.x, 0.0, 30.0);
  float w1 = bandWeight(hsl.x, 30.0, 30.0);
  float w2 = bandWeight(hsl.x, 60.0, 45.0);
  float w3 = bandWeight(hsl.x, 120.0, 60.0);
  float w4 = bandWeight(hsl.x, 180.0, 45.0);
  float w5 = bandWeight(hsl.x, 225.0, 45.0);
  float w6 = bandWeight(hsl.x, 270.0, 45.0);
  float w7 = bandWeight(hsl.x, 315.0, 45.0);
  vec4 wa = vec4(w0, w1, w2, w3);
  vec4 wb = vec4(w4, w5, w6, w7);
  float total = max(dot(wa, vec4(1.0)) + dot(wb, vec4(1.0)), 1e-4);
  float hueShift = (dot(wa, uHslHue0) + dot(wb, uHslHue1)) / total;
  float satShift = (dot(wa, uHslSat0) + dot(wb, uHslSat1)) / total;
  float lumShift = (dot(wa, uHslLum0) + dot(wb, uHslLum1)) / total;
  float strength = min(total, 1.0) * smoothstep(0.0, 0.15, hsl.y);
  hsl.x = fract(hsl.x + hueShift * strength * (30.0 / 360.0));
  hsl.y = clamp(hsl.y * (1.0 + satShift * strength), 0.0, 1.0);
  hsl.z = clamp(hsl.z + lumShift * strength * 0.25 * hsl.y, 0.0, 1.0);
  return hsl2rgb(hsl);
}

vec3 sampleLut(vec3 c) {
  float n = uFlags.z;
  vec3 s = clamp(c, 0.0, 1.0) * (n - 1.0);
  float b0 = floor(s.b);
  float b1 = min(b0 + 1.0, n - 1.0);
  float fb = s.b - b0;
  float y = (s.g + 0.5) / n;
  float x0 = (b0 * n + s.r + 0.5) / (n * n);
  float x1 = (b1 * n + s.r + 0.5) / (n * n);
  vec3 c0 = texture(uLut, vec2(x0, y)).rgb;
  vec3 c1 = texture(uLut, vec2(x1, y)).rgb;
  return mix(c0, c1, fb);
}

float curve(float v, int ch) {
  vec4 t = texture(uCurves, vec2(clamp(v, 0.0, 1.0) * (255.0 / 256.0) + 0.5 / 256.0, 0.5));
  if (ch == 0) return t.r;
  if (ch == 1) return t.g;
  if (ch == 2) return t.b;
  return t.a;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  vec4 src = texture(uImage, uv);
  float alpha = src.a;
  vec3 c = alpha > 0.0 ? src.rgb / alpha : src.rgb;

  // ---- White balance + exposure in linear light.
  vec3 lin = toLinear(c);
  float temp = uTone2.z;
  float tint = uTone2.w;
  lin *= vec3(1.0 + 0.25 * temp, 1.0 - 0.18 * tint, 1.0 - 0.25 * temp);
  lin.rb *= 1.0 + 0.08 * tint;
  lin *= exp2(uTone.x);
  c = toGamma(lin);

  // ---- Whites / blacks (levels).
  float bp = -uTone2.y * 0.12;
  float wp = 1.0 - uTone2.x * 0.18;
  c = (c - bp) / max(wp - bp, 0.05);

  // ---- Highlights / shadows (luminance masked).
  float l = dot(clamp(c, 0.0, 1.0), kLuma);
  float shMask = pow(1.0 - smoothstep(0.0, 0.55, l), 1.6);
  float hiMask = pow(smoothstep(0.45, 1.0, l), 1.4);
  float lumTarget = l + uTone.w * 0.45 * shMask * (uTone.w > 0.0 ? (1.0 - l) : l)
      + uTone.z * 0.45 * hiMask * (uTone.z > 0.0 ? (1.0 - l) : l);
  c *= (l > 1e-4) ? lumTarget / l : 1.0;

  // ---- Contrast (S-curve around mid grey).
  float k = uTone.y;
  vec3 cc = clamp(c, 0.0, 1.0);
  vec3 sCurve = cc * cc * (3.0 - 2.0 * cc);
  c = k >= 0.0 ? mix(c, sCurve, k) : mix(c, vec3(0.5) + (c - 0.5) * 0.6, -k);

  c = clamp(c, 0.0, 1.0);

  // ---- HSL mixer.
  c = applyHsl(c);

  // ---- Vibrance & saturation.
  float luma = dot(c, kLuma);
  float mx = max(c.r, max(c.g, c.b));
  float mn = min(c.r, min(c.g, c.b));
  float sat = mx - mn;
  float vib = uColor.x * (1.0 - sat) * (uColor.x > 0.0 ? 1.0 : 0.6);
  c = mix(vec3(luma), c, 1.0 + vib);
  c = mix(vec3(dot(c, kLuma)), c, 1.0 + uColor.y);
  c = clamp(c, 0.0, 1.0);

  // ---- Split toning.
  if (uSplit.y > 0.0 || uSplit.w > 0.0) {
    float lum = dot(c, kLuma);
    float balance = uFlags.w * 0.5;
    float shW = (1.0 - smoothstep(0.0, 0.5 + balance, lum)) * uSplit.y;
    float hiW = smoothstep(0.5 + balance, 1.0, lum) * uSplit.w;
    vec3 shTint = hsl2rgb(vec3(uSplit.x, 1.0, 0.5));
    vec3 hiTint = hsl2rgb(vec3(uSplit.z, 1.0, 0.5));
    c = mix(c, c * (shTint * 1.6), shW * 0.35);
    c = mix(c, 1.0 - (1.0 - c) * (1.0 - hiTint * 0.6), hiW * 0.5);
  }

  // ---- Curves.
  if (uFlags.x > 0.5) {
    c = vec3(curve(c.r, 0), curve(c.g, 1), curve(c.b, 2));
    c = vec3(curve(c.r, 3), curve(c.g, 3), curve(c.b, 3));
  }

  // ---- Fade (matte blacks).
  c = mix(c, vec3(0.08) + c * 0.9, uColor.z);

  // ---- 3D LUT.
  if (uFlags.y > 0.5) {
    c = mix(c, sampleLut(c), uColor.w);
  }

  c = clamp(c, 0.0, 1.0);
  fragColor = vec4(c * alpha, alpha);
}
