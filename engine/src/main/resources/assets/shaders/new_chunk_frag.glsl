/*
 * Copyright 2012 Benjamin Glatzel <benjamin.glatzel@me.com>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
*/

#define WATER_COLOR_SWIMMING 0.8, 1.0, 1.0, 0.975
#define WATER_TINT 0.1, 0.41, 0.627, 1.0

#define WATER_SPEC 1.0



#if defined (NORMAL_MAPPING)
varying vec3 worldSpaceNormal;
varying mat3 normalMatrix;

uniform sampler2D textureAtlasNormal;
#endif

#if defined (PARALLAX_MAPPING)
uniform vec4 parallaxProperties;
#define parallaxBias parallaxProperties.x
#define parallaxScale parallaxProperties.y

uniform sampler2D textureAtlasHeight;
#endif


#if defined (FLICKERING_LIGHT)
varying float flickeringLightOffset;
#endif



varying vec3 vertexWorldPos;
varying vec4 vertexViewPos;
varying vec4 vertexProjPos;
varying vec3 sunVecView;

varying vec3 normal;

varying float blockHint;
varying float isUpside;

uniform sampler2D textureAtlas;
uniform sampler2D textureEffects;
uniform sampler2D textureLava;

uniform float clip;

mat2 inverse2(mat2 m) {
    float det = m[0][0] * m[1][1] - m[1][0] * m[0][1];
    return mat2(m[1][1], -m[0][1], -m[1][0], m[0][0]) / det;
}

// lava color
vec4 getLavaColor(float time, sampler2D textureLava, vec2 texCoord, float texOffset) {
    texCoord.x = mod(texCoord.x, texOffset) * (1.0 / texOffset);
    texCoord.y = mod(texCoord.y, texOffset) / (128.0 / (1.0 / texOffset));
    texCoord.y += mod(timeToTick(time, -0.1), 127.0) * (1.0/128.0);

    vec4 color = texture2D(textureLava, texCoord.xy);
    return color;
}

// gets chunk color given sampler and texCoord
vec4 getColor(float time, sampler2D textureAtlas, sampler2D textureLava, sampler2D textureEffects, vec2 texCoord, float texOffset, bool alphaReject, bool isLava, bool isGrass, vec3 glColor, float textureOffsetEffects) {
    vec4 color = vec4(0.0, 0.0, 0.0, 1.0);

    if (isLava) {
        color = getLavaColor(time, textureLava, texCoord, texOffset);
    /* APPLY DEFAULT TEXTURE FROM ATLAS */
    }
    else {
        color = texture2D(textureAtlas, texCoord.xy);

        if (alphaReject && color.a < 0.1) {
            discard;
        }
    }

    if (isGrass) {
        vec4 maskColor = texture2D(textureEffects, vec2(10.0 * textureOffsetEffects + mod(texCoord.x, textureOffsetEffects), mod(texCoord.y, textureOffsetEffects)));

        // Only use one channel so the color won't be altered
        if (maskColor.a != 0.0) {
            color.rgb = vec3(color.g) * glColor.rgb;
        }
    }
    else {
        if (glColor.r < 0.99 && glColor.g < 0.99 && glColor.b < 0.99) {
            if (color.g > 0.5) {
                color.rgb = vec3(color.g) * glColor.rgb;
            } else {
                color.rgb *= glColor.rgb;
            }
        }
    }

    return color;
}

float getShininess(sampler2D textureAtlasNormal, vec2 texCoord) {
    float shininess = texture2D(textureAtlasNormal, texCoord).w;

    return shininess;
}

mat2x3 getUvToView(vec3 vertexViewPos, vec2 texCoord, float texOffset) {
    mat2x3 screenToView = mat2x3(dFdx(vertexViewPos), dFdy(vertexViewPos));
    mat2   screenToUv   = mat2  (dFdx(texCoord), dFdy(texCoord)) / texOffset;
    mat2 uvToScreen = inverse2(screenToUv);
    mat2x3 uvToView = screenToView * uvToScreen;
    return uvToView;
}

vec2 getTexCoordParallax(vec2 texCoord, float texOffset, mat2x3 uvToView, vec3 normalizedViewPos, float parallaxScale, float parallaxBias, sampler2D textureAtlasHeight) {
    vec2 viewDirectionUvProjection = -normalizedViewPos * uvToView;

    float height = parallaxScale * texture2D(textureAtlasHeight, texCoord).r - parallaxBias;
    texCoord += height * viewDirectionUvProjection * texOffset;

    vec2 texCorner = floor(texCoord / texOffset) * texOffset;
    vec2 texSize = vec2(1,1)*texOffset*0.9999;
    texCoord = clamp(texCoord, texCorner, texCorner + texSize);
    return texCoord;
}

vec2 getNormalOpaque(mat2x3 uvToView, vec3 normal, sampler2D textureAtlasNormal, vec2 texCoord) {
    vec3 normalOpaque = vec3(0.0, 0.0, 0.0);
    mat3 uvnSpaceToViewSpace = mat3(normalize(uvToView[0]), normalize(uvToView[1]), normal);
    normalOpaque = normalize(texture2D(textureAtlasNormal, texCoord).xyz * 2.0 - 1.0);
    normalOpaque = normalize(uvnSpaceToViewSpace * normal);
    return normalOpaque;
}

void main() {

    bool normalMapping = false;
    bool parallaxMapping = false;
    bool flickeringLight = false;
#if defined (NORMAL_MAPPING)
    normalMapping = true;
#endif
#if defined (PARALLAX_MAPPING)
    parallaxMapping = true;
#endif
#if defined (FLICKERING_LIGHT)
    flickeringLight = true;
#endif

    vec2 texCoord = gl_TexCoord[0].xy;
    float texOffset = TEXTURE_OFFSET;
    float textureOffsetEffects = TEXTURE_OFFSET_EFFECTS;
    vec3 glColor = gl_Color.rgb;

    vec3 normalizedViewPos = -normalize(vertexViewPos.xyz);
    vec2 projectedPos = projectVertexToTexCoord(vertexProjPos);
    vec3 normalOpaque = normal;

    float shininess = 0.0;

#if defined (NORMAL_MAPPING) || defined (PARALLAX_MAPPING)
    mat2x3 uvToView = getUvToView(vertexViewPos.xyz, gl_TexCoord[0].xy, texOffset);
#if defined (PARALLAX_MAPPING)
    texCoord = getTexCoordParallax(texCoord, texOffset, uvToView, normalizedViewPos, parallaxScale, parallaxBias, textureAtlasHeight);
#endif
#if defined (NORMAL_MAPPING)
    normalOpaque = getNormalOpaque(uvToView, normal, textureAtlasNormal, texCoord);
    shininess = getShininess(textureAtlasNormal, texCoord);
#endif
#endif



    bool isLava = checkFlag(BLOCK_HINT_LAVA, blockHint);
    bool isGrass = checkFlag(BLOCK_HINT_GRASS, blockHint);
    bool alphaReject = false;
    vec4 color = getColor(time, textureAtlas, textureLava, textureEffects, texCoord, texOffset, alphaReject, isLava, isGrass, glColor, textureOffsetEffects);

    // Calculate daylight lighting value
    float daylightValue = gl_TexCoord[1].x;
    // Calculate blocklight lighting value
    float blocklightValue = gl_TexCoord[1].y;
    // ...and finally the occlusion value
    float occlusionValue = expOccValue(gl_TexCoord[1].z);

    float blocklightColorBrightness = calcBlocklightColorBrightness(blocklightValue
#if defined (FLICKERING_LIGHT)
        , flickeringLightOffset
#endif
    );
    vec3 blocklightColorValue = calcBlocklightColor(blocklightColorBrightness);


    // we need a getter for blocklightColorBrightness, daylightValue, occlusionValue, shininess, normalOpaque
    gl_FragData[2].rgba = vec4(blocklightColorBrightness, daylightValue, 0.0, 0.0);


    gl_FragData[0].rgb = color.rgb;
    // Encode occlusion value into the alpha channel
    gl_FragData[0].a = occlusionValue;
    // Encode shininess value into the normal alpha channel
    gl_FragData[1].a = shininess;

    gl_FragData[1].rgb = vec3(normalOpaque.x / 2.0 + 0.5, normalOpaque.y / 2.0 + 0.5, normalOpaque.z / 2.0 + 0.5);
}
