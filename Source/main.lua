import "CoreLibs/graphics"
import "CoreLibs/object"

local gfx = playdate.graphics
local abs = math.abs
local didHit = playdate.geometry.rect.fast_intersection

class('Body').extends()
function Body:init(x, y, speed, size, direction, thickness)
	Body.super.init(self)
	self.x = x
	self.y = y
	self.speed = speed
	self.size = size
	self.direction = direction
	self.thickness = thickness
end

class('Grid').extends()
function Grid:init(width, height)
    self.width = width
    self.height = height
    self.grid = {}

    for i = 1, self.width * self.height do
        self.grid[i] = 1
    end

    count = 0
    for key, value in pairs(self.grid) do
        count = count + 1
    end

    assert(count == self.width * self.height)
end

local function drawGridLines(grid)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)

    for x = 1, grid.width do
        gfx.drawLine(x * 20, 0, x * 20, grid.height * 20)
    end

    for y = 1, grid.height do
        gfx.drawLine(0, y * 20, grid.width * 20, y * 20)
    end
end

local function drawGrid(grid)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(1)

    for x = 0, grid.width - 1 do
        for y = 0, grid.height - 1 do
            if grid.grid[(y * grid.width) + x + 1] == 0 then
                gfx.fillRect(x * 20, y * 20, 20, 20)
            end
        end
    end
end

local function drawGameOver(score)
    local errorString = "*Game Over* You scored: " .. tostring(score)
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

local function emptyBorderSquare(grid)
    while true do
        local key = math.random(4)
        local point = playdate.geometry.point.new(0, 0)
        if key == 1 then
            point = playdate.geometry.point.new(1, math.random(grid.height))
        elseif key == 2 then
            point = playdate.geometry.point.new(grid.width, math.random(grid.height))
        elseif key == 3 then
            point = playdate.geometry.point.new(math.random(grid.width), 1)
        elseif key == 4 then
            point = playdate.geometry.point.new(math.random(grid.width), grid.height)
        end

        if nodeIsActive(grid, point.x, point.y) then
            return point
        end
    end
end

local function connectNode(grid, node, x, y, weight)
    if x < 1 or x > grid.width or y < y or y > grid.height or nodeIsActive(grid, x, y) == false then
        return
    end

    node:addConnectionToNodeWithXY(x, y, weight, true)
end

local function flipSelectedSquare(grid, graph, x, y)
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

    gfx.drawRect((body.x - 1) * 20, (body.y - 1) * 20, body.size, body.size)
end

function kill(grid, graph, body)
    flipSelectedSquare(grid, graph, round(body.x), round(body.y))
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

local player = Body(16, 6, 0.25, 21, playdate.kButtonRight, 4)
local enemies = {}
local bullet = nil
local grid = Grid(20, 12)
local framesSinceSpawn = 0
local frameCount = 0
local spawnSpeed = 30
local score = 0
local gameOver = false

local graph = playdate.pathfinder.graph.new2DGrid(grid.width, grid.height, false, grid.grid)

function playdate.update()
    if gameOver then
        drawGameOver(score)
        return
    end

    if framesSinceSpawn == spawnSpeed or next(enemies) == nil then
        local square = emptyBorderSquare(grid)
        print("Spawning enemy on frame ", framesSinceSpawn, " at ", square.x, square.y)
        enemies[frameCount] = Body(square.x, square.y, 0.125, 21, playdate.kButtonRight, 1)
        framesSinceSpawn = 0

        if spawnSpeed > 15 and frameCount % 2 == 0 then
            print("Lowering spawnspeed to ", spawnSpeed)
            spawnSpeed = spawnSpeed - 1
        else
            count = 0
            for key, value in pairs(enemies) do
                count = count + 1
            end
            print("Going mental?, enemies: ", count)
        end
    end
    framesSinceSpawn = framesSinceSpawn + 1
    frameCount = frameCount + 1

    gfx.clear()

    targetX = player.x
    targetY = player.y

    if playdate.buttonJustReleased(playdate.kButtonB) and bullet == nil then
        bullet = Body(player.x, player.y, 1, 3, player.direction, 3)
    elseif playdate.buttonIsPressed(playdate.kButtonUp) then
        targetY = player.y - player.speed
        player.direction = playdate.kButtonUp
    elseif playdate.buttonIsPressed(playdate.kButtonDown) then
        targetY = player.y + player.speed
        player.direction = playdate.kButtonDown
    elseif playdate.buttonIsPressed(playdate.kButtonRight) then
        targetX = player.x + player.speed
        player.direction = playdate.kButtonRight
    elseif playdate.buttonIsPressed(playdate.kButtonLeft) then
        targetX = player.x - player.speed
        player.direction = playdate.kButtonLeft
    end

    if moveIsPossible(grid, targetX, targetY) then
        player.x = targetX
        player.y = targetY
    end

    if bullet ~= nil then
        width = bullet.speed
        height = bullet.speed

        if bullet.direction == playdate.kButtonUp then
            bullet.y = bullet.y - bullet.speed
            height = bullet.speed
        elseif bullet.direction == playdate.kButtonDown then
            bullet.y = bullet.y + bullet.speed
            height = bullet.speed
        elseif bullet.direction == playdate.kButtonRight then
            bullet.x = bullet.x + bullet.speed
            width = bullet.speed
        elseif bullet.direction == playdate.kButtonLeft then
            bullet.x = bullet.x - bullet.speed
            width = bullet.speed
        end

        drawBody(bullet)

        for key, enemy in pairs(enemies) do
            hit = didHit(bullet.x, bullet.y, width, height, enemy.x, enemy.y, 1, 1)
            if hit ~= 0.0 then
                kill(grid, graph, enemy)
                bullet = nil
                enemies[key] = nil
                score = score + 1
                break
            end
        end

        if bullet ~= nil and not moveIsPossible(grid, bullet.x, bullet.y) then
            bullet = nil
        end
    end

    endNode = graph:nodeWithXY(round(player.x), round(player.y))
    for key, enemy in pairs(enemies) do
        enemyNode = graph:nodeWithXY(round(enemy.x), round(enemy.y))
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
                gameOver = true
            end
        end
    end

    drawGrid(grid)
    if false then
        drawGridLines(grid)
    end

    drawBody(player)
    for key, enemy in pairs(enemies) do
        drawBody(enemy)
    end
    playdate.drawFPS()
end
