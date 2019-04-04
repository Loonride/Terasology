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