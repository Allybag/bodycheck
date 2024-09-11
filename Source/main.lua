print("Press B to create or remove a barrier")
print("Press A to toggle diagonal moves")

import "CoreLibs/graphics"
import "CoreLibs/object"

local gfx = playdate.graphics
local abs = math.abs

class('Body').extends()

function Body:init(x, y, speed, thickness)
	Body.super.init(self)
	self.x = x
	self.y = y
	self.speed = speed
	self.thickness = thickness
end

local player = Body(16, 6, 0.25, 3)
local enemy = Body(1, 1, 0.25, 1)

class('Grid').extends()
function Grid:init(width, height)
    self.width = width
    self.height = height
    self.grid = {1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
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
    count = 0
    for key, value in pairs(self.grid) do
        count = count + 1
    end

    assert(count == self.width * self.height)
end

grid = Grid(20, 12)

local function drawGrid(grid)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)

    for x = 1, grid.width do
        gfx.drawLine(x * 20, 0, x * 20, grid.height * 20)
    end

    for y = 1, grid.height do
        gfx.drawLine(0, y * 20, grid.width * 20, y * 20)
    end

    for x = 0, grid.width - 1 do
        for y = 0, grid.height - 1 do
            if grid.grid[(y * grid.width) + x + 1] == 0 then
                gfx.fillRect(x * 20, y * 20, 20, 20)
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

local function index(grid, x, y)
    return (y * grid.width) + x - grid.width
end

local function nodeIsActive(grid, x, y)
    return grid.grid[index(grid, x, y)] == 1
end

local function flipGridAt(grid, x, y)
    local gridIndex = index(grid, x, y)
    if grid.grid[gridIndex] == 1 then
        grid.grid[gridIndex] = 0
    else
        grid.grid[gridIndex] = 1
    end
end

local function connectNode(grid, node, x, y, weight)
    if x < 1 or x > grid.width or y < y or y > grid.height or nodeIsActive(grid, x, y) == false then
        return
    end

    node:addConnectionToNodeWithXY(x, y, weight, true)
end

local function flipSelectedSquare(grid, x, y)
    local node = graph:nodeWithXY(x, y)

    if nodeIsActive(grid, x, y) then
        node:removeAllConnections()
    else
        -- add connections to neighbour nodes
        -- weights of 10 for horizontal and 14 for diagonal nodes tends to produce nicer paths than all equal weights
        connectNode(grid, node, x-1, y, 10)
        connectNode(grid, node, x+1, y, 10)
        connectNode(grid, node, x, y-1, 10)
        connectNode(grid, node, x, y+1, 10)
    end

    flipGridAt(grid, x, y)
    -- path = graph:findPath(enemyNode, endNode)
end

function round(float)
    return math.floor(float + 0.5)
end

local function drawBody(body)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(body.thickness)

    gfx.drawRect((body.x - 1) * 20, (body.y - 1) * 20, 21, 21)
end

function kill(grid, body)
    flipSelectedSquare(grid, round(body.x), round(body.y))

    body.x = 1
    body.y = 1
end

function moveIsPossible(grid, targetX, targetY)
    if targetX < 1 or targetY < 1 or targetX > grid.width or targetY > grid.height then
        return false
    end

    if not nodeIsActive(grid, math.floor(targetX), math.floor(targetY)) then
        return false
    elseif not nodeIsActive(grid, math.floor(targetX), math.ceil(targetY)) then
        return false
    elseif not nodeIsActive(grid, math.ceil(targetX), math.floor(targetY)) then
        return false
    elseif not nodeIsActive(grid, math.ceil(targetX), math.ceil(targetY)) then
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

    gfx.drawRect((bullet.x - 1) * 20, (bullet.y - 1) * 20, 3, 3)
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

graph = playdate.pathfinder.graph.new2DGrid(grid.width, grid.height, false, grid.grid)

function playdate.update()
    gfx.clear()

    targetX = player.x
    targetY = player.y

    if playdate.buttonJustReleased(playdate.kButtonB) then
        shoot()
    elseif playdate.buttonIsPressed(playdate.kButtonUp) then
        targetY = player.y - player.speed
        direction = playdate.kButtonUp
    elseif playdate.buttonIsPressed(playdate.kButtonDown) then
        targetY = player.y + player.speed
        direction = playdate.kButtonDown
    elseif playdate.buttonIsPressed(playdate.kButtonRight) then
        targetX = player.x + player.speed
        direction = playdate.kButtonRight
    elseif playdate.buttonIsPressed(playdate.kButtonLeft) then
        targetX = player.x - player.speed
        direction = playdate.kButtonLeft
    end

    if moveIsPossible(grid, targetX, targetY) then
        player.x = targetX
        player.y = targetY
    end

    if bullet ~= nil then
        bullet_speed = player.speed * 4
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

        hit = playdate.geometry.rect.fast_intersection(bullet.x, bullet.y, width, height, enemy.x, enemy.y, 1, 1)
        if hit ~= 0.0 then
            print(hit)
            kill(grid, enemy)
            bullet = nil
        elseif not moveIsPossible(grid, bullet.x, bullet.y) then
            bullet = nil
        end


    end

    drawGrid(grid)

    enemyNode = graph:nodeWithXY(round(enemy.x), round(enemy.y))
    endNode = graph:nodeWithXY(round(player.x), round(player.y))
    path = graph:findPath(enemyNode, endNode, heuristicFunction)
    if path ~= nil then
        local n = path[2]
        if n ~= nil then
            if n.x > enemy.x then
                enemy.x = enemy.x + enemy.speed
            elseif n.x < enemy.x then
                enemy.x = enemy.x - enemy.speed
            elseif n.y > enemy.y then
                enemy.y = enemy.y + enemy.speed
            elseif n.y < enemy.y then
                enemy.y = enemy.y - enemy.speed
            end
        else
            drawGameOver()
        end
    else
        drawGameOver()
    end

    drawBody(player)
    drawBody(enemy)
    playdate.drawFPS()
end
