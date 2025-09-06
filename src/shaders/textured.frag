#version 330 core

noperspective in vec2 outTexCoord;
in vec4 vertLightColor;

out vec4 outColor;

uniform sampler2D sampler;
uniform bool textured;

void main() {
    outColor = vertLightColor;
    if (textured) {
        outColor *= texture(sampler, outTexCoord);
    }
}
