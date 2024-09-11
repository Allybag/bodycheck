print("Press B to create or remove a barrier")
print("Press A to toggle diagonal moves")

import "CoreLibs/graphics"

local gfx = playdate.graphics
local abs = math.abs

local player = playdate.geometry.point.new(16, 6)
player_speed = 0.25

local w = 20
local h = 12

local grid = {1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
              1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
              0, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
              1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1,
              1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1,
              1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1,
              1, 1, 1, 1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1,
              1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1,
              1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1,
              1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1,
              1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1,
              1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1}

local path, graph, enemyNode, endNode

local function drawGrid()
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)

    for x = 1, w do
        -- gfx.drawLine(x*20, 0, x*20, h*20)
    end

    for y = 1, h do
        -- gfx.drawLine(0, y*20, w*20, y*20)
    end

    for x = 0, w-1 do
        for y = 0, h-1 do
            if grid[((y)*w)+x+1] == 0 then
                gfx.fillRect(x*20, y*20, 20, 20)
            end
        end
    end

end

local function drawGameOver()
    local errorString = "*Game Over*"
    local tw, th = gfx.getTextSize(errorString)
    local bw = tw + 30
    local bh = th + 30
    local dw, dh = playdate.display.getSize()

    gfx.setLineWidth(1)

    gfx.setColor(gfx.kColorBlack)
    gfx.fillRect((dw-bw)/2 + 3, (dh-bh)/2 + 3, bw, bh)

    gfx.setColor(gfx.kColorWhite)
    gfx.drawRect((dw-bw)/2 + 3, (dh-bh)/2 + 3, bw, bh)

    gfx.setColor(gfx.kColorWhite)
    gfx.fillRect((dw-bw)/2, (dh-bh)/2, bw, bh)

    gfx.setLineWidth(2)
    gfx.setColor(gfx.kColorBlack)
    gfx.drawRect((dw-bw)/2, (dh-bh)/2, bw, bh)

    gfx.drawText(errorString, (dw-bw)/2 + 15, (dh-bh)/2 + 15)
end

local function nodeIsActive(x, y)
    local index = (y * w) + x - w
    if grid[index] == 1 then
        return true
    end

    return false
end

local function flipGridAt(x, y)
    local index = ((y-1) * w + x-1) + 1

    if grid[index] == 1 then
        grid[index] = 0
    else
        grid[index] = 1
    end
end

local function connectNode(graph, node, x, y, weight)
    if x < 1 or x > w or y < y or y > h or nodeIsActive(x, y) == false then
        return
    end

    node:addConnectionToNodeWithXY(x, y, weight, true)
end

local function flipSelectedSquare(x, y)
    local node = graph:nodeWithXY(x, y)

    if nodeIsActive(x, y) then
        node:removeAllConnections()
    else
        -- add connections to neighbour nodes
        -- weights of 10 for horizontal and 14 for diagonal nodes tends to produce nicer paths than all equal weights
        connectNode(graph, node, x-1, y, 10)
        connectNode(graph, node, x+1, y, 10)
        connectNode(graph, node, x, y-1, 10)
        connectNode(graph, node, x, y+1, 10)

    end

    flipGridAt(x, y)

    path = graph:findPath(enemyNode, endNode)
end

function round(float)
    return math.floor(float + 0.5)
end

enemy_x = 1
enemy_y = 1
graph = playdate.pathfinder.graph.new2DGrid(w, h, false, grid)

local function drawEnemy()
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)

    gfx.drawRect((enemy_x-1)*20, (enemy_y-1)*20, 21, 21)
end

local function drawCursor()
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(3)

    gfx.drawRect((player.x-1)*20, (player.y-1)*20, 21, 21)
end

function reset()
    flipSelectedSquare(round(enemy_x), round(enemy_y))

    enemy_x = 1
    enemy_y = 1
end

function moveIsPossible(targetX, targetY)
    if targetX < 1 or targetY < 1 or targetX > w or targetY > h then
        return false
    end

    if not nodeIsActive(math.floor(targetX), math.floor(targetY)) then
        return false
    elseif not nodeIsActive(math.floor(targetX), math.ceil(targetY)) then
        return false
    elseif not nodeIsActive(math.ceil(targetX), math.floor(targetY)) then
        return false
    elseif not nodeIsActive(math.ceil(targetX), math.ceil(targetY)) then
        return false
    end

    return true
end

direction = playdate.kButtonRight
bulletDirection = playdate.kButtonRight

bullet = nil
function shoot()
    if bullet ~= nil then
        return
    end

    bullet = playdate.geometry.point.new(player.x, player.y)
    bulletDirection = direction
end

local function drawBullet()
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)

    gfx.drawRect((bullet.x-1)*20, (bullet.y-1)*20, 3, 3)
end


-- Manhattan distance, plus encouragement to line up and be easily shot
local heuristicFunction = function(enemyNode, goalNode)
    result = 0
    if enemyNode.x ~= goalNode.x then
        result = result + 100
    end

    if enemyNode.y ~= goalNode.y then
        result = result + 100
    end

    return result + abs(enemyNode.x - goalNode.x) + abs(enemyNode.y - goalNode.y)
end

function playdate.update()
    gfx.clear()

    targetX = player.x
    targetY = player.y

    if playdate.buttonJustReleased(playdate.kButtonB) then
        shoot()
    elseif playdate.buttonIsPressed(playdate.kButtonUp) then
        targetY = player.y - player_speed
        direction = playdate.kButtonUp
    elseif playdate.buttonIsPressed(playdate.kButtonDown) then
        targetY = player.y + player_speed
        direction = playdate.kButtonDown
    elseif playdate.buttonIsPressed(playdate.kButtonRight) then
        targetX = player.x + player_speed
        direction = playdate.kButtonRight
    elseif playdate.buttonIsPressed(playdate.kButtonLeft) then
        targetX = player.x - player_speed
        direction = playdate.kButtonLeft
    end

    if moveIsPossible(targetX, targetY) then
        player.x = targetX
        player.y = targetY
    end

    if bullet ~= nil then
        bullet_speed = player_speed * 4
        width = bullet_speed
        height = bullet_speed

        if bulletDirection == playdate.kButtonUp then
            bullet.y = bullet.y - bullet_speed
            height = bullet_speed
        elseif bulletDirection == playdate.kButtonDown then
            bullet.y = bullet.y + bullet_speed
            height = bullet_speed
        elseif bulletDirection == playdate.kButtonRight then
            bullet.x = bullet.x + bullet_speed
            width = bullet_speed
        elseif bulletDirection == playdate.kButtonLeft then
            bullet.x = bullet.x - bullet_speed
            width = bullet_speed
        end

        if bullet ~= nil then
            drawBullet()
        end

        hit = playdate.geometry.rect.fast_intersection(bullet.x, bullet.y, width, height, enemy_x, enemy_y, 1, 1)
        if hit ~= 0.0 then
            print(hit)
            reset()
            bullet = nil
        elseif not moveIsPossible(bullet.x, bullet.y) then
            bullet = nil
        end


    end

    drawGrid()

    enemyNode = graph:nodeWithXY(round(enemy_x), round(enemy_y))
    endNode = graph:nodeWithXY(round(player.x), round(player.y))
    path = graph:findPath(enemyNode, endNode, heuristicFunction)
    if path ~= nil then
        local n = path[2]
        if n ~= nil then
            if n.x > enemy_x then
                enemy_x = enemy_x + (player_speed * 1)
            elseif n.x < enemy_x then
                enemy_x = enemy_x - (player_speed * 1)
            elseif n.y > enemy_y then
                enemy_y = enemy_y + (player_speed * 1)
            elseif n.y < enemy_y then
                enemy_y = enemy_y - (player_speed * 1)
            end
        else
            drawGameOver()
        end
    else
        drawGameOver()
    end

    drawCursor()
    drawEnemy()
    playdate.drawFPS()
end
