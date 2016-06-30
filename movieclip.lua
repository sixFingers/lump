local MovieClip = Class{}

function MovieClip:init(animation, framerate)
    self.animation = animation
    self.clip = self:getClip()
    self.currentClipName = self.clip.id

    self.framerate = framerate
    self.currentFrame = 0
    self.paused = true
    self.elapsedTime = 0
    self.duration = self.clip.totalFrames / self.framerate
    self.frameUpdates = {}
    self.keyframeCaches = {}
    self.emittedEvents = {}

    self.x = 0
    self.y = 0
    self.rotation = 0
    self.scaleX = 1
    self.scaleY = 1

    self:gotoAndStop(1)
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
