#version 460 core
// Lumora Studio – clipping warning overlay. Pixels whose channels are
// blown out (>= highlight threshold) become red, crushed shadows (all
// channels <= shadow threshold) become blue; everything else is clear.
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform vec4 uThreshold;  // highlight, shadow, showHighlights, showShadows

uniform sampler2D uImage;

out vec4 fragColor;

vec2 fixUv(vec2 uv) {
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return uv;
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec4 c = texture(uImage, fixUv(p / uSize));
  vec3 rgb = c.a > 0.0 ? c.rgb / c.a : vec3(0.0);
  float hi = max(max(rgb.r, rgb.g), rgb.b);
  float lo = max(max(rgb.r, rgb.g), rgb.b);
  if (uThreshold.z > 0.5 && hi >= uThreshold.x && c.a > 0.0) {
    fragColor = vec4(0.95, 0.12, 0.2, 1.0) * 0.85;
  } else if (uThreshold.w > 0.5 && lo <= uThreshold.y && c.a > 0.0) {
    fragColor = vec4(0.15, 0.4, 1.0, 1.0) * 0.85;
  } else {
    fragColor = vec4(0.0);
  }
}
