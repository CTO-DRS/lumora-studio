#version 460 core
// Lumora Studio – local adjustment compositor.
// Blends an "edited" render over the "base" render through a mask that is
// either a texture (brush strokes / AI subject mask), a linear gradient or a
// radial (elliptical) gradient.
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform vec4 uTile;    // tileOffsetX, tileOffsetY, fullWidth, fullHeight
uniform vec4 uMode;    // mode (0 texture, 1 linear, 2 radial), invert, feather, amount
uniform vec4 uGeom;    // linear: x0,y0,x1,y1 | radial: cx,cy,rx,ry (normalized)
uniform vec4 uGeom2;   // radial rotation (radians), unused...

uniform sampler2D uBase;
uniform sampler2D uEdited;
uniform sampler2D uMask;   // only red channel is used

out vec4 fragColor;

vec2 fixUv(vec2 uv) {
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return uv;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 uv = p / uSize;
  vec2 gn = (p + uTile.xy) / uTile.zw;
  vec4 base = texture(uBase, fixUv(uv));
  vec4 edited = texture(uEdited, fixUv(uv));

  float m = 0.0;
  float feather = max(uMode.z, 0.001);
  if (uMode.x < 0.5) {
    m = texture(uMask, fixUv(gn)).r;  // masks are rasterised render targets
  } else if (uMode.x < 1.5) {
    vec2 a = uGeom.xy;
    vec2 b = uGeom.zw;
    vec2 ab = b - a;
    float t = dot(gn - a, ab) / max(dot(ab, ab), 1e-6);
    // Full effect before `a`, fading out towards `b`.
    m = 1.0 - smoothstep(0.0, 1.0, t);
  } else {
    vec2 d = gn - uGeom.xy;
    float aspect = uTile.z / uTile.w;
    d.x *= aspect;
    float cs = cos(uGeom2.x);
    float sn = sin(uGeom2.x);
    d = vec2(cs * d.x + sn * d.y, -sn * d.x + cs * d.y);
    vec2 r = max(uGeom.zw * vec2(aspect, 1.0), vec2(1e-4));
    float dist = length(d / r);
    m = 1.0 - smoothstep(1.0 - feather, 1.0 + feather * 0.25, dist);
  }
  if (uMode.y > 0.5) m = 1.0 - m;
  m = clamp(m * uMode.w, 0.0, 1.0);
  fragColor = mix(base, edited, m);
}
