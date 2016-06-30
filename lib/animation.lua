local Animation = Class{}

local jsonCache = {}
local textureCache = {}

function Animation:init(jsonPath, texturePath)
    if (not textureCache[texturePath]) then
        local texture = love.graphics.newImage(texturePath)
        textureCache[texturePath] = texture
    end

    self.texture = textureCache[texturePath]

    if (not jsonCache[jsonPath]) then
        local components, frames = self:parse(jsonPath, texturePath)
        jsonCache[jsonPath] = {components, frames}
    end

    self.components, self.clips = unpack(jsonCache[jsonPath])
end

function Animation:parse(jsonPath, texturePath)
    local content = love.filesystem.read(jsonPath)
    local json = JSON.decode(content)

    local atlasDef = json.textureGroups[1].atlases[1].textures
    local clipDefs = json.movies
    local atlas, clips = {}, {}
    local tw, th = self.texture:getDimensions()

    for _, def in ipairs(atlasDef) do
        local ox, oy, x, y, w, h, id = def.origin[1], def.origin[2], def.rect[1], def.rect[2], def.rect[3], def.rect[4], def.symbol
        local quad = love.graphics.newQuad(x, y, w, h, tw, th)
        local component = {x = ox, y = oy, w = w, h = h, quad = quad}
        atlas[id] = component
    end

    for d, def in ipairs(clipDefs) do
        local id, layerDefs = def.id, def.layers
        local layers, totalFrames = {}, 0

        for l, layerDef in ipairs(layerDefs) do
            local name, frameDefs = layerDef.name, layerDef.keyframes
            local frames = {}

            for f, frameDef in ipairs(frameDefs) do
                local ref = atlas[frameDef.ref]

                local skewX, skewY = frameDef.skew and frameDef.skew[1] or 0, frameDef.skew and frameDef.skew[2] or 0

                local frame = {
                    ref = ref,
                    x = frameDef.loc and frameDef.loc[1] or 0,
                    y = frameDef.loc and frameDef.loc[2] or 0,
                    scaleX = frameDef.scale and frameDef.scale[1] or 1,
                    scaleY = frameDef.scale and frameDef.scale[2] or 1,
                    rotation = frameDef.skew and frameDef.skew[1] or 0,
                    skewX = frameDef.skew and frameDef.skew[1] or 0,
                    skewY = frameDef.skew and frameDef.skew[2] or 0,
                    shearX = shearX,
                    shearY = shearY,
                    pivotX = frameDef.pivot and frameDef.pivot[1] or 0,
                    pivotY = frameDef.pivot and frameDef.pivot[2] or 0,
                    alpha = frameDef.alpha and frameDef.alpha or 1,
                    visible = frameDef.visible and frameDef.visible or true,
                    index = frameDef.index,
                    duration = frameDef.duration,
                    tweened = frameDef.tweened and frameDef.tweened or true,
                    ease = frameDef.ease and frameDef.ease or 0,
                    label = frameDef.label and frameDef.label or nil,
                }

                if (l == 1) then
                    totalFrames = totalFrames + frame.duration
                end

                table.insert(frames, frame)
            end

            local layer = {
                name = name,
                frames = frames,
            }

            table.insert(layers, layer)
        end


        local clip = {
            id = id,
            layers = layers,
            totalFrames = totalFrames,
        }

        clips[id] = clip
    end

    return atlas, clips
end

function Animation:getKeyFrame(clipId, layerName, frameIndex)
    local layers = self.clips[clipId].layers

    for l, layer in ipairs(layers) do
        if (layer.name == layerName) then
            for f, frame in ipairs(layer.frames) do
                if (frame.index > frameIndex) then
                    return layer.frames[f - 1]
                end
            end
        end
    end

    return nil, nil
end

function Animation:getKeyFrameAfter(clipId, layerName, frameIndex)
    local layers = self.clips[clipId].layers

    for l, layer in ipairs(layers) do
        if (layer.name == layerName) then
            for f, frame in ipairs(layer.frames) do
                if (frame.index > frameIndex) then
                    return frame
                end
            end
        end
    end

    return nil, nil
end

return Animation
