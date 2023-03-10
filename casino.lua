-- Определение переменных и констант
local component = require("component")
local computer = require("computer")
local sides = require("sides")
local serialization = require("serialization")
local term = require("term")
local gpu = component.gpu
local screenWidth, screenHeight = gpu.getResolution()
local yCenter = screenHeight / 2
local xCenter = screenWidth / 2
local countOfMenuButtons
local selectedItem = 1
local writeLine = 1
local JSON_LOOT_LIST={}
local CHEST_LOOT_LIST={}
local LOOT_LIST = {}
local MENU_LIST = {}
local STAY_MENU= true
local Tick = 200
local tr = component.proxy("91003801-3b82-4d87-8a7a-f9a7f9d3bf29")

local chestInput = sides.bottom
local chestOutput = sides.top
local chestTrash = sides.west
local chestLoot = sides.east

--setings menu--
local SETTINGS_LINE

local FILE_WITH_ODDS = "lootList.json"
local title = "Казино"


MenuPages = {["main"] = {
    " Запустить Казино! ",
    " Настройки шансов",
    " Настройки оплаты",
    " Выход "
    }
}


----------------------------Графика ------------------------
--[[ Почистить экран ]]--
function ClearScreen()
  gpu.setBackground(0x000000)
  gpu.fill(1, 1, screenWidth, screenHeight, " ")
  gpu.set(math.floor(xCenter - string.len(title) / 2), 2, title)
end


--[[ Нарисовать текст ]]--
function WriteText(text, color, background, x, y)
    text =tostring(text)
    x = x or math.floor(xCenter - string.len(text)/4)
    y = y or math.floor(yCenter)
    color = color or 0xFFFFFF
    background = background or 0x000000

    gpu.setBackground(background)
    gpu.setForeground(color)
    gpu.set(x, y, text)
    writeLine= writeLine+1
end

function DrawExit(line, x, y) 
    countOfMenuButtons = countOfMenuButtons+1
    if line == selectedItem then
        WriteText(" Выход ", 0xFFFFFF, 0x3366CC, x, y)  
    else
        WriteText(" Выход ", 0xFFFFFF, nil, x, y)   
    end
end

--[[ Слушатель клавишь ]]--
function HandleKeyEvent(key, func)
    if key == 200 and selectedItem > 1 then -- стрелка вверх
      selectedItem = selectedItem - 1
    elseif key == 208 and selectedItem < countOfMenuButtons then -- стрелка вниз
      selectedItem = selectedItem + 1
    elseif key == 28 then -- энтер
      func()
    end
  end

--[[ Функция для работы с менюшками ]]--
function DrawMenu(funcMenu, buttons,  funcHandler)
    ClearScreen()
    selectedItem= 1
    STAY_MENU = true

    while STAY_MENU do
        countOfMenuButtons = #buttons
        funcMenu(buttons)
        local event, _, _, key = computer.pullSignal(0.5)
        if event == "key_down" then
            HandleKeyEvent(key, funcHandler)
        end
    end
    
end

--[[ Логика Главного меню ]]--
function MainMenu()
    ClearScreen()
    if selectedItem == 1 then
        GameStart()
    elseif selectedItem == 2 then 
        DrawMenu(SettingsDraw, LOOT_LIST,  SettingsMenu)
    elseif selectedItem == 3 then
      os.exit()
    end
end

--[[ Рисовка Главного меню ]]--
function MainDraw(buttons)
  if buttons == nil or #buttons == 0 then return end
  local menuItemY = yCenter - #buttons/2

  for i, _text in ipairs(buttons) do
    if i == selectedItem then
        WriteText(_text, 0xFFFFFF, 0x3366CC, nil, menuItemY)
    else
        WriteText(_text, 0xFFFFFF, nil, nil, menuItemY)
    end
    menuItemY = menuItemY + 2
  end
end

--[[ Логика меню Настроек ]]--
function SettingsMenu()
    if selectedItem == countOfMenuButtons then  
        MenuBack()  
        return
    else 
        SetNewOdd()
    end
end

--[[ Рисовка меню Настроек ]]--
function SettingsDraw(buttons)
    ClearScreen()
    SETTINGS_LINE = 1
    local buttonY = 4
    local _text
    Tick = Tick+1

    for fullName, loot in pairs(CHEST_LOOT_LIST) do -- в сундуке
        if JSON_LOOT_LIST[fullName] == nil or JSON_LOOT_LIST[fullName].odd == 0 then
            _text =  " #"..SETTINGS_LINE.. "  " .."...% ".. loot.label.. " -> ".. fullName .." "

            if SETTINGS_LINE == selectedItem then 
                WriteText(_text, 0xFFFFFF, 0x3366CC, 5, buttonY+SETTINGS_LINE)
            else 
                WriteText(_text, 0xFFFFFF, nil, 5, buttonY+SETTINGS_LINE) end
            LOOT_LIST[fullName] = loot
            SETTINGS_LINE = SETTINGS_LINE + 1
            table.insert(MENU_LIST, fullName)
        end
    end

    for fullName, loot in pairs(JSON_LOOT_LIST) do -- В файле
        local odd
        if loot.odd == 0 then odd = "..."
        else odd = loot.odd end

        _text =  " #"..SETTINGS_LINE.. "  "..odd .."% ".. loot.label.. " -> ".. fullName .." "
        if SETTINGS_LINE == selectedItem then 
            WriteText(_text, 0xFFFFFF, 0x3366CC, 5, buttonY+SETTINGS_LINE)
        else 
            WriteText(_text, 0xFFFFFF, nil, 5, buttonY+SETTINGS_LINE) end

        LOOT_LIST[fullName] = loot
        SETTINGS_LINE = SETTINGS_LINE + 1
        table.insert(MENU_LIST, fullName)
    end

    countOfMenuButtons = SETTINGS_LINE -1
    DrawExit(SETTINGS_LINE, 5, buttonY+SETTINGS_LINE+1)

    if Tick >= 200 then
        Tick = 0
        UpdateLootList()
    end
end

function SetNewOdd(show_text)
    show_text = "Новый шанс: "
    local new_odd = tonumber(TextInput(show_text, xCenter- string.len(show_text)/2 , screenHeight- 5))

    if new_odd ~= nil and new_odd<100 and new_odd>=0 then
        local item_index = MENU_LIST[selectedItem]
        if JSON_LOOT_LIST[item_index] == nil then
            JSON_LOOT_LIST[item_index] = {
                ["label"] = CHEST_LOOT_LIST[item_index]["label"]
            }
        end

        JSON_LOOT_LIST[item_index]["odd"] = new_odd
        SaveToFile(FILE_WITH_ODDS, JSON_LOOT_LIST)
    end
    ClearScreen()
end

function TextInput(_text, x, y)
    term.setCursor(x,y)
    term.write(_text)
    return term.read()
end

function MenuBack()
    STAY_MENU = false
    ClearScreen()
    selectedItem = 1
end


----------------------------Работа с файлами --------------------------

function SaveToFile(fileName, array)
    local data = serialization.serialize(JSON_LOOT_LIST)
    local f = io.open(fileName, "w")

    f:write(data)
    f:close()
end

function LoadFile(fileName)
    local f = io.open(fileName, "r")
    if f == nil then return {} end

    local _data = serialization.unserialize(f:read())
    f:close()

    return _data
end

function DeleteFromFile(fileName, array)
    local data = serialization.serialize(array)
    local f = io.open(fileName, "w")

    f:write(data)
    f:close()
end


----------------------------Утилиты и функции ------------------------
--[[ Проверки и настройка ]]--

function Check()
    ClearScreen()
    if tr == nil 
    or tr.getInventoryName(chestInput) == nil
    or tr.getInventoryName(chestOutput) == nil
    or tr.getInventoryName(chestTrash) == nil
    or tr.getInventoryName(chestLoot) == nil
    then
        WriteText("Неверно указаны настройки или не хватает сундуков/транспозера!")
        os.exit()
    end
    if inputItem == nil then  SetPay()  end
    --if #odds == 0 then WriteText("Не указаны предметы для выйгрыша")  os.sleep(5) os.exit() end

    ClearScreen()
end

function SetPay()
    WriteText("Положите плату для лотереи в входной сундук")
    while true do
        local item = getItemFromChest(chestInput, nil)
        if item ~= nil then
            inputItem =item.fullName
            ClearScreen()
            WriteText("В качестве платы установлено: " ..item.label .." ("..inputItem..")")
            os.sleep(4)
            return
        end
        os.sleep(1)
    end
end

--[[ Сундуки и выбор лута]]--
function getSlotWithItem(side, slot) 
    if slot == nil then
        local all_items = tr.getAllStacks(side).getAll()
        for i, item in pairs(all_items) do
            if item ~=nil then
                return i+1
            end
        end
    end
    return 0
end


function getItemFromChest(side, slot) 
    if slot == nil then
        slot = getSlotWithItem(side, slot)
    end
    if slot == 0 then return end 
    local item =  tr.getStackInSlot(side, slot)

    if item == nil then return end

    return {
        ["slot"] = slot,
        ["fullName"] = item.name .. "/"..item.damage,
        ["label"]= item.label,
        ["damage"] = item.damage
    }
end

--Обновляет лутлисты
function UpdateLootList() 
    local allStacks = tr.getAllStacks(chestLoot).getAll()
    CHEST_LOOT_LIST = {}

    for i, item in pairs(allStacks) do
        if item.name ~= nil then
            local itemName = item.name .. "/" .. item.damage
            if CHEST_LOOT_LIST[itemName] == nil then
                CHEST_LOOT_LIST[itemName] = {
                    ["slot"] = i+1,
                    ["label"]= item.label,
                    ["count"] = item.size,
                }                
            end
        end
    end
    JSON_LOOT_LIST = LoadFile(FILE_WITH_ODDS)
end

local function putItemFromTo(fromSide, fromSlot, toSide)
    tr.transferItem(fromSide, fromSlot, toSide)
end



function getRandomLoot()
    if countOfLoots == 0 then return end  -------todo вернуть оплату
    local i = 0
    while true do
        randomItem = math.random(0,countOfLoots)
        for item, odd in pairs(odds) do
            if i == randomItem then
                WriteText(item)
                os.sleep(1)
                if odd < math.random(0,100) then
                    ClearScreen()
                    WriteText(item, 0x925CAF)
                    tr.transferItem(chestLoot, chestOutput, 1, lootList[item].slot)     
                    os.sleep(4)
                    return
                else
                    i=0 
                    break
                end
            end
            i = i+1
        end
    end
end


--[[ Логика игры]]--
function GameStart()
    Check()

    while true do
        --local item = getItemFromChest(chestInput)
        if item == nil then return end
        if item.fullName ~= inputItem then 
            putItemFromTo(chestInput, item.slot, chestOutput)
            WriteText("Неверная оплата") 
        end

        getRandomLoot()
        os.sleep(1)
    end
end

--[[ Главное меню ]]--
while true do
    DrawMenu(MainDraw, MenuPages["main"],  MainMenu)
end
