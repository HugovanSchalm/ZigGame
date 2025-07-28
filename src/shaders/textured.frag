#version 330 core

in vec2 outTexCoord;
in vec4 normalLightColor;

out vec4 outColor;

uniform sampler2D sampler;

void main() {
    outColor = normalLightColor * texture(sampler, outTexCoord);
}
