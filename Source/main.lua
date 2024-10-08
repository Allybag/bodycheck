import "CoreLibs/graphics"
import "CoreLibs/object"

local gfx = playdate.graphics
local abs = math.abs
local didHit = playdate.geometry.rect.fast_intersection

class('Body').extends()
function Body:init(x, y, speed, size, direction, thickness, image, upImage, downImage)
	Body.super.init(self)
	self.x = x
	self.y = y
	self.speed = speed
	self.size = size
	self.direction = direction
	self.thickness = thickness
	self.image = image
	self.upImage = upImage
	self.downImage= downImage
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
    local errorString = "*Game Over* (Press A to restart) You scored: " .. tostring(score)
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

local function setGridAt(grid, x, y)
    grid.grid[index(grid, x, y)] = 0
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

local function setSelectedSquare(grid, graph, x, y)
    local node = graph:nodeWithXY(x, y)

    if nodeIsActive(grid, x, y) then
        node:removeAllConnections()
        setGridAt(grid, x, y)
    end
end

local function round(float)
    return math.floor(float + 0.5)
end

local function drawBody(body)
    gfx.setColor(gfx.kColorBlack)
    gfx.setLineWidth(body.thickness)

    if body.image ~= nil then
        if body.direction == playdate.kButtonRight then
            body.image:draw((body.x - 1) * 20, (body.y - 1) * 20)
        elseif body.direction == playdate.kButtonLeft then
            body.image:draw((body.x - 1) * 20, (body.y - 1) * 20, gfx.kImageFlippedX)
        elseif body.direction == playdate.kButtonDown then
            body.downImage:draw((body.x - 1) * 20, (body.y - 1) * 20)
        elseif body.direction == playdate.kButtonUp then
            body.upImage:draw((body.x - 1) * 20, (body.y - 1) * 20)
        end
    else
        gfx.drawRect((body.x - 1) * 20, (body.y - 1) * 20, body.size, body.size)
    end
end

local function moveIsPossible(grid, targetX, targetY)
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

-- Pressing a button overrides holding one down
local function getInput(lastButton)
    local inputs = { playdate.kButtonB, playdate.kButtonA, playdate.kButtonUp,
                     playdate.kButtonDown, playdate.kButtonRight, playdate.kButtonLeft }

    for i, input in pairs(inputs) do
        if playdate.buttonJustPressed(input) then
            return input
        end
    end

    if lastButton ~= 0 and playdate.buttonIsPressed(lastButton) then
        return lastButton
    end

    for i, input in pairs(inputs) do
        if playdate.buttonIsPressed(input) then
            return input
        end
    end

    return 0
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

local enemyImage = gfx.image.new("Images/ninja"):scaledImage(1 / 20, 1 / 12)
local playerImage = gfx.image.new("Images/player"):scaledImage(1 / 20, 1 / 12)
local playerUpImage = gfx.image.new("Images/playerUp"):scaledImage(1 / 20, 1 / 12)
local playerDownImage = gfx.image.new("Images/playerDown"):scaledImage(1 / 20, 1 / 12)

local spawnSpeed = 30
local framesSinceSpawn = 0
local framesSinceDeath = 0
local framesTillPathFind = 0
local frameCount = 0
local score = 0
local lastButton = 0
local leapCooldown = 0
local gameOver = false
local bullet = nil
local enemies = {}
local grid = nil
local player = nil
local graph = nil
local endNode = nil

local function setUp()
    spawnSpeed = 30
    framesSinceSpawn = 0
    framesSinceDeath = 0
    framesTillPathFind = 1
    frameCount = 0
    score = 0
    lastButton = 0
    leapCooldown = 0
    gameOver = false
    bullet = nil
    enemies = {}
    grid = Grid(20, 12)
    player = Body(16, 6, 0.25, 21, playdate.kButtonRight, 4, playerImage, playerUpImage, playerDownImage)

    graph = playdate.pathfinder.graph.new2DGrid(grid.width, grid.height, false, grid.grid)
    endNode = graph:nodeWithXY(round(player.x), round(player.y))
end

setUp()

function playdate.update()
    if gameOver then
        drawGameOver(score)
        if framesSinceDeath > 15 and playdate.buttonJustPressed(playdate.kButtonA) then
            setUp()
        end

        framesSinceDeath = framesSinceDeath + 1
        return
    end

    if framesSinceSpawn == spawnSpeed or next(enemies) == nil then
        local square = emptyBorderSquare(grid)
        enemies[frameCount] = Body(square.x, square.y, 0.125, 21, playdate.kButtonRight, 1, enemyImage)
        framesSinceSpawn = 0

        if spawnSpeed > 15 and frameCount % 2 == 0 then
            spawnSpeed = spawnSpeed - 1
        end
    end

    framesSinceSpawn = framesSinceSpawn + 1
    framesTillPathFind = framesTillPathFind - 1
    frameCount = frameCount + 1
    if leapCooldown > 0 then
        leapCooldown = leapCooldown - 1
    end

    gfx.clear()

    targetX = player.x
    targetY = player.y

    input = getInput(lastButton)
    lastButton = input
    if input == playdate.kButtonB and bullet == nil then
        bullet = Body(player.x, player.y, 1, 3, player.direction, 3)
    elseif input == playdate.kButtonA and leapCooldown == 0 then
        leapCooldown = 30
        if player.direction == playdate.kButtonDown then
            targetY = player.y - player.speed * 20
        elseif player.direction == playdate.kButtonUp then
            targetY = player.y + player.speed * 20
        elseif player.direction == playdate.kButtonLeft then
            targetX = player.x + player.speed * 20
        elseif player.direction == playdate.kButtonRight then
            targetX = player.x - player.speed * 20
        end
    elseif input == playdate.kButtonUp then
        targetY = player.y - player.speed
        player.direction = playdate.kButtonUp
    elseif input == playdate.kButtonDown then
        targetY = player.y + player.speed
        player.direction = playdate.kButtonDown
    elseif input == playdate.kButtonRight then
        targetX = player.x + player.speed
        player.direction = playdate.kButtonRight
    elseif input == playdate.kButtonLeft then
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
                setSelectedSquare(grid, graph, round(enemy.x), round(enemy.y))
                bullet = nil
                enemies[key] = nil
                score = score + 1
                framesTillPathFind = 0
                break
            end
        end

        if bullet ~= nil and not moveIsPossible(grid, bullet.x, bullet.y) then
            bullet = nil
        end
    end

    if leapCooldown <= 20 then
        endNode = graph:nodeWithXY(round(player.x), round(player.y))
    end

    for key, enemy in pairs(enemies) do
        if framesTillPathFind == 0 or enemy.path == nil or enemy.path[4] == nil or enemy.path[enemy.next] == nil then
            local enemyNode = graph:nodeWithXY(round(enemy.x), round(enemy.y))
            enemy.path = graph:findPath(enemyNode, endNode, heuristicFunction)
            enemy.next = 2
        end

        if enemy.path ~= nil then
            local next = enemy.path[enemy.next]
            if next ~= nil then
                if next.x > enemy.x then
                    enemy.x = enemy.x + enemy.speed
                    if enemy.x == next.x then
                        enemy.next = enemy.next + 1
                    end
                elseif next.x < enemy.x then
                    enemy.x = enemy.x - enemy.speed
                    if enemy.x == next.x then
                        enemy.next = enemy.next + 1
                    end
                elseif next.y > enemy.y then
                    enemy.y = enemy.y + enemy.speed
                    if enemy.y == next.y then
                        enemy.next = enemy.next + 1
                    end
                elseif next.y < enemy.y then
                    enemy.y = enemy.y - enemy.speed
                    if enemy.y == next.y then
                        enemy.next = enemy.next + 1
                    end
                end
            end
        end

        local hit = didHit(player.x, player.y, 1, 1, enemy.x, enemy.y, 1, 1)
        if hit ~= 0.0 then
            gameOver = true
        end
    end

    if framesTillPathFind == 0 then
        framesTillPathFind = 16
    end

    if false then
        drawGridLines(grid)
    end

    drawBody(player)
    for key, enemy in pairs(enemies) do
        drawBody(enemy)
    end
    drawGrid(grid)
    playdate.drawFPS()
end
