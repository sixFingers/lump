-------------------
--[[JSON parser]]--
-------------------
--
-- json.lua
--
-- Copyright (c) 2015 rxi
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--
local json = { _version = "0.1.0" }
local parse

local function create_set(...)
  local res = {}
  for i = 1, select("#", ...) do
    res[ select(i, ...) ] = true
  end
  return res
end

local space_chars   = create_set(" ", "\t", "\r", "\n")
local delim_chars   = create_set(" ", "\t", "\r", "\n", "]", "}", ",")
local escape_chars  = create_set("\\", "/", '"', "b", "f", "n", "r", "t", "u")
local literals      = create_set("true", "false", "null")

local literal_map = {
  [ "true"  ] = true,
  [ "false" ] = false,
  [ "null"  ] = nil,
}


local function next_char(str, idx, set, negate)
  for i = idx, #str do
    if set[str:sub(i, i)] ~= negate then
      return i
    end
  end
  return #str + 1
end


local function decode_error(str, idx, msg)
  local line_count = 1
  local col_count = 1
  for i = 1, idx - 1 do
    col_count = col_count + 1
    if str:sub(i, i) == "\n" then
      line_count = line_count + 1
      col_count = 1
    end
  end
  error( string.format("%s at line %d col %d", msg, line_count, col_count) )
end


local function codepoint_to_utf8(n)
  -- http://scripts.sil.org/cms/scripts/page.php?site_id=nrsi&id=iws-appendixa
  local f = math.floor
  if n <= 0x7f then
    return string.char(n)
  elseif n <= 0x7ff then
    return string.char(f(n / 64) + 192, n % 64 + 128)
  elseif n <= 0xffff then
    return string.char(f(n / 4096) + 224, f(n % 4096 / 64) + 128, n % 64 + 128)
  elseif n <= 0x10ffff then
    return string.char(f(n / 262144) + 240, f(n % 262144 / 4096) + 128,
                       f(n % 4096 / 64) + 128, n % 64 + 128)
  end
  error( string.format("invalid unicode codepoint '%x'", n) )
end


local function parse_unicode_escape(s)
  local n1 = tonumber( s:sub(3, 6),  16 )
  local n2 = tonumber( s:sub(9, 12), 16 )
  -- Surrogate pair?
  if n2 then
    return codepoint_to_utf8((n1 - 0xd800) * 0x400 + (n2 - 0xdc00) + 0x10000)
  else
    return codepoint_to_utf8(n1)
  end
end


local function parse_string(str, i)
  local has_unicode_escape = false
  local has_surrogate_escape = false
  local has_escape = false
  local last
  for j = i + 1, #str do
    local x = str:byte(j)

    if x < 32 then
      decode_error(str, j, "control character in string")
    end

    if last == 92 then -- "\\" (escape char)
      if x == 117 then -- "u" (unicode escape sequence)
        local hex = str:sub(j + 1, j + 5)
        if not hex:find("%x%x%x%x") then
          decode_error(str, j, "invalid unicode escape in string")
        end
        if hex:find("^[dD][89aAbB]") then
          has_surrogate_escape = true
        else
          has_unicode_escape = true
        end
      else
        local c = string.char(x)
        if not escape_chars[c] then
          decode_error(str, j, "invalid escape char '" .. c .. "' in string")
        end
        has_escape = true
      end
      last = nil

    elseif x == 34 then -- '"' (end of string)
      local s = str:sub(i + 1, j - 1)
      if has_surrogate_escape then
        s = s:gsub("\\u[dD][89aAbB]..\\u....", parse_unicode_escape)
      end
      if has_unicode_escape then
        s = s:gsub("\\u....", parse_unicode_escape)
      end
      if has_escape then
        s = s:gsub("\\.", escape_char_map_inv)
      end
      return s, j + 1

    else
      last = x
    end
  end
  decode_error(str, i, "expected closing quote for string")
end


local function parse_number(str, i)
  local x = next_char(str, i, delim_chars)
  local s = str:sub(i, x - 1)
  local n = tonumber(s)
  if not n then
    decode_error(str, i, "invalid number '" .. s .. "'")
  end
  return n, x
end


local function parse_literal(str, i)
  local x = next_char(str, i, delim_chars)
  local word = str:sub(i, x - 1)
  if not literals[word] then
    decode_error(str, i, "invalid literal '" .. word .. "'")
  end
  return literal_map[word], x
end


local function parse_array(str, i)
  local res = {}
  local n = 1
  i = i + 1
  while 1 do
    local x
    i = next_char(str, i, space_chars, true)
    -- Empty / end of array?
    if str:sub(i, i) == "]" then
      i = i + 1
      break
    end
    -- Read token
    x, i = parse(str, i)
    res[n] = x
    n = n + 1
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "]" then break end
    if chr ~= "," then decode_error(str, i, "expected ']' or ','") end
  end
  return res, i
end


local function parse_object(str, i)
  local res = {}
  i = i + 1
  while 1 do
    local key, val
    i = next_char(str, i, space_chars, true)
    -- Empty / end of object?
    if str:sub(i, i) == "}" then
      i = i + 1
      break
    end
    -- Read key
    if str:sub(i, i) ~= '"' then
      decode_error(str, i, "expected string for key")
    end
    key, i = parse(str, i)
    -- Read ':' delimiter
    i = next_char(str, i, space_chars, true)
    if str:sub(i, i) ~= ":" then
      decode_error(str, i, "expected ':' after key")
    end
    i = next_char(str, i + 1, space_chars, true)
    -- Read value
    val, i = parse(str, i)
    -- Set
    res[key] = val
    -- Next token
    i = next_char(str, i, space_chars, true)
    local chr = str:sub(i, i)
    i = i + 1
    if chr == "}" then break end
    if chr ~= "," then decode_error(str, i, "expected '}' or ','") end
  end
  return res, i
end


local char_func_map = {
  [ '"' ] = parse_string,
  [ "0" ] = parse_number,
  [ "1" ] = parse_number,
  [ "2" ] = parse_number,
  [ "3" ] = parse_number,
  [ "4" ] = parse_number,
  [ "5" ] = parse_number,
  [ "6" ] = parse_number,
  [ "7" ] = parse_number,
  [ "8" ] = parse_number,
  [ "9" ] = parse_number,
  [ "-" ] = parse_number,
  [ "t" ] = parse_literal,
  [ "f" ] = parse_literal,
  [ "n" ] = parse_literal,
  [ "[" ] = parse_array,
  [ "{" ] = parse_object,
}


parse = function(str, idx)
  local chr = str:sub(idx, idx)
  local f = char_func_map[chr]
  if f then
    return f(str, idx)
  end
  decode_error(str, idx, "unexpected character '" .. chr .. "'")
end


function json.decode(str)
  if type(str) ~= "string" then
    error("expected argument of type string, got " .. type(str))
  end
  return ( parse(str, next_char(str, 1, space_chars, true)) )
end

-----------------
--[[Animation]]--
-----------------
local Animation = {}
Animation.__index = Animation

local jsonCache = {}
local textureCache = {}
local animationCache = {}

function Animation.new(jsonPath, texturePath)
    local animation = {}
    setmetatable(animation, Animation)

    local cacheKey = jsonPath .. "." .. texturePath
    if (animationCache[cacheKey]) then
        return animationCache[cacheKey]
    end

    if (not textureCache[texturePath]) then
        local texture = love.graphics.newImage(texturePath)
        textureCache[texturePath] = texture
    end

    animation.texture = textureCache[texturePath]

    if (not jsonCache[jsonPath]) then
        local components, frames = animation:parse(jsonPath, texturePath)
        jsonCache[jsonPath] = {components, frames}
    end

    animation.components, animation.clips = unpack(jsonCache[jsonPath])
    animationCache[cacheKey] = animation

    return animation
end

function Animation:parse(jsonPath, texturePath)
    local content = love.filesystem.read(jsonPath)
    local _json = json.decode(content)

    local atlasDef = _json.textureGroups[1].atlases[1].textures
    local clipDefs = _json.movies
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

-----------------
--[[MovieClip]]--
-----------------
local MovieClip = {}
MovieClip.__index = MovieClip

function MovieClip.new(json, texture, framerate)
    local animation = Animation.new(json, texture)

    local mc = {}
    setmetatable(mc, MovieClip)

    mc.animation = animation
    mc.clip = mc:getClip()
    mc.currentClipName = mc.clip.id

    mc.framerate = framerate
    mc.currentFrame = 0
    mc.paused = true
    mc.elapsedTime = 0
    mc.duration = mc.clip.totalFrames / mc.framerate
    mc.frameUpdates = {}
    mc.keyframeCaches = {}
    mc.emittedEvents = {}

    mc.x = 0
    mc.y = 0
    mc.rotation = 0
    mc.scaleX = 1
    mc.scaleY = 1

    mc:gotoAndStop(1)

    return mc
end

function MovieClip:getClip(clipId)
    for id, clip in pairs(self.animation.clips) do
        if (id == clipId or not clipId) then
            return clip
        end
    end

    return nil
end

function MovieClip:getCurrentFrame()
    local frameTime = self.elapsedTime % self.duration
    local currentFrame = math.min(math.floor(self.clip.totalFrames * frameTime / self.duration), self.clip.totalFrames - 1)

    return currentFrame, frameTime
end

function MovieClip:update(dt)
    if (self.paused) then return end

    self.elapsedTime = self.elapsedTime + dt
    local currentFrame, frameTime = self:getCurrentFrame()

    if (currentFrame >= self.currentFrame) then
        self.emittedEvents = {}
    end

    self.currentFrame = currentFrame + 1
    self.frameUpdates = {}

    for _, layer in ipairs(self.clip.layers) do
        local keyframe = self.animation:getKeyFrame(self.clip.id, layer.name, currentFrame) or self.keyframeCaches[layer.name]

        local component = keyframe.ref

        local x, y = keyframe.x, keyframe.y
        local scaleX, scaleY = keyframe.scaleX, keyframe.scaleY
        local rotation = keyframe.rotation
        local skewX, skewY = keyframe.skewX, keyframe.skewY
        local pivotX, pivotY = keyframe.pivotX, keyframe.pivotY
        local alpha = keyframe.alpha

        local nextFrame = self.animation:getKeyFrameAfter(self.clip.id, layer.name, currentFrame)

        if (nextFrame) then
            self.keyframeCaches[layer.name] = nextFrame
        end

        local isKeyFrame = currentFrame == keyframe.index

        if (not isKeyFrame and nextFrame) then
            local ease, interpolation = keyframe.ease, (currentFrame - keyframe.index) / keyframe.duration

            if (ease ~= 0) then
                local t = 0

                if (ease < 0) then
                    local inv = 1 - interpolation
                    t = 1 - inv * inv
                    ease = -ease
                else
                    t = interpolation * interpolation
                end

                interpolation = ease * t + (1 - ease) * interpolation
            end

            x = x + (nextFrame.x - x) * interpolation
            y = y + (nextFrame.y - y) * interpolation
            scaleX = scaleX + (nextFrame.scaleX - scaleX) * interpolation
            scaleY = scaleY + (nextFrame.scaleY - scaleY) * interpolation
            rotation = rotation + (nextFrame.rotation - rotation) * interpolation
            skewX = skewX + (nextFrame.skewX - skewX) * interpolation
            skewY = skewY + (nextFrame.skewY - skewY) * interpolation
            pivotX = pivotX + (nextFrame.pivotX - pivotX) * interpolation
            pivotY = pivotY + (nextFrame.pivotY - pivotY) * interpolation
        else
            if (isKeyFrame) then
                if (keyframe.label ~= nil and self.onFrameLabel ~= nil and not self.emittedEvents[layer.name]) then
                    self.onFrameLabel(keyframe.label, currentFrame)
                    self.emittedEvents[layer.name] = keyframe.label
                end
            end
        end

        table.insert(self.frameUpdates, {keyframe.ref, x, y, scaleX, scaleY, rotation, skewX, skewY, pivotX, pivotY})
    end
end

function MovieClip:play()
    self.paused = false
end

function MovieClip:stop()
    self.paused = true
end

function MovieClip:gotoAndStop(clipId, frame)
    if (type(clipId) == "number") then
        frame = clipId - 1
        clipId = self.currentClipName
    end

    if (type(clipId) == "string") then
        frame = frame ~= nil and frame or 0
        clipId = clipId
    end

    self.paused = false
    self.clip = self:getClip(clipId)
    self.currentClipName = self.clip.id
    self.elapsedTime = frame * self.duration / self.clip.totalFrames
    self:update(0)
    self.paused = true
end

function MovieClip:gotoAndPlay(clipId, frame)
    self:gotoAndStop(clipId, frame)
    self.paused = false
end

function MovieClip:draw()
    local components = self.animation.components
    local texture = self.animation.texture

    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.rotation)
    love.graphics.scale(self.scaleX, self.scaleY)

    for _, frameValues in ipairs(self.frameUpdates) do
        local component, x, y, scaleX, scaleY, rotation, skewX, skewY, pivotX, pivotY = unpack(frameValues)

        love.graphics.draw(texture, component.quad, x, y, rotation, scaleX, scaleY, pivotX, pivotY)
    end

    love.graphics.pop()
end

return MovieClip
