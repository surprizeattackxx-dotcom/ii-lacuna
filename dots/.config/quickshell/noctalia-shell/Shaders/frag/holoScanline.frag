#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    vec4 glowColor;
} ubuf;

void main() {
    vec4 base = texture(source, qt_TexCoord0);

    float dist = abs(qt_TexCoord0.y - ubuf.time);
    float band = smoothstep(0.05, 0.0, dist) * base.a;

    fragColor = vec4(ubuf.glowColor.rgb * band * ubuf.qt_Opacity, band * ubuf.qt_Opacity);
}
