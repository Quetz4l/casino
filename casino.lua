-- Определение переменных и констант
local component = require("component")
local computer = require("computer")
local sides = require("sides")
local serialization = require("serialization")
local term = require("term")
local gpu = component.gpu

local JSON_LOOT_LIST={}
local CHEST_LOOT_LIST={}
local LOOT_LIST = {}
local Tick = 20

------ change this! ----------
local tr = component.proxy("91003801-3b82-4d87-8a7a-f9a7f9d3bf29") -- change this!
local Settings={
    ["title"] = "Казино",
    ["chestInput"] = sides.bottom,
    ["chestOutput"] = sides.top,
    ["chestTrash"] = sides.west,
    ["chestLoot"] = sides.east,   
}
--------end --------------

local Graphic. = {
    ["screenWidth"], ["screenHeight"] =  gpu.getResolution(),
    ["yCenter"] = Graphic.screenHeight / 2,
    ["xCenter"] = Graphic.screenWidth / 2,
    ["titleCenter"] = Graphic.xCenter - string.len(Settings.title) / 2), 
    ["countOfMenuButtons"] = 0 ,
    ["selectedItem"] = 1,
    ["settingsLine"] = 1,
    ["goBack"] = false,
}

local FileNames = {
    ["oddList"] = "oddList.json",
    ["payList"] = "payList.json",
}

local MenuPages = {
    ["main"] = {
        " Запустить Казино! ",
        " Настройки ",
        " Выход "
    }
}

----------------------------Графика ------------------------
--[[ Почистить экран ]]--
function ClearScreen()
  gpu.setBackground(0x000000)
  gpu.fill(1, 1, Graphic.screenWidth, Graphic.screenHeight, " ")
  gpu.set(Graphic.titleCenter, 2, Settings.title)
end


--[[ Нарисовать текст ]]--
function WriteText(text, color, background, x, y)
    text =tostring(text)
    x = x or math.floor(Graphic.xCenter - string.len(text)/4)
    y = y or math.floor(Graphic.yCenter)
    color = color or 0xFFFFFF
    background = background or 0x000000

    gpu.setBackground(background)
    gpu.setForeground(color)
    gpu.set(x, y, text)
end

function DrawExit(line, x, y) 
    Graphic.countOfMenuButtons = Graphic.countOfMenuButtons+1
    if line == Graphic.selectedItem then
        WriteText(" Выход ", 0xFFFFFF, 0x3366CC, x, y)  
    else
        WriteText(" Выход ", 0xFFFFFF, nil, x, y)   
    end
end

--[[ Слушатель клавишь ]]--
function HandleKeyEvent(key, func)
    if key == 200 and Graphic.selectedItem > 1 then -- стрелка вверх
      Graphic.selectedItem = Graphic.selectedItem - 1
    elseif key == 208 and Graphic.selectedItem < Graphic.countOfMenuButtons then -- стрелка вниз
      Graphic.selectedItem = Graphic.selectedItem + 1
    elseif key == 28 then -- энтер
      func()
    end
  end

--[[ Функция для работы с менюшками ]]--
function DrawMenu(funcMenu, buttons,  funcHandler)
    ClearScreen()
    Graphic.selectedItem= 1
    Graphic.goBack = false

    while ~Graphic.goBack do
        Graphic.countOfMenuButtons = #buttons
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
    if Graphic.selectedItem == 1 then
        GameStart()
    elseif Graphic.selectedItem == 2 then 
        DrawMenu(SettingsDraw, LOOT_LIST,  SettingsMenu)
    elseif Graphic.selectedItem == 3 then
      os.exit()
    end
end

--[[ Нарисовать Главное меню ]]--
function MainDraw(buttons)
  if buttons == nil or #buttons == 0 then return end
  local menuItemY = Graphic.yCenter - #buttons/2

  for i, _text in ipairs(buttons) do
    if i == Graphic.selectedItem then
        WriteText(_text, 0xFFFFFF, 0x3366CC, nil, menuItemY)
    else
        WriteText(_text, 0xFFFFFF, nil, nil, menuItemY)
    end
    menuItemY = menuItemY + 2
  end
end




--[[ Нарисовать меню Настроек ]]--
function SettingsDraw(buttons)
    Graphic.settingsLine = 1
    local buttonY = 4
    local _text

    for fullName, loot in pairs(CHEST_LOOT_LIST) do -- в сундуке
        if LOOT_LIST[fullName] == nil  and (JSON_LOOT_LIST[fullName] == nil or JSON_LOOT_LIST[fullName].odd == 0) then
            _text =  " #".. Graphic.settingsLine.. "  " .."...% ".. loot.label.. " -> ".. fullName .." "

            if  Graphic.settingsLine == Graphic.selectedItem then WriteText(_text, 0xFFFFFF, 0x3366CC, 5, buttonY+ Graphic.settingsLine)   
            else WriteText(_text, 0xFFFFFF, nil, 5, buttonY+ Graphic.settingsLine) end
            
            LOOT_LIST[fullName] = loot
             Graphic.settingsLine =  Graphic.settingsLine + 1
        end
    end

    for fullName, loot in pairs(JSON_LOOT_LIST) do -- В файле
        if LOOT_LIST[fullName] == nil then
            local odd
            if loot.odd == 0 then odd = "..."
            else odd = loot.odd end

            _text =  " #".. Graphic.settingsLine.. "  "..odd .."% ".. loot.label.. " -> ".. fullName .." "
            if  Graphic.settingsLine == Graphic.selectedItem then WriteText(_text, 0xFFFFFF, 0x3366CC, 5, buttonY+ Graphic.settingsLine)   
            else WriteText(_text, 0xFFFFFF, nil, 5, buttonY+ Graphic.settingsLine) end

            LOOT_LIST[fullName] = loot
             Graphic.settingsLine =  Graphic.settingsLine + 1
        end
    end

    Graphic.countOfMenuButtons =  Graphic.settingsLine
    DrawExit( Graphic.settingsLine, 5, buttonY+1)
end


function SettingsMenu()
    if Graphic.selectedItem == Graphic.countOfMenuButtons then  
        MenuBack()  
        return
    else 
        local _text = "Новый шанс: "
        SetNewOdd()
    end
end

function SetNewOdd()
    local _text = TextInput(_text, Graphic.xCenter-string.len(_text)/2 , screenHeight- 5)
    if _text.tointeger() then
        
    end
    ClearScreen()
end

function TextInput(_text, x, y)
    term.setCursor(x,y)
    term.write(_text)
    return term.read()
end

function MenuBack()
    Graphic.goBack = true
    ClearScreen()
    Graphic.selectedItem = 1
end


----------------------------Работа с файлом --------------------------

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

function SaveOdd(fullName, odd)
    JSON_LOOT_LIST[fullName].odd = odd
    SaveToFile(FileNames.oddList, JSON_LOOT_LIST)
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
    or tr.getInventoryName(Settings.chestInput) == nil
    or tr.getInventoryName(Settings.chestOutput) == nil
    or tr.getInventoryName(Settings.chestTrash) == nil
    or tr.getInventoryName(Settings.chestLoot) == nil
    then
        WriteText("Неверно указаны настройки или не хватает сундуков/транспозера!")
        os.exit()
    end
    if inputItem == nil then  SetPay()  end
    --if #odds == 0 then WriteText("Не указаны предметы для выйгрыша")  os.sleep(5) os.exit() end
end



--[[ Сундуки и выбор лута]]--
function getSlotWithItem(side) 
    if slot == nil then
        local all_items = tr.getAllStacks(side).getAll()
        for i, item in pairs(all_items) do
            if item ~=nil then
                return i+1
            end
        end
    end
    return 0 -- chest is empty
end


function getItemFromChest(side, slot) 
    slot = slot or getSlotWithItem(side)
    
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
    local allStacks = tr.getAllStacks(Settings.chestLoot).getAll()
    CHEST_LOOT_LIST = {}

    for i, item in pairs(allStacks) do
        if item.name ~= nil then
            local itemName = item.name .. "/" .. item.damage
            if CHEST_LOOT_LIST[itemName] == nil then
                CHEST_LOOT_LIST[itemName] = {
                    ["slot"] = i+1,
                    ["label"]= item.label,
                    ["count"] = item.size,
                    print( item.label)
                }
            end
        end
    end
    JSON_LOOT_LIST = LoadFile(FileNames.oddList)
end

function putItemFromTo(fromSide, fromSlot, toSide)
    tr.transferItem(fromSide, fromSlot, toSide)
end



function getRandomLoot(payValue)
    local countOfLoots = 0
    local lootList = {}
    for loot in CHEST_LOOT_LIST do
        lootList[countOfLoots] = loot
        countOfLoots = countOfLoots +1
    end
    
    while true do
        local randomItem = lootList[math.random(0,countOfLoots)]
        local odd = JSON_LOOT_LIST[randomItem.fullName]
        
        ClearScreen()
        if odd == nil then 
            WriteText(randomItem.label .. " no has odd! Say to owner", 0x880808)
        elseif odd ~= 0 then
            odd= odd + payValue
            WriteText(odd .." -> "..randomItem.label)
            if odd > math.random(0,100) then
                ClearScreen()
                WriteText(randomItem.label, 0xBF40BF)
                return randomItem
            end
        end
        os.sleep(1)
    end
end


PayList = {
    ["coin.1"] = 1,
    ["coin.2"] = 20,
}

function getPayItem()
    WriteText("Положите плату для лотереи в сундук")
    while true do
        local item = getItemFromChest(Settings.chestInput)
        if item ~= nil then
            return item
        end
        os.sleep(1)
    end
end

local function getPay()
    local item = getPayItem()
    
    for payItem, value in pairs(PayList) do
       if item.fullName == payItem then
            ClearScreen()
            WriteText("В качестве платы was used: " ..item.label.. " -> ".. value)
            os.sleep(2)
            return value
       end           
    end
    putItemFromTo(Settings.chestInput, item.slot, Settings.chestOutput)
    ClearScreen()
    writeText("Pay item didnt recognize")
    os.sleep(3)
    return false
end

--[[ Логика игры]]--
function GameStart()
    Check()
    UpdateLootList()

    while true do
        local payValue = getPay()
        local randomItem = getRandomLoot(payValue)
        putItemFromTo(Settings.chestLoot, randomItem.slot, Settings.chestOutput)
        os.sleep(1)
    end
end

--[[ Главное меню ]]--
while true do
    if Tick % 20 == 0 then
        UpdateLootList()
        term.write('asd')
        os.sleep(1)
    end
    Tick = Tick+1
    DrawMenu(MainDraw, MenuPages["main"],  MainMenu)
end
