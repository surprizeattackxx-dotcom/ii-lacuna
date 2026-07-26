#version 450

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(binding = 1) uniform sampler2D source;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float intensity;
    vec4 glowColor;
} ubuf;

void main() {
    vec4 base = texture(source, qt_TexCoord0);
    float a = base.a * ubuf.intensity;
    fragColor = vec4(ubuf.glowColor.rgb * a * ubuf.qt_Opacity, a * ubuf.qt_Opacity);
}
