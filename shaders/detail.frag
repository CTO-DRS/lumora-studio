#version 460 core
// Lumora Studio – neighbourhood "detail" pass: sharpen (unsharp mask),
// clarity / structure (local contrast at two radii) and dehaze (dark channel).
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform vec4 uDetail;  // sharpen(0..1), clarity(-1..1), structure(-1..1), dehaze(-1..1)
uniform vec4 uRadius;  // sharpenRadiusPx, clarityRadiusPx, structureRadiusPx, unused

uniform sampler2D uImage;

out vec4 fragColor;

const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);

vec2 fixUv(vec2 uv) {
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return uv;
}

vec3 tap(vec2 px) {
  return texture(uImage, fixUv(clamp(px, vec2(0.5), uSize - 0.5) / uSize)).rgb;
}

// 12-tap ring blur at radius r (cheap approximation of a gaussian).
vec3 ringBlur(vec2 p, float r) {
  vec3 acc = tap(p) * 2.0;
  float w = 2.0;
  for (int i = 0; i < 12; i++) {
    float a = float(i) * 0.5235988;  // 30 deg
    vec2 o = vec2(cos(a), sin(a));
    acc += tap(p + o * r) * 1.0;
    acc += tap(p + o * r * 0.5) * 1.5;
    w += 2.5;
  }
  return acc / w;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec4 src = texture(uImage, fixUv(p / uSize));
  vec3 c = src.rgb;

  // Sharpen: unsharp mask on luminance to avoid colour fringes.
  if (uDetail.x > 0.0) {
    vec3 b = ringBlur(p, uRadius.x);
    float d = dot(c - b, kLuma);
    c += d * uDetail.x * 2.0;
  }

  // Structure: fine local contrast.
  if (abs(uDetail.z) > 0.0) {
    vec3 b = ringBlur(p, uRadius.z);
    float d = dot(c - b, kLuma);
    c += d * uDetail.z * 1.2;
  }

  // Clarity: mid-tone local contrast with a large radius.
  if (abs(uDetail.y) > 0.0) {
    vec3 b = ringBlur(p, uRadius.y);
    float l = dot(c, kLuma);
    float midMask = 1.0 - pow(abs(l - 0.5) * 2.0, 2.0);
    float d = dot(c - b, kLuma);
    c += d * uDetail.y * 1.5 * midMask;
  }

  // Dehaze: dark channel prior with a fixed atmospheric light.
  if (abs(uDetail.w) > 0.0) {
    vec3 b = ringBlur(p, uRadius.y);
    float dark = min(min(b.r, b.g), b.b);
    if (uDetail.w > 0.0) {
      float t = max(1.0 - 0.95 * dark * uDetail.w, 0.15);
      vec3 a = vec3(0.98);
      c = (c - a) / t + a;
    } else {
      c = mix(c, vec3(0.85), -uDetail.w * 0.4 * (1.0 - dark));
    }
  }

  c = clamp(c, 0.0, src.a);
  fragColor = vec4(c, src.a);
}
