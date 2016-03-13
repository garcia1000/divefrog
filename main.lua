require 'lovedebug'
require 'utilities' -- helper functions
require 'camera'
local json = require 'dkjson'
local class = require 'middleclass' -- class support
local stage = require 'stage'  -- total playing field area
local window = require 'window'  -- current view of stage
local music = require 'music'
local character = require 'character'
require 'Konrad'
require 'Jean'
require 'Sun'
require 'Frogson'
require 'AI'
local particles = require 'particles'

-- load controls
buttons = {p1jump = 'a', p1attack = 's', p2jump = 'l', p2attack = ';', start = 'return'}

if love.filesystem.exists("controls.txt") then
  local controls_string = love.filesystem.read("controls.txt")
  buttons = json.decode(controls_string)
else
  love.filesystem.write("controls.txt", json.encode(buttons))  
end

-- load settings
settings_options = {Rounds = 3, Timer = 2, Speed = 1, Music = 3, Sound = 3}

if love.filesystem.exists("settings.txt") then
  local settings_string = love.filesystem.read("settings.txt")
  settings_options = json.decode(settings_string)
else
  love.filesystem.write("settings.txt", json.encode(settings_options))  
end

--love.filesystem.createDirectory("saves")

-- load images
local replaysscreen = love.graphics.newImage('images/Replays.jpg')
local charselectscreen = love.graphics.newImage('images/CharSelect.jpg')
local bkmatchend = love.graphics.newImage('images/MatchEndBackground.png')
local hpbar = love.graphics.newImage('images/HPBar.png')
local portraits = love.graphics.newImage('images/Portraits.png')
local greenlight = love.graphics.newImage('images/GreenLight.png')
local portraitsQuad = love.graphics.newQuad(0, 0, 200, 140,portraits:getDimensions())

-- load fonts
local roundStartFont = love.graphics.newFont('/fonts/Comic.otf', 60)
local finalroundStartFont = love.graphics.newFont('/fonts/Comic.otf', 40)
local roundEndFont = love.graphics.newFont('/fonts/ComicItalic.otf', 42)
local charInfoFont = love.graphics.newFont('/fonts/CharSelect.ttf', 21)
local charSelectorFont = love.graphics.newFont('/fonts/GoodDog.otf', 18)
local timerFont = love.graphics.newFont('/fonts/Comic.otf', 40)
local gameoverFont = love.graphics.newFont('/fonts/ComicItalic.otf', 24)
local gameoverHelpFont = love.graphics.newFont('/fonts/ComicItalic.otf', 16)

-- load sounds
super_sfx = "SuperFull.ogg"
charselect_sfx = "CharSelectSFX.ogg"
charselected_sfx = "CharSelectedSFX.ogg"

-- build screen
love.window.setMode(window.width, window.height, { borderless = true })
love.window.setTitle("Divefrog")

-- build canvas layers
canvas_overlays = love.graphics.newCanvas(stage.width, stage.height)
canvas_sprites = love.graphics.newCanvas(stage.width, stage.height)
canvas_background = love.graphics.newCanvas(stage.width, stage.height)

function love.load()
  game = {
    current_screen = "title",
    best_to_x = Params.Rounds,
    speed = Params.Speed,
    current_round = 0,
    match_winner = false,
    superfreeze_time = 0,
    superfreeze_player = nil,
    BGM = nil,
  	background_color = nil,
  	isScreenShaking = false,
  	identical_players = false,
    format = "2P"
    }
  setBGM("Intro.ogg")
  min_dt = 1/60 -- frames per second
  next_time = love.timer.getTime()
  frame = 0 -- framecount
  frame0 = 0 -- timer for start of round fade in
  init_round_timer = Params.Timer * 60 -- round time in frames
  round_timer = init_round_timer
  round_end_frame = 0
  round_ended = false
  keybuffer = {false, false, false, false} -- log of all keystates during the round. Useful for netplay!
  prebuffer = {} -- pre-load draw instruction into future frames behind sprite
  postbuffer = {} -- pre-load draw instructions into future frames over sprite
  soundbuffer = {} -- pre-load sound effects into future frames
  camera_xy = {} -- top left window corner for camera and window drawing
  debug = {boxes = false, sprites = false, midpoints = false, camera = false,	keybuffer = false}
end

function drawBackground()
  love.graphics.clear()
  
  local temp_color = {255, 255, 255, 255}

  if game.background_color then
  	temp_color = game.background_color
  elseif game.superfreeze_time > 0 then
  	temp_color = {96, 96, 96, 255}
  elseif p1.frozenFrames > 0 and p2.frozenFrames > 0 and frame > 90 then
    temp_color = {0, 0, 0, 255}
  end

  love.graphics.push("all")
    love.graphics.setColor(temp_color)
    love.graphics.draw(p2.stage_background, 0, 0) 
  love.graphics.pop()
end

function drawSprites()
  love.graphics.clear()

  --[[----------------------------------------------
                        MID-LINE      
  ----------------------------------------------]]--   
    -- draw if low on time
  if round_timer <= 180 then
    love.graphics.push("all")
      love.graphics.setColor(100 + (180 - round_timer) / 2, 0, 0, 200)
      love.graphics.setLineWidth(12)
      love.graphics.line(stage.center, 0, stage.center, stage.height)

	    if round_timer > 0 then
	    	love.graphics.setLineWidth(1)
	    	local alpha = (180 - round_timer) / 2 + 90
	    	local lines = {
	    		{shift = 2 * round_timer, color = {255, 0, 0, alpha}},
	    		{shift = 4 * round_timer, color = {220, 220, 0, alpha}},
	    		{shift = 6 * round_timer, color = {220, 220, 220, alpha}},
	    		{shift = 12 * round_timer, color = {255, 255, 255, alpha}}
	    		}

	    	for _, line in pairs(lines) do
	    		love.graphics.setColor(line.color)
	    		love.graphics.line(stage.center - line.shift, 0, stage.center - line.shift, stage.height)
	    		love.graphics.line(stage.center + line.shift, 0, stage.center + line.shift, stage.height)
	    	end
	    end
    love.graphics.pop()
  end

  --[[----------------------------------------------
                  UNDER-SPRITE LAYER      
  ----------------------------------------------]]--
  if prebuffer[frame] then
    love.graphics.push("all")
	    for index, _ in pairs(prebuffer[frame]) do
	    	prebuffer[frame][index][12] = prebuffer[frame][index][12] or {255, 255, 255, 255}
	      love.graphics.setColor(prebuffer[frame][index][12]) -- 12 is RGB table
	      love.graphics.draw(unpack(prebuffer[frame][index]))
	    end
    love.graphics.pop()
  end
  prebuffer[frame] = nil
  
  --[[----------------------------------------------
                        SPRITES      
  ----------------------------------------------]]--      
	for side, op in pairs(PLAYERS) do
	  love.graphics.push("all")

			-- Ground shadow for sprites
		  love.graphics.setColor(0, 0, 0, 96)
		  love.graphics.ellipse("fill", side:getCenter(), stage.floor - 5, 50, 20)

		  -- Sprites
		  local temp_color = {255, 255, 255, 255}

		  if side.color then
		  	for i = 1, 4 do temp_color[i] = side.color[i] end
		  end

		  if game.identical_players and side == p2 then
		  	temp_color[1] = temp_color[1] * 0.7
		  	temp_color[2] = temp_color[2] * 0.85
		  	temp_color[3] = temp_color[3] * 0.7
		  end

		  love.graphics.setColor(temp_color)
      
      love.graphics.draw(side.image, side.sprite,
        side.pos[1] + side.h_mid, side.pos[2] + side.v_mid, 0, side.facing, 1, side.h_mid, side.v_mid)

	  love.graphics.pop()
	end

  --[[----------------------------------------------
                  OVER-SPRITE LAYER      
  ----------------------------------------------]]--
  if postbuffer[frame] then
  	love.graphics.push("all")
	    for index, _ in pairs(postbuffer[frame]) do
	    	postbuffer[frame][index][12] = postbuffer[frame][index][12] or {255, 255, 255, 255}
	    	love.graphics.setColor(postbuffer[frame][index][12]) -- 12 is RGB table
	      love.graphics.draw(unpack(postbuffer[frame][index]))
	    end
    love.graphics.pop()
  end
  postbuffer[frame] = nil
end

function drawOverlays()
  love.graphics.clear()
  --[[----------------------------------------------
                       OVERLAYS      
  ----------------------------------------------]]--
    																				test.o0 = love.timer.getTime()
  -- timer
  love.graphics.push("all")
    																				test.timer0 = love.timer.getTime()
  	local displayed_time = math.ceil(round_timer * min_dt)
    																				test.timer1 = love.timer.getTime()
    love.graphics.setColor(230, 147, 5)
    love.graphics.setFont(timerFont)
    																				test.timer2 = love.timer.getTime()
    love.graphics.printf(displayed_time, 0, 6, window.width, "center")
    																				test.timer3 = love.timer.getTime()
  love.graphics.pop()

  for side, op in pairs(PLAYERS) do
  																					test.o1 = love.timer.getTime()
    -- HP bars
    love.graphics.draw(hpbar, window.center + (op.move * 337), 18, 0, op.flip, 1)
  	-- ornament
  	local pos = (frame % 180) * 8
  	if side.life > pos then
  		h_loc = window.center + (op.move * 53) + (op.move * pos)
	    love.graphics.push("all")
    		love.graphics.setColor(255, 255, 255, 128)
    		love.graphics.setLineWidth(1)
    		love.graphics.line(h_loc, 22, h_loc, 44)
    	love.graphics.pop()
    end
    -- life depleted
    if side.life < 280 then
      love.graphics.push("all")
        love.graphics.setColor(220, 0, 0, 255)
        love.graphics.setLineWidth(23)
        love.graphics.line(window.center + (op.move * 333), 34, window.center + (op.move * 333) - op.move * (280 - side.life), 34)
      love.graphics.pop()
    end
  																					test.o2 = love.timer.getTime()
    -- win points
    for i = 1, game.best_to_x do
      if side.score >= i then
        love.graphics.draw(greenlight, window.center + (op.move * 354) - op.move * (20 * i),
        52, 0, 1, 1, op.offset * greenlight:getWidth())
      end
    end
  																					test.o3 = love.timer.getTime()
    -- player icons
    love.graphics.draw(side.icon, window.center + (op.move * 390), 10, 0, op.flip, 1, 0)
  																					test.o4 = love.timer.getTime()
    -- super bars
    love.graphics.push("all")
    if not side.isSupering then
      -- super bar base
      love.graphics.setColor(255, 255, 255, 144)
      love.graphics.draw(SuperBarBase.image, window.center + (op.move * 375), window.height - 35,
				0, 1, 1, op.offset * SuperBarBase.width)
  																					test.o5 = love.timer.getTime()
      -- super meter
      local index = math.floor((frame % 64) / 8)
      local Quad = love.graphics.newQuad(0, index * SuperMeter.height,
      	SuperMeter.width * (side.super / 96),	SuperMeter.height,
      	SuperMeter.image_size[1],	SuperMeter.image_size[2])
      local supermeterColor = {0, 32 + side.super * 2, 0, 255}
	    if side.super >= 32 and side.super < 64 then
	    	supermeterColor = {80 + side.super, 80 + side.super, 160 + side.super, 255}
	    elseif side.super >= 64 then
	    	supermeterColor = {159 + side.super, 159 + side.super, 0, 255}
	    end
      love.graphics.setColor(supermeterColor)
      love.graphics.draw(SuperMeter.image, Quad, window.center + (op.move * 373),
      	window.height - 33, 0, op.flip, 1, 0)
  																					test.o6 = love.timer.getTime()
    else -- if super full, draw frog factor
      local index = math.floor((frame % FrogFactor.total_time) / FrogFactor.time_per_frame)
      local Quad = love.graphics.newQuad(index * FrogFactor.width, 0,
        FrogFactor.width * (side.super / 96), FrogFactor.height,
        FrogFactor.image_size[1], FrogFactor.image_size[2])
      love.graphics.setColor(255, 255, 255, 255)
      love.graphics.draw(FrogFactor.image, Quad, window.center + (op.move * 390),
        window.height - FrogFactor.height - 10, 0, op.flip, 1, 0)
    end
    love.graphics.pop()
      																			test.o7 = love.timer.getTime()
  end

  --[[----------------------------------------------
                OVERLAYS - ROUND START      
  ----------------------------------------------]]--
  local frames_elapsed = frame - frame0
  if frames_elapsed < 60 then
    love.graphics.push("all") 
      love.graphics.setColor(0, 0, 0, 255 - frames_elapsed * 255 / 60)
      love.graphics.rectangle("fill", 0, 0, stage.width, stage.height) 
    love.graphics.pop()
  end
  if frames_elapsed > 48 and frames_elapsed < 90 then
    love.graphics.push("all")
      love.graphics.setFont(roundStartFont)
      love.graphics.setColor(230, 200, 0)
      love.graphics.printf("Round " .. game.current_round, 0, 200, window.width, "center")
      if p1.score == game.best_to_x - 1 and p2.score == game.best_to_x - 1 then
        love.graphics.setFont(finalroundStartFont)
        love.graphics.printf("Final round!", 0, 270, window.width, "center")
      end
    love.graphics.pop()
  end
  																					test.o8 = love.timer.getTime()
  --[[----------------------------------------------
                 OVERLAYS - ROUND END      
  ----------------------------------------------]]--
  if round_end_frame > 0 then
    -- end of round win message
    if frame - round_end_frame > 60 and frame - round_end_frame < 150 then
      love.graphics.push("all")
        love.graphics.setFont(roundEndFont)
        love.graphics.setColor(230, 200, 0)
        if p1.hasWon then love.graphics.printf(p1.fighter_name .. " wins!", 0, 200, window.width, "center")
        elseif p2.hasWon then love.graphics.printf(p2.fighter_name .. " wins!", 0, 200, window.width, "center")
        else love.graphics.printf("Double K.O. !!", 0, 200, window.width, "center")
        end
      love.graphics.pop()
    end
    -- end of round fade out
    if frame - round_end_frame > 120 and frame - round_end_frame < 150 then
      local light = 255 / 30 * (frame - round_end_frame - 120) -- 0 at 120 frames, 255 at 150
      love.graphics.push("all")
        love.graphics.setColor(0, 0, 0, light)
        love.graphics.rectangle("fill", 0, 0, stage.width, stage.height)
      love.graphics.pop()
    end
  end
  																					test.o9 = love.timer.getTime()  
end

function love.draw()
  if game.current_screen == "maingame" then
  																					test.t0 = love.timer.getTime()
    canvas_background:renderTo(drawBackground)
  																					test.t1 = love.timer.getTime()
    canvas_sprites:renderTo(drawSprites)
  																					test.t2 = love.timer.getTime()
    canvas_overlays:renderTo(drawOverlays)
  																					test.t3 = love.timer.getTime()
    camera:scale(1 / camera_scale_factor, 1 / camera_scale_factor)

    camera:set(0.5, 1)
    love.graphics.draw(canvas_background)
    camera:unset()
  																					test.t4 = love.timer.getTime()
    camera:set(1, 1)
    love.graphics.draw(canvas_sprites)
    if debug.boxes then drawDebugHurtboxes() end 
    if debug.sprites then drawDebugSprites() end 
    camera:unset()
  																					test.t5 = love.timer.getTime()
    camera:set(0, 0)
    if game.superfreeze_time == 0 then love.graphics.draw(canvas_overlays) end
    if debug.midpoints then drawMidPoints() end
    camera:unset()      
  																					test.t6 = love.timer.getTime()
    camera:scale(camera_scale_factor, camera_scale_factor)

    if debug.camera then print(unpack(camera_xy)) end
    if debug.keybuffer then print(unpack(keybuffer[frame])) end
  
  elseif game.current_screen == "charselect" then
    love.graphics.draw(charselectscreen, 0, 0, 0) -- background
    love.graphics.draw(portraits, portraitsQuad, 473, 130) -- character portrait
    love.graphics.push("all")
      love.graphics.setColor(0, 0, 0)
      love.graphics.setFont(charInfoFont)
      love.graphics.print(char_text[p1_char][1], 516, 350) -- character movelist
      love.graphics.print(char_text[p1_char][2], 516, 384)
      love.graphics.print(char_text[p1_char][3], 513, 425)
      love.graphics.print(char_text[p1_char][4], 430, 469)
      --p1 rectangle
      love.graphics.setFont(charSelectorFont)
      love.graphics.setLineWidth(2)
      love.graphics.setColor(14, 28, 232)
      love.graphics.print("P1", 42, 20 + (p1_char * 70)) -- helptext
      if frame % 60 < 7 then love.graphics.setColor(164, 164, 255) end -- flashing rectangle
      love.graphics.rectangle("line", 60, 30 + (p1_char * 70), 290, 40)
      
      --p2 rectangle
      love.graphics.setColor(14, 232, 54)
      love.graphics.print("P2", 355, 20 + (p2_char * 70))
      if (frame + 45) % 60 < 7 then love.graphics.setColor(164, 255, 164) end
      love.graphics.rectangle("line", 61, 31 + (p2_char * 70), 289, 39)
    love.graphics.pop()

  elseif game.current_screen == "match_end" then
    love.graphics.draw(bkmatchend, 0, 0) -- background

    love.graphics.push("all")
      love.graphics.setFont(gameoverFont)
      love.graphics.draw(game.match_winner.win_portrait, 100, 50)
      love.graphics.setColor(0, 0, 0)
      love.graphics.printf(game.match_winner.win_quote, 0, 470, window.width, "center")
      love.graphics.setFont(gameoverHelpFont)
      love.graphics.setColor(0, 0, 0, (frame * 2) % 255)
      love.graphics.print("Press enter", 650, 540)
    love.graphics.pop()

    -- fade in for match end
    local fadein = 255 - ((frame - frame0) * 255 / 60)
    if frame - frame0 < 60 then
      love.graphics.push("all") 
        love.graphics.setColor(0, 0, 0, fadein)
        love.graphics.rectangle("fill", 0, 0, stage.width, stage.height) 
      love.graphics.pop()
    end

  elseif game.current_screen == "title" then
  	drawTitle()

 	elseif game.current_screen == "settings" then
 		drawSettingsMain()
 		drawSettingsPopup()

 	elseif game.current_screen == "replays" then
		love.graphics.draw(replaysscreen, 0, 0, 0) 		
  
  end

  local cur_time = love.timer.getTime() -- time after drawing all the stuff

  if cur_time - next_time >= 0 then
    next_time = cur_time -- time needed to sleep until the next frame (?)
  end
    																					test.t7 = love.timer.getTime()
  love.timer.sleep(next_time - cur_time) -- advance time to next frame (?)
    																					test.t8 = love.timer.getTime()
end

function love.update(dt)
  frame = frame + 1
  if game.current_screen == "maingame" then

    if game.superfreeze_time == 0 then
      local h_midpoint = (p1:getCenter() + p2:getCenter()) / 2
      local highest_sprite = math.min(p1.pos[2] + p1.sprite_size[2], p2.pos[2] + p2.sprite_size[2])
      local screen_bottom = stage.height - window.height

      camera_xy = {clamp(h_midpoint - window.center, 0, stage.width - window.width),
        screen_bottom - (stage.floor - highest_sprite) / 8 }

			-- screen shake    	
    	local h_displacement = 0
    	local v_displacement = 0

    	if game.isScreenShaking then
    		h_displacement = (frame % 7 * 6 + frame % 13 * 3 + frame % 23 * 2 - 60) / 2
    		v_displacement = (frame % 5 * 8 + frame % 11 * 3 + frame % 17 * 2 - 30) / 2
    	end
      camera:setPosition(camera_xy[1] + h_displacement, camera_xy[2] - v_displacement)

    -- tweening for scale and camera position
    else
    	camera_xy_temp = camera_xy_temp or camera_xy

      camera_scale_factor = camera_scale_factor * 1.015
      if camera_scale_factor > 2 then camera_scale_factor = 2 end
      
      local h_position = game.superfreeze_player:getCenter() - 0.5 * window.center
      local v_position = game.superfreeze_player.pos[2]
      local h_tween = math.max((h_position + 14 * camera_xy_temp[1]) / 15, 0)
      local v_tween = (v_position + 14 * camera_xy_temp[2]) / 15
      camera:setPosition(h_tween, v_tween)
      camera_xy_temp[1] = h_tween
      camera_xy_temp[2] = v_tween

      game.superfreeze_time = game.superfreeze_time - 1
      if game.superfreeze_time == 0 then
      	camera_xy_temp = nil
      	camera_scale_factor = 1
      end
    end

    if not round_ended and not (p1.frozenFrames > 0 and p2.frozenFrames > 0) then
      round_timer = math.max(round_timer - (1 * game.speed), 0)
    end

    -- get button press state, and write to keybuffer table
    if game.format == "2P" then
      keybuffer[frame] = {
      love.keyboard.isDown(buttons.p1jump),
      love.keyboard.isDown(buttons.p1attack),
      love.keyboard.isDown(buttons.p2jump),
      love.keyboard.isDown(buttons.p2attack)}
    elseif game.format == "1P" then
      local AIjump, AIattack = AI.Action(p2, p1)
      keybuffer[frame] = {
      love.keyboard.isDown(buttons.p1jump),
      love.keyboard.isDown(buttons.p1attack),
      AIjump,
      AIattack}
    elseif game.format == "Netplay1P" then
      keybuffer[frame] = {
      love.keyboard.isDown(buttons.p1jump),
      love.keyboard.isDown(buttons.p1attack),
      love.keyboard.isDown(buttons.p2jump),   -- get netplay data here
      love.keyboard.isDown(buttons.p2attack)} -- get netplay data here
    elseif game.format == "Netplay2P" then
      keybuffer[frame] = {
      love.keyboard.isDown(buttons.p1jump),   -- get netplay data here
      love.keyboard.isDown(buttons.p1attack), -- get netplay data here
      love.keyboard.isDown(buttons.p2jump),   
      love.keyboard.isDown(buttons.p2attack)}
    end


    -- read keystate from keybuffer and call the associated functions
    if not round_ended then
      if keybuffer[frame][1] and p1.frozenFrames == 0 and not keybuffer[frame-1][1] then p1:jump_key_press() end
      if keybuffer[frame][2] and p1.frozenFrames == 0 and not keybuffer[frame-1][2] then p1:attack_key_press() end
      if keybuffer[frame][3] and p2.frozenFrames == 0 and not keybuffer[frame-1][3] then p2:jump_key_press() end
      if keybuffer[frame][4] and p2.frozenFrames == 0 and not keybuffer[frame-1][4] then p2:attack_key_press() end
    end

    -- update character positions
    p1:updatePos()
    p2:updatePos()

    -- check if anyone got hit
    if check_got_hit(p1, p2) and check_got_hit(p2, p1) then
      round_end_frame = frame
      round_ended = true
      p1:gotHit(p2.hit_type)
      p2:gotHit(p1.hit_type)

    elseif check_got_hit(p1, p2) then
      round_end_frame = frame
      round_ended = true
      p1:gotHit(p2.hit_type)
      p2:hitOpponent()

    elseif check_got_hit(p2, p1) then
      round_end_frame = frame
      round_ended = true
      p2:gotHit(p1.hit_type)
      p1:hitOpponent()
    end

    -- check if timeout
    if round_timer == 0 and not round_ended then
      round_end_frame = frame
      round_ended = true
      local p1_from_center = math.abs((stage.center) - p1:getCenter())
      local p2_from_center = math.abs((stage.center) - p2:getCenter())
      if p1_from_center < p2_from_center then
        p2:gotHit(p1.hit_type)
        p1:hitOpponent()
      elseif p2_from_center < p1_from_center then
        p1:gotHit(p2.hit_type)
        p2:hitOpponent()
      else
        p1:gotHit(p2.hit_type)
        p2:gotHit(p1.hit_type)
      end 
    end  

    if soundbuffer[frame] then playSFX(soundbuffer[frame]) end

    -- after round ended and displayed round end stuff, start new round
    if frame - round_end_frame == 144 then
      for p, _ in pairs(PLAYERS) do
        if p.hasWon then p:addScore() end
        if p.score == game.best_to_x then game.match_winner = p end
      end
      
      if not game.match_winner then newRound()
      else -- match end
        frame = 0
        frame0 = 0
        setBGM("GameOver.ogg")
        game.current_screen = "match_end" 
        keybuffer = {}
      end
    end

    -- advance time (?)
    next_time = next_time + min_dt
  end
end

function newRound()

  --Uncomment this for replays later. Too annoying atm sorry
	--local keybuffer_string = json.encode(keybuffer)
	--local filename = "saves/" .. os.date("%m%d%H%M") .. p1_char .. "v" ..
	--	p2_char .. "R" .. game.current_round .. ".txt" -- need to modify this later if 10+ chars
	--love.filesystem.write(filename, keybuffer_string)

  p1:initialize(1, p2, p1.super, p1.hitflag.Mugshot, p1.score)
  p2:initialize(2, p1, p2.super, p2.hitflag.Mugshot, p2.score)

  frame = 0
  frame0 = 0
  round_timer = init_round_timer
  round_ended = false
  round_end_frame = 100000 -- arbitrary number, larger than total round time
  game.current_round = game.current_round + 1
  game.background_color = nil
  game.isScreenShaking = false
  keybuffer = {false, false, false, false}
  prebuffer = {}
  postbuffer = {}
  soundbuffer = {}
	camera_xy_temp = nil
	camera_scale_factor = 1
  if p1.score == game.best_to_x - 1 and p2.score == game.best_to_x - 1 then
    setBGMspeed(2 ^ (4/12))
  end
end

function startGame()
  game.current_screen = "maingame"

  p1 = available_chars[p1_char](1, p2, 0, false, 0)
  p2 = available_chars[p2_char](2, p1, 0, false, 0)
  if p1_char == p2_char then game.identical_players = true end

  PLAYERS = { [p1] = {move = -1, flip = 1, offset = 0},
              [p2] = {move = 1, flip = -1, offset = 1}}
  game.BGM = p2.BGM
  setBGM(game.BGM)
  newRound()
end

function charSelect()
  setBGM("CharSelect.ogg")
  available_chars = {Konrad, Jean, Sun, Frogson}
  char_text = {
    {"Hyper Jump", "Hyper Kick", "+40%", "Double Jump"},
    {"Wire Sea", "Frog On Land", "+20%, Wire Ocean", "Dandy Frog (Wire Sea OK)\n— Pile Bonquer (Wire Sea OK)"},
    {"Hotflame (Wire Sea OK)", "Riot Kick", "Frog Install", "Small Head"},
    {"Anti-Gravity Frog", "Wow!", "+40%", "Jackson/Bison Stances"}
    }
  p1_char = 1
  p2_char = 2
  game.current_screen = "charselect"
end

function select1P()
  game.format="1P"
  charSelect()
end

function select2P()
  game.format="2P"
  charSelect()
end

function replays()
	game.current_screen = "replays"
	--[[
	Scan folder for all valid folders
	Output list of all files to a table -- https://love2d.org/wiki/love.filesystem.getDirectoryItems
	Sort table by filename -- table.sort(table)
	Show all files with 'round 0' as the end part
	Each segment is from 'round 0' until (1 - next 'round 0')

	Operations: select files, or back to main menu
	Select file: play file, delete file
		Play file --
			9th char in string is P1, 11th is P2
			Disable user input
			Allow enter key to popup "return to main menu?" (can continue playing in background for simplicity)
			For i = 1 to #-1: decode .txt into keybuffer
		Delete file -- https://love2d.org/wiki/love.filesystem.remove
	]]
end

test = {}
require 'settings'
require 'title'

function love.keypressed(key)
  if key == "escape" then love.event.quit() end

  if game.current_screen == "title" then
  	if key == buttons.p1attack or key == buttons.start then
  		playSFX(charselected_sfx)
  		title_choices.action[title_choices.option]()
  	
    elseif key == buttons.p1jump or key == "down" then
    	playSFX(charselect_sfx)
    	title_choices.option = title_choices.option % #title_choices.menu + 1

    elseif key == "up" then
      playSFX(charselect_sfx)
      title_choices.option = (title_choices.option - 2) % #title_choices.menu + 1      
    end

  elseif game.current_screen == "charselect" then
    if key == buttons.p1attack or key == buttons.p2attack then
      playSFX(charselected_sfx)
      startGame()
    end

    if key == buttons.p1jump then
    	p1_char = p1_char % #available_chars + 1
      portraitsQuad = love.graphics.newQuad(0, (p1_char - 1) * 140, 200, 140, portraits:getDimensions())
      playSFX(charselect_sfx)
    end

    if key == buttons.p2jump then
    	p2_char = p2_char % #available_chars + 1
      playSFX(charselect_sfx)
    end

  elseif game.current_screen == "settings" then
  	setupReceiveKeypress(key)

  elseif game.current_screen == "replays" then
  	if key == buttons.start then
  		playSFX(charselected_sfx)
  		game.current_screen = "title"
  	end

  elseif game.current_screen == "match_end" then
    if key ==  buttons.start then
      love.load()
      game.current_screen = "title"
    end
  end

  if key == '`' then p1.super = 90 p2.super = 90 end
  if key == '1' then debug.boxes = not debug.boxes end
  if key == '2' then debug.sprites = not debug.sprites end
  if key == '3' then debug.midpoints = not debug.midpoints end
  if key == '4' then debug.camera = not debug.camera end
  if key == '5' then debug.keybuffer = not debug.keybuffer end
  if key == '6' then print(love.filesystem.getSaveDirectory()) end
  if key == '7' then 
  	local output_keybuffer = json.encode(keybuffer)
  	local filename = os.date("%Y.%m.%d.%H%M") .. " Keybuffer.txt"
  	success = love.filesystem.write(filename, output_keybuffer)
  end
  if key == '8' then
  	local calc_background = (test.t1 - test.t0) * 100 / min_dt
  	local calc_sprites = (test.t2 - test.t1) * 100 / min_dt
  	local calc_overlays = (test.t3 - test.t2) * 100 / min_dt
  	local draw_background = (test.t4 - test.t3) * 100 / min_dt
  	local draw_sprites = (test.t5 - test.t4) * 100 / min_dt
  	local draw_overlays = (test.t6 - test.t5) * 100 / min_dt
  	local sleep = (test.t8 - test.t7) * 100 / min_dt
  	print("Calculate background % of CPU:", calc_background)
  	print("Calculate sprites    % of CPU:", calc_sprites)
  	print("Calculate overlays   % of CPU:", calc_overlays)
  	print("Draw background      % of CPU:", draw_background)
  	print("Draw sprites         % of CPU:", draw_sprites)
  	print("Draw overlays        % of CPU:", draw_overlays)
  	print("Sleep:", sleep)
  end
  if key == '9' then
  	local o_timer = (test.o1 - test.o0) * 100 / min_dt
  	local o_hpbar = (test.o2 - test.o1) * 200 / min_dt
  	local o_winpoint = (test.o3 - test.o2) * 200 / min_dt
  	local o_icon = (test.o4 - test.o3) * 200/ min_dt
  	local o_superbase = (test.o5 - test.o4) * 200/ min_dt
  	local o_superquad = (test.o6 - test.o5) * 200/ min_dt
  	local o_frogfactor = (test.o7 - test.o6) * 200/ min_dt
  	local o_roundstart = (test.o8 - test.o7) * 100/ min_dt
  	local o_roundend = (test.o9 - test.o8) * 100/ min_dt
  	print("Calculate timer               % of CPU:", o_timer)
  	print("Calculate HP bars             % of CPU:", o_hpbar)
  	print("Calculate win points          % of CPU:", o_winpoint)
  	print("Calculate icons               % of CPU:", o_icon)
  	print("Calculate super bar base      % of CPU:", o_superbase)
  	print("Calculate super bar quad      % of CPU:", o_superquad)
  	print("Calculate frog factor quad    % of CPU:", o_frogfactor)
  	print("Calculate round start fade in % of CPU:", o_roundstart)
   	print("Calculate round end fade out  % of CPU:", o_roundend)
  end
  if key == '0' then
  	local timer_calc = (test.timer1 - test.timer0) * 100 / min_dt
  	local timer_font = (test.timer2 - test.timer1) * 100 / min_dt  	
  	local timer_print = (test.timer3 - test.timer2) * 100 / min_dt  	  	
  	print("Calculate timer % of CPU:", timer_color)
  	print("Set timer font  % of CPU:", timer_font)
  	print("Print timer     % of CPU:", timer_print)
  end
  if key == '-' then
  	local globaltable = {}
  	local num = 1
  	for k, v in pairs(_G) do
  		globaltable[num] = k
  		num = num + 1
  	end
  	local output_globals = json.encode(globaltable)
  	local filename = os.date("%Y.%m.%d.%H%M") .. " globals.txt"
  	love.filesystem.write(filename, output_globals)
  end
end
