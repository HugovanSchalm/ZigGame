#version 330 core

noperspective in vec2 outTexCoord;
in vec4 vertLightColor;

out vec4 outColor;

uniform sampler2D sampler;

void main() {
    outColor = vertLightColor * texture(sampler, outTexCoord);
}
