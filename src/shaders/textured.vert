#version 330 core

layout (location = 0) in vec3 inPosition;
layout (location = 1) in vec2 inTexCoord;
layout (location = 2) in vec3 inNormal;

noperspective out vec2 outTexCoord;
out vec4 vertLightColor;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

uniform vec3 lightColor;
uniform vec3 lightPos;
uniform float ambientStrength;

uniform vec4 meshColor;

uniform vec2 targetResolution;

uniform bool snapVertices;

void main() {
    vec2 grid = targetResolution * 0.5;
    vec4 vertInClipSpace = projection * view * model * vec4(inPosition, 1.0);
    vec4 snapped = vertInClipSpace;

    if (snapVertices) {
        snapped.xyz = vertInClipSpace.xyz / vertInClipSpace.w;
        snapped.xy = floor(grid * snapped.xy) / grid;
        snapped.xyz *= vertInClipSpace.w;
    }

    gl_Position = snapped;

    vec3 position = vec3(model * vec4(inPosition, 1.0));
    outTexCoord = inTexCoord;

    vec3 ambient = ambientStrength * lightColor;

    vec3 norm = mat3(transpose(inverse(model))) * inNormal;
    vec3 lightDir = normalize(lightPos - position);
    float diff = max(dot(norm, lightDir), 0.0);
    vec3 diffuse = diff * lightColor;

    vec3 lightResult = ambient + diffuse;

    vertLightColor = vec4(lightResult, 1.0) * meshColor;
}
