#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

// R channel = amplitude, G channel = peak-hold value (both 0..1)
layout(binding = 1) uniform sampler2D dataSource;

layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  vec4 fillColor;
  vec4 capColor;
  float count;
  float texWidth;
  float vertical;
  float mirrored;
  float flip;
  float segments;
  float showPeaks;
  float gapRatio;
  float barRatio;
};

// Nearest-sample fetch; segments are discrete so interpolation would only blur them.
vec2 fetchData(float idx) {
  float i = clamp(idx, 0.0, texWidth - 1.0);
  float u = (floor(i) + 0.5) / texWidth;
  return texture(dataSource, vec2(u, 0.5)).rg;
}

void main() {
  vec2 uv = qt_TexCoord0;

  // `along` runs across the band axis; `level` runs along the growth axis,
  // 0 at the bar's base and 1 at its far end.
  float along = (vertical > 0.5) ? uv.y : uv.x;
  float level = (vertical > 0.5) ? ((flip > 0.5) ? 1.0 - uv.x : uv.x) : 1.0 - uv.y;

  float totalBars = (mirrored > 0.5) ? count * 2.0 : count;
  float slot = 1.0 / totalBars;

  float bandIdx = clamp(floor(along / slot), 0.0, totalBars - 1.0);
  float inSlot = (along - bandIdx * slot) / slot;

  // Same mirroring as NLinearSpectrum: band 0 of the data sits at the center.
  float dataIdx = bandIdx;
  if (mirrored > 0.5) {
    dataIdx = (bandIdx < count) ? (count - 1.0 - bandIdx) : (bandIdx - count);
  }

  vec2 d = fetchData(dataIdx);
  float amp = clamp(d.r, 0.0, 1.0);
  float peak = clamp(d.g, 0.0, 1.0);

  // Bar occupies a centered fraction of its slot. Derive the AA width from `along`
  // rather than `inSlot`, which is discontinuous at every slot boundary.
  float halfBar = barRatio * 0.5;
  float slotEdge = fwidth(along) * totalBars;
  float sideMask = smoothstep(halfBar + slotEdge, halfBar - slotEdge, abs(inSlot - 0.5));

  // Carve the growth axis into discrete segments with a gap at the top of each.
  // fwidth(level) is continuous, unlike fwidth of the fract() below.
  float segPos = level * segments;
  float segIdx = floor(segPos);
  float segFrac = segPos - segIdx;
  float segEdge = fwidth(level) * segments;
  float solidTop = 1.0 - gapRatio;
  float segMask = smoothstep(solidTop + segEdge, solidTop - segEdge, segFrac);

  // Number of lit segments, and which segment the peak cap rides on. Clamping the
  // cap to at least the top lit segment keeps it from sinking into the bar body.
  float litCount = ceil(amp * segments);
  float peakSeg = clamp(ceil(peak * segments) - 1.0, 0.0, segments - 1.0);
  peakSeg = max(peakSeg, litCount - 1.0);

  bool lit = (segIdx + 0.5) < litCount;
  bool isCap = (showPeaks > 0.5) && (peak > 0.0) && (abs(segIdx - peakSeg) < 0.5);

  vec4 base = isCap ? capColor : fillColor;
  float on = (isCap || lit) ? 1.0 : 0.0;

  // Premultiplied alpha, matching wave_spectrum.frag
  float a = on * sideMask * segMask * base.a;
  fragColor = vec4(base.rgb * a, a) * qt_Opacity;
}
