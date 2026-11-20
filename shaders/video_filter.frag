#version 460 core
// Lumora Studio – real-time video preview filter used through
// ImageFilter.shader (Impeller). The engine binds the first vec2 to the
// child size and the first sampler to the child's rendered texture.
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform vec4 uTone;     // exposure EV, contrast, highlights, shadows
uniform vec4 uColor;    // temperature, tint, vibrance, saturation
uniform vec4 uFx;       // fade, vignette, grain, time
uniform vec4 uLutInfo;  // enabled, size, intensity, unused

uniform sampler2D uImage;
uniform sampler2D uLut;

out vec4 fragColor;

const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

vec3 sampleLut(vec3 c) {
  float n = uLutInfo.y;
  vec3 s = clamp(c, 0.0, 1.0) * (n - 1.0);
  float b0 = floor(s.b);
  float b1 = min(b0 + 1.0, n - 1.0);
  float y = (s.g + 0.5) / n;
  vec3 c0 = texture(uLut, vec2((b0 * n + s.r + 0.5) / (n * n), y)).rgb;
  vec3 c1 = texture(uLut, vec2((b1 * n + s.r + 0.5) / (n * n), y)).rgb;
  return mix(c0, c1, s.b - b0);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 uv = p / uSize;
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  vec4 src = texture(uImage, uv);
  vec3 c = src.a > 0.0 ? src.rgb / src.a : src.rgb;

  vec3 lin = pow(max(c, vec3(0.0)), vec3(2.2));
  lin *= vec3(1.0 + 0.25 * uColor.x, 1.0 - 0.18 * uColor.y, 1.0 - 0.25 * uColor.x);
  lin *= exp2(uTone.x);
  c = pow(max(lin, vec3(0.0)), vec3(1.0 / 2.2));

  float l = dot(clamp(c, 0.0, 1.0), kLuma);
  float shMask = pow(1.0 - smoothstep(0.0, 0.55, l), 1.6);
  float hiMask = pow(smoothstep(0.45, 1.0, l), 1.4);
  float target = l + uTone.w * 0.45 * shMask * (1.0 - l) + uTone.z * 0.45 * hiMask * l;
  c *= l > 1e-4 ? target / l : 1.0;

  vec3 cc = clamp(c, 0.0, 1.0);
  vec3 s = cc * cc * (3.0 - 2.0 * cc);
  c = uTone.y >= 0.0 ? mix(c, s, uTone.y) : mix(c, vec3(0.5) + (c - 0.5) * 0.6, -uTone.y);
  c = clamp(c, 0.0, 1.0);

  float luma = dot(c, kLuma);
  float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
  c = mix(vec3(luma), c, 1.0 + uColor.z * (1.0 - sat));
  c = mix(vec3(dot(c, kLuma)), c, 1.0 + uColor.w);
  c = mix(c, vec3(0.08) + c * 0.9, uFx.x);

  if (uLutInfo.x > 0.5) c = mix(c, sampleLut(c), uLutInfo.z);

  vec2 d = p / uSize - 0.5;
  float v = smoothstep(0.35, 0.95, length(d) * 1.414);
  c *= 1.0 - uFx.y * v;

  if (uFx.z > 0.0) c += (hash(p + uFx.w) - 0.5) * uFx.z * 0.25;

  fragColor = vec4(clamp(c, 0.0, 1.0) * src.a, src.a);
}
