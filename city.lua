-----------------------------------------------------------------------------------------
--
-- city.lua
--
-----------------------------------------------------------------------------------------

local composer = require( "composer" )
local Json = require("json")
require( "element" )
local scene = composer.newScene()

local sceneGroup = nil
--------------------------------------------

-- forward declarations and other locals

local screenW, screenH, halfW = display.actualContentWidth, display.actualContentHeight, display.contentCenterX

local city_elements = {}
local cables = nil

local touch_start, touch_end = nil,nil

local touch_last = nil
local touch_path = {}

local clock = os.clock

local tile_size = 0

-- json configuration file
local jsonfile = nil

-- starting amount of money
local money = 0
-- starting points
local points = 0

local cable_cost = 10
local money_text = nil
local points_text = nil
local customer_payment = 10

-- cables definitions
local actual_cable = "white"

local current_lvl = 1

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

function drawCable(cab_id,last_x,last_y,path,elem, start, i_end)
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
    local color = getFieldFromCable(actual_cable,"color")
    new_cable:setStrokeColor(color["r"],color["g"],color["b"],color["a"])
    new_cable.strokeWidth = 4
    cables[cab_id].vis[start] = new_cable
    cables[cab_id].name = actual_cable
    return end_point_x, end_point_y
end

function changeVisCable(cab_id, path)
    local last_x, last_y = nil, nil
    cables[cab_id].vis = {}
    for i,elem in ipairs(path) do
        if i ~= #path then
            last_x, last_y = drawCable(cab_id, last_x, last_y, path, elem, i, i+1)
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

function updateMoneyPointsVisual()
    if money_text then
        money_text:removeSelf()
    end
    money_text = display.newText(money,halfW+60, screenH-60)
    money_text:setFillColor(0,0,0,1)

    if points_text then
        points_text:removeSelf()
    end
    points_text = display.newText(points,halfW-60, screenH-60)
    points_text:setFillColor(0,0,0,1)
end

function refreshScene()
    for i,elem in ipairs(city_elements) do
        elem:addEventListener( "touch", touchlistener )
        elem:addEventListener( "tap", taplistener )
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
    money = money - #touch_path*getFieldFromCable(actual_cable,"cost")
    if money < 0 then
        money = money_old
        return false
    end
    print("Money status after construction", money)
    points = points + getFieldFromCable(actual_cable,"points_init")
    print("Points also need to go up",points)
    checkLevelUp()
    updateMoneyPointsVisual()
    return true
end

function checkLevelUp()
    if current_lvl < 7 then
        threshold = jsonfile["levelingup"][current_lvl+1]
        print("Checking if to level up",current_lvl,points,threshold)
        if points >= threshold then
            print("Level up")
            --TODO cool animation
            current_lvl = current_lvl + 1
            menu_slide_panel()
        end
    end
end

function getFieldFromCable(cabl,field)
    local cables_type = jsonfile["cables"]
    for i,cab in ipairs(cables_type) do
        if cab["name"] == cabl then
            return cab[field]
        end
    end
end

function addPath()
    if discardMoney(touch_path) == true then
        cables[#cables+1] = touch_path
    else
        cleanuppath()
        return
    end
    changeVisCable(#cables,touch_path)
    cleanuppath()

    printAllCables()
end

function checkIfAlreadyHasCable(index, endings)
    for i,cab in ipairs(cables) do
        for j,elem in ipairs(cab) do
            if elem == index then
                if endings == true then
                    if j == 1 or j == #cab then
                        return false
                    else
                        return i
                    end
                else
                    return i
                end
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

function refreshCablesState()
    for i,elem in ipairs(city_elements) do
        elem.street_state = 0
    end
    for i,cab in ipairs(cables) do
        for j,elem in ipairs(cab) do
            city_elements[elem].street_state = 1
        end
    end
end

function taplistener(event)
    if event.numTaps == 2 then
        print("double click")
        printAllCables()
        index = checkIfAlreadyHasCable(event.target.index, true) 
        print(index)
        if index ~= false then
            for _,elem in ipairs(cables[index].vis) do
                print("TOREMOVE", elem,cables[index].name)
                elem:removeSelf()
            end
            -- cables[i] = nil
            table.remove(cables,index)
            printAllCables()
            --TODO consider if want to give back money to player
            refreshCablesState()
        end
    end
end

function touchlistener(event)
    if ( event.phase == "began" ) then
        move_flag = false
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
        move_flag = true
        -- Code executed when the touch is moved over the object
        if touch_start == nil then
            return true
        end
        if event.target.index ~= touch_last then
            -- check the path if already not been here and do not add to path or just stop

            if #touch_path > 1 then
                if city_elements[touch_last].type == 2 or city_elements[touch_last].type == 3 or city_elements[touch_last].type == 5 then
                    -- check if start != stop
                    if city_elements[touch_last].index ~= city_elements[touch_start].index and checkIfAlreadyHasCable(touch_last,false) == false then
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
        print( "touch ended on object ", event.target.type, move_flag)
        if touch_start == nil then
            return true
        end
        if move_flag == false then
            print("clicked, without moving")
            -- return true
        end
        print("deb1",checkIfAlreadyHasCable(toch_last))
        if event.target.type < 1 or event.target.type == 1 or city_elements[touch_last].index == city_elements[touch_start].index
         or checkIfAlreadyHasCable(touch_last,false) ~= false then
            print("deb2",checkIfAlreadyHasCable(toch_last))
            cleanuppath()
            return true
        end
        print("deb3",checkIfAlreadyHasCable(toch_last))
        addPath()
    end
    return true
end

function generateCity(cityjson)

    -- field 1 house 2, bloc 3, street 0, hq 5
    local citymap = cityjson["map"]

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
end

function scene:create( event )
   
    -- first we need variables to store the citymap

    sceneGroup = self.view

	-- local background = display.newRect( display.screenOriginX, display.screenOriginY, screenW, screenH )
	local background = display.newImageRect( "graphics/field.png", screenW, screenH )
	background.anchorX = 0
	background.anchorY = 0
	background.x = 0 + display.screenOriginX 
    background.y = 0 + display.screenOriginY
    
    sceneGroup:insert( background )

    -- bottom rect with actual selected cable
    local actual_cable_button = display.newImageRect( "graphics/button-over.png", 50, 30 )
	actual_cable_button.x = screenW - 30
    actual_cable_button.y = screenH - 60
    actual_cable_button:addEventListener( "touch", enableMenuListener )
    
    sceneGroup:insert( actual_cable_button )
    
    cables = {} -- cable need to have start, end and path, also type

    local file = io.open("C:\\LuaGame\\conf.json", "rb")

    if file then
        -- read all contents of file into a string
        local contents = file:read( "*a" )
        jsonfile = Json.decode(contents);
        io.close( file )
        
        money = jsonfile["init_money"]
        tile_size = jsonfile["init_tile_size"]
        generateCity(jsonfile["init_city"])
        refreshScene()
    end
end

function updateMoneyPointsFromCustomers()
    --money and points depends on cable type
    for i,cabl in ipairs(cables) do
        print("DEBUG",i,cabl,cabl.name)
        if cabl then
            money = money + getFieldFromCable(cabl.name,"payment")
            points = points + getFieldFromCable(cabl.name,"points")
        end
    end

    checkLevelUp()
    print("Money status", money)
    updateMoneyPointsVisual()
    coinAnim()
end

function menu_slide_panel()
    inv_panel.background = display.newRect( 0, 0, inv_panel.width, inv_panel.height )
    inv_panel.background:setFillColor( 0, 0.25, 0.5 )
    inv_panel.background:addEventListener( "touch", menuTouchListener )
    inv_panel:insert( inv_panel.background )

    y_shift = 30
    y = -inv_panel.height/2 + offset
    -- title menu
    inv_panel.title = display.newText( "menu", 0, y, native.systemFontBold, 18 )
    inv_panel.title:setFillColor( 1, 1, 1 )
    inv_panel:insert( inv_panel.title )
    y = y+y_shift

    -- title menu
    inv_panel.remove = display.newText( "Double-click to\n remove cable", 0, y, native.systemFont, 12 )
    inv_panel.remove:setFillColor( 1, 1, 1 )
    inv_panel:insert( inv_panel.remove )
    y = y+y_shift

    --cables
    inv_panel.cables = display.newText( "Cable types", 0, y, native.systemFont, 12 )
    inv_panel.cables:setFillColor( 1, 1, 1 )
    inv_panel:insert( inv_panel.cables )
    y = y+y_shift

    -- go throught conf file and get as many as current level permit
    local cables_type = jsonfile["cables"]
    for i,elem in ipairs(cables_type) do
        if elem["level"] <= current_lvl then
            inv_panel.cable = display.newRect(0,y,20,10)
            inv_panel.cable.name = elem["name"]
            inv_panel.cable:setFillColor(elem["color"]["r"], elem["color"]["g"], elem["color"]["b"],elem["color"]["a"])
            inv_panel.cable:addEventListener( "touch", menuCableTouchListener )
            inv_panel:insert( inv_panel.cable )
            y = y+y_shift
        end
    end
end

function actualCable(name)
    actual_cable = name
    local cable_preview = display.newLine(screenW - 45,screenH - 60,screenW-15,screenH - 60)
    local color = getFieldFromCable(actual_cable,"color")
    cable_preview:setStrokeColor(color["r"],color["g"],color["b"],color["a"])
    cable_preview.strokeWidth = 4
end

function bottom_Panel() 
    actualCable("white")

    points_labal= display.newText("Points:",halfW-120, screenH-60)
    points_labal:setFillColor(0,0,0,1)

    money_labal= display.newText("Money:",halfW, screenH-60)
    money_labal:setFillColor(0,0,0,1)

    updateMoneyPointsVisual()
end

function scene:show( event )
	local sceneGroup = self.view
	local phase = event.phase
	
	if phase == "will" then
		-- Called when the scene is still off screen and is about to move on screen
    elseif phase == "did" then
        bottom_Panel()
        menu_slide_panel()

        timer.performWithDelay(1000*10, updateMoneyPointsFromCustomers, 0)     
        timer.performWithDelay(1000*20, updateCity, 0)
	end
end

function enableMenuListener(event)
    inv_panel:show()
    return true
end

function menuTouchListener(event)
    print("Touched in menu", event.target)
    return true
end

function menuCableTouchListener(event)
    print("Touched cable in menu", event.target.name)
    -- set actual cable
    actualCable(event.target.name)
    inv_panel:hide()
    return true
end

function scene:hide( event )
	local sceneGroup = self.view
	
	local phase = event.phase
	
	if event.phase == "will" then
		-- Called when the scene is on screen and is about to move off screen
		--
		-- INSERT code here to pause the scene
		-- e.g. stop timers, stop animation, unload sounds, etc.)
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
end

---------------------------------------------------------------------------------

-- Listener setup
scene:addEventListener( "create", scene )
scene:addEventListener( "show", scene )
scene:addEventListener( "hide", scene )
scene:addEventListener( "destroy", scene )

-----------------------------------------------------------------------------------------
return scene