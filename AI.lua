local stage = require 'stage'

AI = {
	Konrad = {},
	Jean = {},
	Sun = {},
	Frogson = {}
}

-- angle of attack, expressed as h_vel / v_vel. Lower = steeper angle 
AI.KillAngle = { 
  Konrad = 0.75,
  Jean = 1,
  Sun = 5 / 11,
  FrogsonB = 6 / 11,
  FrogsonJ = 1.5
	}





------------------------------------KONRAD-------------------------------------

-- placeholder function
function AI.Action(player, foe)
	local sendjump = false
	local sendattack = false

  if player.isInAir then
    sendjump, sendattack = AI.Konrad.inAir(player, foe)
  else
    sendjump, sendattack = AI.Konrad.onGround(player, foe)
  end

	return sendjump, sendattack
end

AI.Konrad = {
  -- max height reached = v^2 / 2a (gives pixels above stage floor)
  MAX_JUMP_HEIGHT = 544,
  MAX_SUPERJUMP_HEIGHT = 700,
  MIN_KICK_HEIGHT = stage.floor - 50,

  FAR_JUMP = 0.8,
  FAR_DOUBLEJUMP = 0.2,
  FAR_DOUBLEJUMP_LOWEST = 100,
  FAR_DOUBLEJUMP_HIGHEST = 500,
  
  NEAR_SUPERJUMP = 0.8,

  KILL_SUPERKICK = 0.5,

  HORIZONTAL_CLOSE = 200, -- pixels apart to go for kill

  GoForKill = false,
  DoDoublejump = false,
  DoublejumpHeight = 300
}


function AI.Konrad.inKillRange(player, foe)
  local player_foot = {player.h_mid, player.pos[2] + player.sprite_size[2]}
  local foe_target = {foe.h_mid, foe.pos[2]}

  -- calculate current angle
  local h_dist = math.abs(player_foot[1] - foe_target[1])
  local v_dist = math.abs(player_foot[2] - foe_target[2])
  local angle = h_dist / v_dist

  -- compare angle with kill angle, and check for height
	local killangle = AI.KillAngle.Konrad
  local Konrad_above = player.pos[2] < foe.pos[2]

  return (angle < killangle) and Konrad_above
end

function AI.Konrad.inClose(player, foe)
  -- Konrad's foot  
  local player_foot_h = player.pos[1] + player.sprite_size[1]
  if player.facing == -1 then
    player_foot_h = player.pos[1]
  end

  -- foe's closest side, top of sprite
  local foe_target_h = foe.pos[1]
  if foe.facing == -1 then
    foe_target_h = foe.pos[1] + foe.sprite_size[1]
  end

  local h_distance = math.abs(player_foot_h - foe_target_h)

  return h_distance < AI.Konrad.HORIZONTAL_CLOSE
end

function AI.Konrad.onGround(player, foe)
  local jump = false
  local attack = false

  local near = AI.Konrad.inClose(player, foe)
  local num = math.random()
  
  if near then
    AI.Konrad.GoForKill = true
    if num < AI.Konrad.NEAR_SUPERJUMP then
      jump = true
      attack = true
    else
      jump = true
    end
  else
    AI.Konrad.GoForKill = false
    if num < AI.Konrad.FAR_JUMP then
      jump = true
      if math.random() < AI.Konrad.FAR_DOUBLEJUMP then
        AI.Konrad.DoDoublejump = true
        AI.Konrad.DoublejumpHeight = stage.floor - math.random(AI.Konrad.FAR_DOUBLEJUMP_LOWEST, AI.Konrad.FAR_DOUBLEJUMP_HIGHEST)
      end
    else
      attack = true -- kickback
    end
  end
  return jump, attack
end


function AI.Konrad.inAir(player, foe)
  local jump = false
  local attack = false

  local near = AI.Konrad.inClose(player, foe)
  local kill = AI.Konrad.inKillRange(player, foe)
  local num = math.random()

  if AI.Konrad.GoForKill then
    if kill then
      if player.super >= 16 and num < AI.Konrad.KILL_SUPERKICK then
        jump = true
        attack = true
      else
        attack = true
      end
      AI.Konrad.GoForKill = false
    end
    -- do nothing if not in kill range yet (don't gain meter)
  elseif AI.Konrad.DoDoublejump then
    if kill then
      if player.super >= 16 and num < AI.Konrad.KILL_SUPERKICK then
        jump = true
        attack = true
      else
        attack = true
      end
      AI.Konrad.GoForKill = false
      AI.Konrad.DoDoublejump = false
    elseif player.pos[2] + player.sprite_size[2] < AI.Konrad.DoublejumpHeight then
      jump = true
      AI.Konrad.DoDoublejump = false
    end
    -- don't gain meter if waiting to doublejump
  else
    if player.pos[2] + player.sprite_size[2] < AI.Konrad.MIN_KICK_HEIGHT then
      attack = true
    end

  end

  return jump, attack
end


--Something to check if the opponent is attacking at "will hit me" angle, then kick if so

