#version 460 core
// Lumora Studio – creative effects pass: chromatic aberration, glitch,
// duotone, vignette and film grain. Tile aware: uTile maps the current tile
// into the full output image so position dependent effects stay seamless.
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform vec4 uTile;      // tileOffsetX, tileOffsetY, fullWidth, fullHeight (px)
uniform vec4 uVignette;  // amount(-1..1), midpoint(0..1), roundness(-1..1), feather(0..1)
uniform vec4 uGrain;     // amount(0..1), size(0..1), seed, chromatic aberration(0..1)
uniform vec4 uGlitch;    // amount(0..1), seed, duotoneStrength(0..1), unused
uniform vec4 uDuoShadow; // rgb
uniform vec4 uDuoLight;  // rgb

uniform sampler2D uImage;

out vec4 fragColor;

const vec3 kLuma = vec3(0.2126, 0.7152, 0.0722);

vec2 fixUv(vec2 uv) {
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return uv;
}

vec4 tapPx(vec2 px) {
  return texture(uImage, fixUv(clamp(px, vec2(0.5), uSize - 0.5) / uSize));
}

float hash(vec2 p) {
  p = fract(p * vec2(123.34, 456.21));
  p += dot(p, p + 45.32);
  return fract(p.x * p.y);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  float a = hash(i);
  float b = hash(i + vec2(1.0, 0.0));
  float c = hash(i + vec2(0.0, 1.0));
  float d = hash(i + vec2(1.0, 1.0));
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 g = p + uTile.xy;              // global pixel position
  vec2 full = uTile.zw;
  vec2 gn = g / full;                 // global normalized position
  float minDim = min(full.x, full.y);

  vec2 samplePx = p;

  // ---- Glitch: horizontal slice displacement.
  float glitch = uGlitch.x;
  if (glitch > 0.0) {
    float band = floor(gn.y * 40.0);
    float r = hash(vec2(band, uGlitch.y));
    if (r < glitch * 0.6) {
      samplePx.x += (hash(vec2(band, uGlitch.y + 7.0)) - 0.5) * glitch * 0.15 * full.x;
    }
  }

  vec4 src = tapPx(samplePx);
  vec3 c = src.rgb;

  // ---- Chromatic aberration (radial) + glitch RGB split.
  float ca = uGrain.w;
  float split = ca * 0.006 * minDim + glitch * 0.01 * minDim;
  if (split > 0.0) {
    vec2 dir = normalize(gn - 0.5 + 1e-5) * length(gn - 0.5) * 2.0;
    if (glitch > 0.0) dir = vec2(1.0, 0.0);
    c.r = tapPx(samplePx + dir * split).r;
    c.b = tapPx(samplePx - dir * split).b;
  }

  // ---- Duotone.
  if (uGlitch.z > 0.0) {
    float l = dot(c, kLuma);
    vec3 duo = mix(uDuoShadow.rgb, uDuoLight.rgb, smoothstep(0.0, 1.0, l));
    c = mix(c, duo * src.a, uGlitch.z);
  }

  // ---- Vignette.
  if (uVignette.x != 0.0) {
    vec2 d = gn - 0.5;
    float aspect = full.x / full.y;
    float round = uVignette.z;
    d.x *= mix(1.0, aspect, (round + 1.0) * 0.5);
    float dist = length(d) * 2.0;
    float mid = mix(0.2, 1.2, uVignette.y);
    float feather = max(uVignette.w, 0.02);
    float v = smoothstep(mid - feather, mid + feather, dist);
    if (uVignette.x < 0.0) {
      c *= 1.0 + uVignette.x * v;
    } else {
      c = mix(c, vec3(src.a), uVignette.x * v);
    }
  }

  // ---- Film grain (luminance weighted, size controlled).
  if (uGrain.x > 0.0) {
    float scale = mix(0.9, 0.25, uGrain.y) * (minDim / 1000.0 + 0.6);
    float n = noise(g * scale + uGrain.z * 17.0) - 0.5;
    n += (noise(g * scale * 2.1 + 31.0 + uGrain.z) - 0.5) * 0.5;
    float l = dot(c, kLuma);
    float w = 1.0 - pow(abs(l - 0.5) * 2.0, 2.0) * 0.6;
    c += n * uGrain.x * 0.28 * w;
  }

  c = clamp(c, 0.0, src.a);
  fragColor = vec4(c, src.a);
}
