-----------------------------------------------------------------------------------------
--
-- city.lua
--
-----------------------------------------------------------------------------------------

local composer = require( "composer" )
require( "element" )
local scene = composer.newScene()

local sceneGroup = nil

-- include Corona's "physics" library
local physics = require "physics"

--------------------------------------------

-- forward declarations and other locals
local screenW, screenH, halfW = display.actualContentWidth, display.actualContentHeight, display.contentCenterX

local city_elements = nil
local cables = nil

local touch_start, touch_end = nil,nil

local touch_last = nil
local touch_path = {}

local clock = os.clock

local tile_size = 30

-- starting amount of money
local money = 200
local cable_cost = 10
local money_text = nil
local customer_payment = 10


function updateCity()
    picked = city_elements[ math.random( #city_elements ) ]
    retry_counter = 0
    while picked.type ~= 1 and picked.type ~= 2
    do
        picked = city_elements[ math.random( #city_elements ) ]
        retry_counter = retry_counter + 1
        if retry_counter < 20 then
            return
        end
    end
    print("Picked index",picked,picked.index, picked.type)
    picked.type = picked.type + 1
    if picked.type == 2 then
        picked = swapImage(picked, "graphics/house.png",tile_size,tile_size)
    else
        picked = swapImage(picked, "graphics/bloc.png",tile_size,tile_size)
    end
    refreshScene()
end

function swapImage(oldImage, imageFile, width, height)
    local newImage = display.newImageRect(imageFile, width, height)
    newImage.x = oldImage.x
    newImage.y = oldImage.y
    newImage.type = oldImage.type
    newImage.index = oldImage.index
    newImage.rotation = oldImage.rotation
    oldImage:removeSelf()
    oldImage = nil
    return newImage

end

function drawCable(last_x,last_y,path,elem, start, i_end)
    if last_x == nil or last_y == nil then
        last_x = city_elements[elem].x
        last_y = city_elements[elem].y
    end
    
    len = tile_size
    temp = city_elements[path[i_end]].index - city_elements[path[start]].index
    local new_cable = nil
    local end_point_x = nil
    local end_point_y = nil

    if temp == 1 then
        end_point_x = city_elements[elem].x+len
        end_point_y = city_elements[elem].y
    elseif temp == -1 then
        end_point_x = city_elements[elem].x-len
        end_point_y = city_elements[elem].y
    elseif temp < -1 then
        end_point_x = city_elements[elem].x
        end_point_y = city_elements[elem].y-len
    elseif temp > 1 then
        end_point_x = city_elements[elem].x
        end_point_y = city_elements[elem].y+len
    end

    local new_cable = display.newLine(last_x,last_y,end_point_x,end_point_y)
    new_cable:setStrokeColor(0.1, 0.8, 1,1) -- cyan like
    new_cable.strokeWidth = 4
    return end_point_x, end_point_y
end

function changeVisCable(path)
    local last_x, last_y = nil, nil
    for i,elem in ipairs(path) do
        if i ~= #path then
            last_x, last_y = drawCable(last_x, last_y, path, elem, i, i+1)
            city_elements[elem].street_state = 1
        end
    end
    refreshScene()
end

local function spriteListener(event)
    if event.target.frame == 36 then
        event.target.alpha = 0.01 --hides 
        event.target:removeSelf()
    end
end

function coinAnim()
    -- above each index of customer (end of a cable) do rotating coin for 1 sec
    local sheetData = {
        width = 16,
        height = 16,
        numFrames = 36,
        sheetContentWidth = 576,
        sheetContentHeight = 16,
    }

    local sequenceData = {
        {
            name = "normal", start=1, count=36, time=2400, loopCount=1
        }
    }

    for i,cab in ipairs(cables) do
        last = cab[#cab]

        local money_anim = display.newSprite(graphics.newImageSheet("graphics/coin.png",sheetData), sequenceData)
        money_anim.x = city_elements[last].x
        money_anim.y = city_elements[last].y-tile_size/2
        money_anim:addEventListener("sprite", spriteListener)

        money_anim:play()
    end 
end

function updateMoneyVisual()
    if money_text then
        money_text:removeSelf()
    end
    money_text = display.newText(money,halfW, screenH-60)
    money_text:setFillColor(0,0,0,1)
end

function refreshScene()
    for i,elem in ipairs(city_elements) do
        elem:addEventListener( "touch", touchlistener )
        sceneGroup:insert( elem )
    end
end

function cleanuppath()
    for i,elem in ipairs(touch_path) do
        city_elements[elem].alpha = 1
    end
    if touch_start then
        city_elements[touch_start].alpha = 1
    end
    touch_path = {}
    touch_end = nil
    touch_start = nil
end

function printAllCables()
    for i,cab in ipairs(cables) do
        print("Cable",i,cab)
        for i,elem in ipairs(cab) do
            print("path",i,elem)
        end
    end
end

function discardMoney(touch_path)
    money_old = money
    money = money - #touch_path*cable_cost
    if money < 0 then
        money = money_old
        return false
    end
    print("Money status after construction", money)
    updateMoneyVisual()
    return true
end

function addPath()

    if discardMoney(touch_path) == true then
        cables[#cables+1] = touch_path
    else
        cleanuppath()
        return
    end
    changeVisCable(touch_path)
    cleanuppath()

    printAllCables()
end

function checkIfAlreadyHasCable(index)
    for i,cab in ipairs(cables) do
        for i,elem in ipairs(cab) do
            if elem == index then
                return true
            end
        end
    end
    return false
end

function checkAlreadyBeen(index) 
    for i,elem in ipairs(touch_path) do
        if elem == index then
            return true
        end
    end
    return false
end

function touchlistener(event)
    if ( event.phase == "began" ) then
        -- Code executed when the button is touched
        print( "object touched = ",event.target.x, event.target.y, event.target.type, event.target.street_state) 
        
        if touch_start then
            return
        end

        if event.target.type == 5 then
            touch_start = event.target.index
            touch_last = touch_start
            city_elements[touch_last].alpha = 0.5
            touch_path[#touch_path+1] = touch_last
        elseif event.target.street_state == 1 then
            touch_start = event.target.index
            touch_last = touch_start
            city_elements[touch_last].alpha = 0.5
            touch_path[#touch_path+1] = touch_last
        end

    elseif ( event.phase == "moved" ) then
        -- Code executed when the touch is moved over the object
        if touch_start == nil then
            return true
        end
        if event.target.index ~= touch_last then
            -- TODO check the path if already not been here and do not add to path or just stop

            if #touch_path > 1 then
                if city_elements[touch_last].type == 2 or city_elements[touch_last].type == 3 or city_elements[touch_last].type == 5 then
                    -- check if start != stop
                    if city_elements[touch_last].index ~= city_elements[touch_start].index and checkIfAlreadyHasCable(touch_last) == false then
                        addPath()
                    end
                    return true
                end
            end

            touch_last = event.target.index
            if event.target.type == 1 or checkAlreadyBeen(touch_last) == true then
                cleanuppath()
                return true
            elseif event.target.type == 2 or event.target.type == 3 or event.target.type == 5 then
                print("Get a building, can pass")
            end
            city_elements[touch_last].alpha = 0.5
            touch_path[#touch_path+1] = touch_last
        end

    elseif ( event.phase == "ended" ) then
        -- Code executed when the touch lifts off the object
        print( "touch ended on object ", event.target.type)
        if touch_start == nil then
            return true
        end
        if event.target.type < 1 or event.target.type == 1 or city_elements[touch_last].index == city_elements[touch_start].index
         or checkIfAlreadyHasCable(touch_last) == true then
            cleanuppath()
            return true
        end
        addPath()
    end
    return true
end

function scene:create( event )
   
    -- first we need variables to store the citymap

    sceneGroup = self.view

    -- We need physics started to add bodies, but we don't want the simulaton
	-- running until the scene is on the screen.
	physics.start()
    physics.pause()
    
	-- local background = display.newRect( display.screenOriginX, display.screenOriginY, screenW, screenH )
	local background = display.newImageRect( "graphics/field.png", screenW, screenH )
	background.anchorX = 0
	background.anchorY = 0
	background.x = 0 + display.screenOriginX 
    background.y = 0 + display.screenOriginY
    
    sceneGroup:insert( background )

    system.activate( "multitouch" )
    
    cables = {} -- cable need to have start, end and path, also type

    city_elements = {}
    -- field 1 house 2, bloc 3, street 0, hq 5
    local citymap = {
                     0.1,0,0.1,0,0.1,0,0.1,0,0.1,0,
                     0.2,1,0.2,1,0.2,1,0.2,1,0.2,1,
                     0.1,0,0.1,0,0.1,0,0.1,0,0.1,0,
                     0.2,1,0.2,1,0.2,1,0.2,1,0.2,1,
                     0.1,0,0.1,0,0.1,0,0.1,0,0.1,0,
                     0.2,1,0.2,1,0.2,1,0.2,1,0.2,1,
                     0.1,0,0.1,0,0.1,0,0.1,0,0.1,0,
                     0.2,1,0.2,2,0.2,1,0.2,3,0.2,1,
                     0.1,0,0.1,0,0.1,0,0.1,0,0.1,0,
                     0.2,1,0.2,2,0.2,5,0.2,1,0.2,1,
                     0.1,0,0.1,0,0.1,0,0.1,0,0.1,0,
                     0.2,2,0.2,1,0.2,1,0.2,2,0.2,1,
                     0.1,0,0.1,0,0.1,0,0.1,0,0.1,0,
                     0.2,1,0.2,1,0.2,1,0.2,1,0.2,1,
                     0.1,0,0.1,0,0.1,0,0.1,0,0.1,0,
                     0.2,1,0.2,1,0.2,1,0.2,1,0.2,1,
                     0.1,0,0.1,0,0.1,0,0.1,0,0.1,0,
                    }

    offset = 25
    curr_x, curr_y = offset, 0
    iter = tile_size;
    for i,elem in ipairs(citymap) do
        vert = 0
        if elem == 0 then
            temp = "graphics/street.png"
        elseif elem == 0.1 then
            temp = "graphics/street_clear.png"
        elseif elem == 0.2 then
            temp = "graphics/street.png"
            vert = 90
        elseif elem == 1 then
            temp = "graphics/field.png"
        elseif elem == 2 then
            temp = "graphics/house.png"
        elseif elem == 3 then
            temp = "graphics/bloc.png"
        elseif elem == 5 then
            temp = "graphics/hq.png"
        end

        local element = display.newImageRect( temp, tile_size, tile_size )
        element.x, element.y = curr_x, curr_y
        element.type = elem
        element.index = i
        element.rotation= vert

        city_elements[#city_elements+1] = element

        curr_x = curr_x + iter
        if curr_x >= screenW then
            curr_x = offset
            curr_y = curr_y + iter
        end
    end

    refreshScene(sceneGroup)
end

function updateMoneyFromCustomers()
    -- TODO check customers count and add theirs money
    -- TO CHANGE for now customers there will be number of cables
    money = money + #cables*customer_payment
    print("Money status", money)
    updateMoneyVisual()
    coinAnim()
end

function scene:show( event )
	local sceneGroup = self.view
	local phase = event.phase
	
	if phase == "will" then
		-- Called when the scene is still off screen and is about to move on screen
	elseif phase == "did" then
        updateMoneyVisual()

        timer.performWithDelay(1000*10, updateMoneyFromCustomers, 0)

        
        timer.performWithDelay(1000*20, updateCity, 0)

		physics.start()
	end
end

function scene:hide( event )
	local sceneGroup = self.view
	
	local phase = event.phase
	
	if event.phase == "will" then
		-- Called when the scene is on screen and is about to move off screen
		--
		-- INSERT code here to pause the scene
		-- e.g. stop timers, stop animation, unload sounds, etc.)
		physics.stop()
	elseif phase == "did" then
		-- Called when the scene is now off screen
	end	
	
end

function scene:destroy( event )

	-- Called prior to the removal of scene's "view" (sceneGroup)
	-- 
	-- INSERT code here to cleanup the scene
	-- e.g. remove display objects, remove touch listeners, save state, etc.
	local sceneGroup = self.view
	
	package.loaded[physics] = nil
	physics = nil
end

---------------------------------------------------------------------------------

-- Listener setup
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

-----------------------------------------------------------------------------------------
return scene