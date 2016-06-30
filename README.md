# lump
Lump is a [Flump](https://github.com/tconkling/flump) runtime for LÖVE2D.
It allows playing MovieClips exported from Flump through a Flash/Actionscript like API.

Animations exported from Flump are cleverly optimized:

- all of the animation component sprites are packed inside a texture;
- a json file describes clips and frame properties;
- one single animation can hold many different states (idle, walk, ...)
- the memory footprint is generally smaller than that of prerendered sprite animations;
- they're smooooth as flumps.

Lump currently supports all of the features of Flump, _except_ skewing of sprite parts.
See "missing features" below for more info.

## Demo
A simple demo playing Flump's logo animation is available in `/demo`. It requires Love2D 0.10.1

## Dependencies
Lump currently uses [Hump's Class](https://github.com/vrld/hump) and [rxi's JSON](https://github.com/rxi/json.lua). Both of these are soft dependencies you can easily swap with something of your choice.

## Library Structure
Lump splits animation into:

- Animation: this is the definition of the animation, loaded from a JSON file and pointing to a texture
- MovieClip: this is the player for the animation

It was designed this way to allow for multiple movieclips to share the same animation.

## MovieClip API

### Requiring and initializing

```
Class = require("class")
JSON = require("json")
Animation = require("animation")
MovieClip = require("movieclip")

local json = "library.json"
local atlas = "atlas.png"

animation = Animation(json, atlas)
mc = MovieClip(animation, 33) -- loads the given animation, playing it at given framerate
```

After initialization, the movieclip frame pointer is set at the first frame (1) of the first available clip.

### Playing the animation

```
-- in love.update
mc:update(dt)

-- in love.draw
mc:draw()
```

### Playback API
The api tries to mimick the original Flash API:

```
-- go at frame 1 of current clip, or first clip
mc.gotoAndStop(1)

-- stop at frame 1 of clip "walk"
mc.gotoAndStop("walk", 1) 

-- go at frame 1 of current clip, or first clip, then play
mc.gotoAndPlay(1) 

-- play from frame 1 of clip "walk"
mc.gotoAndPlay("walk", 1) 

-- stop / play
mc.stop()
mc.play()
```

### MovieClip frame labels and events

Flump exports Flash frame labels, and the library offers a simple way to hook into the enterframe event.
This way, it's possible to use labeled frames as triggers for actions in your code.
All there is to do is to define `mc.onFrameLabel` function:

```
mc.onFrameLabel = function(label, frame)
```

The function will be called every time a labeled frame is encountered, and will be passed the label and the frame number relative to the current clip. A good example is playing a step sound everytime a character's foot is on ground:

```
mc.onFrameLabel = function(label, frame)
  if (label == "foot_left) then playSound("step_left") end
  if (label == "foot_right) then playSound("step_leftright") end
end
```

### MovieClip transforms and properties

Two properties describe current animation state:

```
mc.currentClipName = "walk"
mc.currentFrame = 1
```

Movieclips supports transforms and uses `love.graphics` matrix internally:

```
-- Move so that the center is at 200, 200
mc.x, mc.y = 200, 200 

-- Rotate
mc.rotation = math.pi / 2

-- Scale
mc.scaleX, mc.scaleY = 2, 2

-- Flip on axis
mc.scaleX, mc.scaleY = -1, 1
```

### Missing features
Currently, Lump misses support for skewing of sprite parts.
This is a somewhat [known issue](https://github.com/tconkling/flump/issues/6), which is easily solvable in other contexts where a typical affine matrix can be created and pushed to the GPU.
Sadly, LOVE2D doesn't allow to build a full transform matrix. It allows to push/pop matrix changes with only a _single_ transformation at a time (scale, rotation, position or scale), but not more. I still can't find a way to express Flash rotation transforms (which are themselves a bit strange) with LOVE's features. If anyone is interested in helping on this, it would be _really_ appreciated.
