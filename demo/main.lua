MovieClip = require("lump")

local json = "assets/library.json"
local atlas = "assets/atlas0.png"
local movieClip = nil
local framerate = 60

local sw, sh = love.graphics.getDimensions()
local clips = {"idle", "walk", "attack", "defeat"}
local currentClip = 1

function love.load()
    movieClip = MovieClip.new(json, atlas, framerate)
    movieClip.x, movieClip.y = sw / 2, sh / 2
    movieClip:gotoAndPlay("idle", 1)
end

function love.keypressed(code)
    if (code == "left") then
        currentClip = currentClip > 1 and currentClip - 1 or #clips
        movieClip:gotoAndPlay(clips[currentClip], 1)
    elseif (code == "right") then
        currentClip = currentClip < #clips and currentClip + 1 or 1
        movieClip:gotoAndPlay(clips[currentClip], 1)
    end
end

function love.update(dt)
    movieClip:update(dt)
end

function love.draw()
    movieClip:draw()

    love.graphics.print(clips[currentClip], sw / 2, sh / 2 + 100)
end
