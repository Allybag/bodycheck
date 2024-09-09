import "CoreLibs/object"
import "CoreLibs/graphics"
import "CoreLibs/sprites"
import "CoreLibs/timer"

local gfx <const> = playdate.graphics

local playerSprite = nil

function myGameSetUp()
    local playerImage = gfx.image.new("Images/playerImage")
    assert(playerImage)

    playerSprite = gfx.sprite.new( playerImage )
    assert(playerSprite)
    playerSprite:moveTo(200, 120) -- center of the screen
    playerSprite:add() -- Apparently critical

    local backgroundImage = gfx.image.new("Images/background")
    assert(backgroundImage)

    gfx.sprite.setBackgroundDrawingCallback(
        function(x, y, width, height)
            backgroundImage:draw(0, 0)
        end
    )
end

myGameSetUp()

-- This function is called right before every frame is drawn
-- This should be where we poll input, run game logic and move sprites
function playdate.update()

    -- We could presumably use elseif to disallow diagonal
    if playdate.buttonIsPressed(playdate.kButtonUp) then
        playerSprite:moveBy(0, -2)
    end
    if playdate.buttonIsPressed(playdate.kButtonRight) then
        playerSprite:moveBy(2, 0)
    end
    if playdate.buttonIsPressed(playdate.kButtonDown) then
        playerSprite:moveBy(0, 2)
    end
    if playdate.buttonIsPressed(playdate.kButtonLeft) then
        playerSprite:moveBy(-2, 0)
    end

    gfx.sprite.update()
    playdate.timer.updateTimers()

end
