#version 460 core
// Lumora Studio – geometry pass: crop, rotate, straighten, flip and
// perspective (keystone) in a single inverse-homography lookup.
#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 uSize;     // output size in px
uniform vec4 uRow0;     // inverse homography rows (output px -> source normalized)
uniform vec4 uRow1;
uniform vec4 uRow2;

uniform sampler2D uImage;

out vec4 fragColor;

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec3 h = vec3(p, 1.0);
  float w = dot(uRow2.xyz, h);
  vec2 s = vec2(dot(uRow0.xyz, h), dot(uRow1.xyz, h)) / w;
  if (s.x < 0.0 || s.y < 0.0 || s.x > 1.0 || s.y > 1.0) {
    fragColor = vec4(0.0);
    return;
  }
  // The geometry pass always samples a decoded (non render-target) texture,
  // so no GLES y-flip is needed here; every later pass flips.
  fragColor = texture(uImage, s);
}
