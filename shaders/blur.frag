#version 460 core
// Lumora Studio – separable gaussian blur (run twice: horizontal, vertical).
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;
uniform vec4 uBlur;  // dirX, dirY, radiusPx, unused

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
  float radius = uBlur.z;
  if (radius < 0.5) {
    fragColor = texture(uImage, fixUv(p / uSize));
    return;
  }
  vec2 dir = uBlur.xy;
  float sigma = radius * 0.5;
  vec4 acc = vec4(0.0);
  float wsum = 0.0;
  // 25 taps spread over the radius; linear filtering fills the gaps.
  for (int i = -12; i <= 12; i++) {
    float x = float(i) / 12.0 * radius;
    float w = exp(-(x * x) / (2.0 * sigma * sigma));
    vec2 q = clamp(p + dir * x, vec2(0.5), uSize - 0.5);
    acc += texture(uImage, fixUv(q / uSize)) * w;
    wsum += w;
  }
  fragColor = acc / wsum;
}
