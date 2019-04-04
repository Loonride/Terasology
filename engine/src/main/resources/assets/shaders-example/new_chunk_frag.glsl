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
