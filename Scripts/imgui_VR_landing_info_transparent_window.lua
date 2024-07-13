-- Imgui VR Landing Info using imgui
-- William R. Good 07-11-22

if not SUPPORTS_FLOATING_WINDOWS then
    -- to make sure the script doesn't stop old FlyWithLua versions
    logMsg("imgui not supported by your FlyWithLua version")
    return
end


dataref("YokePitch","sim/joystick/yoke_pitch_ratio","readonly")
dataref("Elevator_Trim", "sim/cockpit2/controls/elevator_trim")
dataref("PilotAirSpeed","sim/cockpit2/gauges/indicators/airspeed_kts_pilot","readonly")
dataref("PilotVerticalSpeed","sim/cockpit2/gauges/indicators/vvi_fpm_pilot","readonly")
Throttle = dataref_table("sim/cockpit2/engine/actuators/throttle_ratio")
prop_speed_rpm = dataref_table("sim/cockpit2/engine/indicators/prop_speed_rpm") -- RPM
dataref("ivli_Q", "sim/flightmodel/position/Q", "readonly")
dataref("ivli_Qrad", "sim/flightmodel/position/Qrad", "readonly")
dataref("VR_enabled","sim/graphics/VR/enabled","readonly")
DataRef("sim_time", "sim/network/misc/network_time_sec")

ivli_wnd = nil
VR_enabled_delayed = 0
VR_disabled_delayed = 0
-- local win_width = imgui.GetWindowWidth()
local win_width = 50
-- Variable to hold lines from the file
line = "line 1"
local fileLines = {}
local currentLineIndex = 1

takeoffId = float_wnd_load_image(SCRIPT_DIRECTORY .. "/icons/takeoff.png")
exitId = float_wnd_load_image(SCRIPT_DIRECTORY .. "/icons/exit.png")
landingId = float_wnd_load_image(SCRIPT_DIRECTORY .. "/icons/landing.png")
runway26Id = float_wnd_load_image(SCRIPT_DIRECTORY .. "/icons/runway26.png")
southeastId = float_wnd_load_image(SCRIPT_DIRECTORY .. "/icons/southeast.png")
trafficId = float_wnd_load_image(SCRIPT_DIRECTORY .. "/icons/traffic.png")
climbId = float_wnd_load_image(SCRIPT_DIRECTORY .. "/icons/climb.png")
runwayHeadingId = float_wnd_load_image(SCRIPT_DIRECTORY .. "/icons/runway_heading.png")
turnLeftId = float_wnd_load_image(SCRIPT_DIRECTORY .. "/icons/turn_left.png")


-- print(preradioClip)
local radioClip = load_WAV_file(SYSTEM_DIRECTORY .. "Resources/sounds/alert/test.wav")
local one = load_WAV_file(SYSTEM_DIRECTORY .. "Resources/sounds/alert/1-Uniform,Zulu, Zulu,Waterloo,tower,lineup, runway26.wav")
local two = load_WAV_file(SYSTEM_DIRECTORY .. "Resources/sounds/alert/2- Uniform Zulu, Zulu, climb runway heading on departure, cleared takeoff, Runway 26.wav")
local three = load_WAV_file(SYSTEM_DIRECTORY .. "Resources/sounds/alert/3- Uniform Zulu, Zulu, Left turn southest approved.wav")
local four = load_WAV_file(SYSTEM_DIRECTORY .. "Resources/sounds/alert/4- Uniform Zulu, Zulu, turn downwind now, extend downwind, I'll call your base.wav")
local five = load_WAV_file(SYSTEM_DIRECTORY .. "Resources/sounds/alert/5 - Uniform Zulu, Zulu, traffic 12 o'clock, one mile, northeastbound company Cessna 2100ft.wav")
local fiveb = load_WAV_file(SYSTEM_DIRECTORY .. "Resources/sounds/alert/5B.wav")
local six = load_WAV_file(SYSTEM_DIRECTORY .. "Resources/sounds/alert/6 - Uniform Zulu, Zulu, turn base now.wav")
local seven = load_WAV_file(SYSTEM_DIRECTORY .. "Resources/sounds/alert/7.wav")
local eight = load_WAV_file(SYSTEM_DIRECTORY .."Resources/sounds/alert/8.wav")
local atc_background = load_WAV_file(SYSTEM_DIRECTORY .."Resources/sounds/alert/atc_background.wav")

local audioList = {
    one,
    two,
    three,
    four,
    five,
    fiveb,
    six,
    seven,
    eight
}

-- map to store word : icon Id
local wordIconMap = {
    ["takeoff"] = takeoffId,
    ["exit"] = exitId,
    ["landing"] = landingId,
    ["runway 26"] = runway26Id,
    ["southeast"] = southeastId,
    ["traffic"] = trafficId,
    ["climb"] = climbId,
    ["runway heading"] = runwayHeadingId,
    ["left turn"] = turnLeftId
}

play_sound(atc_background)


----------------------------------------------------------------------------
-- Function to read content from a file and store each line in a table
function readLinesFromFile(filePath)
    local lines = {}
    local file = io.open(filePath, "r") -- Open the file in read mode
    if not file then 
        return nil, "File not found" -- Return nil and an error message if the file doesn't exist
    end

    for line in file:lines() do
        table.insert(lines, line)
    end
    file:close() -- Close the file
    return lines
end


-- return keys ["zulu", "takeoff" ...]
function getKeys(tbl)
    local keys = {}
    for key, _ in pairs(tbl) do
        table.insert(keys, key)
    end
    return keys
end

-- Helper function to split strings by a delimiter (in this case, the keyword)
function splitString(inputStr, delimiter)
    local result = {}
    local from = 1
    local delimFrom, delimTo = string.find(inputStr, delimiter, from, true)
    while delimFrom do
        table.insert(result, string.sub(inputStr, from, delimFrom - 1))
        from = delimTo + 1
        delimFrom, delimTo = string.find(inputStr, delimiter, from, true)
    end
    table.insert(result, string.sub(inputStr, from))
    return result
end


local keywordsList  = {
    "lineup",
    "clear",
    "cleared",
    "climb",
    "northeastbound",
    "#Two",
    "mid",
    "left",
    "downwind",
    "base"
   }

-- function  highlightKeywords(stringtext)
--     -- This function assumes keywords are separated by non-alphanumeric characters
--     -- We'll split the text into words and check each word against the keywords list
--     local words = {}
--     for word in string.gmatch(stringtext, "%S+") do
--         table.insert(words, word)
--     end

--     for i, word in ipairs(words) do
--         local wordLower = word:lower()
--         local isKeyword = false

--         -- Check if the current word is a keyword
--         for _, keyword in ipairs(keywordsList) do
--             if wordLower == keyword:lower() then
--                 isKeyword = true
--                 break
--             end
--         end

--         -- If it is a keyword, apply special styling
--         if isKeyword then
--             imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFFFFF00) -- Highlight color 
--             imgui.TextUnformatted(word)
--             imgui.PopStyleColor()
--         else
--             -- Regular text
--             imgui.TextUnformatted(word)
--         end

--         -- Add spacing between words, but avoid it after the last word
--         if i ~= #words then
--             imgui.SameLine()
--         end
--     end
-- end
function highlightKeywords(stringtext)
    -- Iterate through the text, checking each segment against the keywords list.
    -- This approach uses a pattern to match whole words and numbers, including those with non-alphanumeric characters like decimal points.
    local textPosition = 1
    local textLength = string.len(stringtext)

    while textPosition <= textLength do
        local foundKeyword = false
        for _, keyword in ipairs(keywordsList) do
            local keywordPattern = "%f[%w]" .. keyword .. "%f[%W]"
            local startIdx, endIdx = string.find(stringtext:lower(), keywordPattern, textPosition)

            if startIdx and startIdx == textPosition then -- Match found at the current position
                imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFFFFF00) -- Highlight color in blue
                imgui.TextUnformatted(string.sub(stringtext, startIdx, endIdx))
                imgui.PopStyleColor()

                textPosition = endIdx + 1
                foundKeyword = true
                break -- Break after finding the first matching keyword to avoid overlapping matches
            end
        end

        if not foundKeyword then
            -- No keyword found, print the next character and move on
            local nextSpace = string.find(stringtext, " ", textPosition) or textLength + 1
            -- Handle non-keyword text. Ensure it does not split keywords.
            if nextSpace > textPosition then
                imgui.TextUnformatted(string.sub(stringtext, textPosition, nextSpace - 1))
                textPosition = nextSpace + 1
            else
                -- Single character or end of string, move forward
                textPosition = textPosition + 1
            end

            if textPosition <= textLength then
                imgui.SameLine()
            end
        end
    end
end

function ivli_on_build(ivli_wnd, x, y)
    -- set display configuration
    imgui.SetWindowFontScale(1.5)
    imgui.PushTextWrapPos(imgui.GetFontSize() * 50)

    -- Read all lines from files
	if #fileLines == 0 then
        -- If the file hasn't been read yet, read it
        local filePath = SCRIPT_DIRECTORY .. "my_text_file.txt" -- Adjust this path as needed
        fileLines = readLinesFromFile(filePath)
    end

    if #fileLines > 0 and currentLineIndex <= #fileLines then
        currentLine = fileLines[currentLineIndex]
        local processedLine = currentLine:lower()

        -- Replace the pre-defined words to icons
        for word, iconId in pairs(wordIconMap) do
            local pattern = word:lower() -- Ensure the pattern is lowercase for case-insensitive matching
            local startIdx, endIdx = string.find(processedLine, pattern)

            -- Iterate over all occurrences of the word in the line
            while startIdx do
                -- Text before the matching word
                if startIdx > 1 then
                    local textBefore = currentLine:sub(1, startIdx - 1)
                    imgui.SameLine()
                    -- imgui.TextUnformatted(textBefore)
                    highlightKeywords(textBefore)
                    imgui.SameLine()
                end

                -- Display the image instead of the word
                imgui.SameLine()
                imgui.Image(iconId, 30, 30)
                imgui.SameLine()

                -- Update processedLine to remove the processed part including the matched word
                processedLine = processedLine:sub(endIdx + 1)
                currentLine = currentLine:sub(endIdx + 1)

                -- Look for the next occurrence in the remaining string
                startIdx, endIdx = string.find(processedLine, pattern)
            end
        end

        -- Display any remaining part of the line after the last matched word
        if #currentLine > 0 then
            imgui.SameLine()
            imgui.TextUnformatted(currentLine)
            -- highlightKeywords(currentLine)
        end
    end
end

function check_for_VR()
	if VR_enabled == 1 and VR_enabled_delayed == 1 then
		if ivli_wnd then
			float_wnd_destroy(ivli_wnd)
		end

        -- imgui.SetNextWindowPos(1000, 100, imgui.constant.Cond.FirstUseEver)
        -- float_wnd_set_geometry(ivli_wnd, 400, 500)
		ivli_wnd = float_wnd_create(900, 70, 0, true)
        float_wnd_set_position(ivli_wnd, 800, 600)
		float_wnd_set_title(ivli_wnd, "Imgui Show Landing Info In VR")
		--                                                0x Alphia Red Green Blue
		-- imgui.PushStyleColor(imgui.constant.Col.WindowBg, 0xCC101112) -- Black like Background
		imgui.PushStyleColor(imgui.constant.Col.WindowBg, 0xCC101112) -- Black like Background

		float_wnd_set_imgui_builder(ivli_wnd, "ivli_on_build")
		VR_disabled_delayed = 0
	end
	if VR_enabled == 1 and VR_enabled_delayed < 2 then
		VR_enabled_delayed = VR_enabled_delayed + 1	
	end
	
	if VR_enabled == 0 and VR_disabled_delayed == 1 then
		if ivli_wnd then
			float_wnd_destroy(ivli_wnd)
		end

        -- float_wnd_set_geometry(ivli_wnd, 400,500)
		ivli_wnd = float_wnd_create(1000, 70, 0, true)
        float_wnd_set_position(ivli_wnd, 800, 600)
		float_wnd_set_title(ivli_wnd, "Imgui Show Landing Info In 2d")
		--                                                0x Alphia Red Green Blue
		-- imgui.PushStyleColor(imgui.constant.Col.WindowBg, 0xCC101112) -- Black like Background
		imgui.PushStyleColor(imgui.constant.Col.WindowBg, 0xCC101112) -- Black like Background
        imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFFFFFFF)
		float_wnd_set_imgui_builder(ivli_wnd, "ivli_on_build")
		VR_enabled_delayed = 0
	end
	if VR_enabled == 0 and VR_disabled_delayed < 2 then
		VR_disabled_delayed = VR_disabled_delayed + 1	
	end
    -- play_sound(atc_background)
end



local lastClickTime = 0
local debounceInterval = 0.2 -- 200 milliseconds

function onMouseClick()
    local currentTime = os.clock()
    if currentTime - lastClickTime < debounceInterval then
        return 1 -- Ignore this click
    end
    lastClickTime = currentTime

    if currentLineIndex < #fileLines then
        play_sound(audioList[currentLineIndex])
        currentLineIndex = currentLineIndex + 1
    else
        -- Reset to start over
        currentLineIndex = 1
    end
    print("Mouse clicked. Current line index: " .. currentLineIndex)
    return 1 -- Consume the click event so it doesn't propagate
end



do_often("check_for_VR()")
do_on_mouse_click("onMouseClick()")



     -- Highlight the pre-defined keywords
                    -- local words = {}
                    -- for word in string.gmatch(textBefore, "%S+") do
                    --     table.insert(words, word)
                    -- end
                
                    -- for i, word in ipairs(words) do
                    --     local wordLower = word:lower()
                    --     local isKeyword = false
                    --     print(wordLower)
                    --     -- Check if the current word is a keyword
                    --     for _, keyword in ipairs(keywordsList) do
                    --         if wordLower == keyword:lower() then
                    --             isKeyword = true
                    --             break
                    --         end
                    --     end
                
                    --     -- If it is a keyword, apply special styling
                    --     if isKeyword then  
                    --         imgui.PushStyleColor(imgui.constant.Col.Text, 0xFFFFFF00) -- Highlight color 
                    --         imgui.TextUnformatted(word)
                    --         imgui.PopStyleColor()
                    --     else
                    --         -- Regular text
                    --         imgui.TextUnformatted(word)
                    --     end
                
                    --     -- Add spacing between words, but avoid it after the last word
                    --     if i ~= #words then
                    --         imgui.SameLine()
                    --     end
                    -- end

