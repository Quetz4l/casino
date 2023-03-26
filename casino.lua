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
local selectedItem
local writeLine = 1
local CountOfLoots
local JSON_LOOT_LIST={}
local JSON_PAY_LIST={}
local CHEST_LOOT_LIST={}
local LOOT_LIST ={}
local ButtonIndex = {}
local STAY_MENU= true
local PaySlot
local Tick = 200
local tr = component.proxy("91003801-3b82-4d87-8a7a-f9a7f9d3bf29")

local chestInput = sides.bottom
local chestOutput = sides.top
local chestTrash = sides.west
local chestLoot = sides.east



local FILE_WITH_ODDS = "lootList.json"
local FILE_WITH_PAY = "payList.json"
local title = "Казино"


Menus = {
    ["main"] = {
        [1] = " Запустить Казино! ",
        [2] = " Настройки шансов ",
        [3] = " Настройки оплаты ",
        [4] = " Выход ",
        ["count"] = 4,
    }
}

Graphic = {
    ["SelectedBackground"] = 0x3366CC
}


----------------------------Графика и пспомогательное ------------------------
--[[ Почистить экран ]]--
function ClearScreen()
  gpu.setBackground(0x000000)
  gpu.fill(1, 1, screenWidth, screenHeight, " ")
  gpu.set(math.floor(xCenter-2), 2, title)
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
    if line == selectedItem then
        WriteText(" Выход ", 0xFFFFFF, 0x3366CC, x, y)  
    else
        WriteText(" Выход ", 0xFFFFFF, nil, x, y)   
    end
end

--[[ Слушатель клавишь ]]--
function HandleKeyEvent(key, func, buttons)   
    if key == 200 and selectedItem > 0 then -- стрелка вверх
      selectedItem = selectedItem - 1
    elseif key == 208 and selectedItem < countOfMenuButtons then -- стрелка вниз
      selectedItem = selectedItem + 1
    elseif key == 28 then -- энтер
      func(buttons)
    end
end

--[[ Функция для работы с менюшками ]]--
function DrawMenu(funcMenu, buttons,  funcHandler)
    ClearScreen()
    selectedItem= 1
    STAY_MENU = true -- todo fix name
    while STAY_MENU do
        funcMenu(buttons)
        local event, _, _, key = computer.pullSignal(0.5)
        if event == "key_down" then
            HandleKeyEvent(key, funcHandler, buttons)
        end
    end
end




----------------Логика менюшек-----------------------
--[[ Логика Главного меню ]]--
function MainMenu(buttons)
    if buttons[selectedItem] == " Запустить Казино! " then
        GameStart()
    elseif buttons[selectedItem] == " Настройки шансов " then
        UpdateLootList()
        DrawMenu(DrawOddSetings, LOOT_LIST,  SettingsMenu)
    elseif buttons[selectedItem] == " Настройки оплаты " then
        UpdatePayList()
        DrawMenu(DrawOddSetingsPay, JSON_PAY_LIST,  MenuSettingsPay)
    elseif buttons[selectedItem] == " Выход " then
      os.exit()
    end
end


--[[ Рисовка меню с кнопками]]--
function DrawButtonsMenu(buttons, color, background)
    if buttons == nil then return end
    countOfMenuButtons = buttons['count']
    background = background or Graphic.SelectedBackground
    local menuItemY = yCenter - buttons["count"]/2

    for i, _text in ipairs(buttons) do
      if i == selectedItem then
          WriteText(_text, color, background, nil, menuItemY)
      else
          WriteText(_text, color, nil, nil, menuItemY)
      end
      menuItemY = menuItemY + 2
    end
  end
  



----------------Настройка шансов-----------------------
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
function DrawOddSetings()
    local i = 0

    --countOfMenuButtons = i - 1
    if Tick >= 200 then
        Tick = 0
        UpdateLootList()
    end


    for fullName, loot  in pairs(LOOT_LIST) do
        if fullName ~= "count" then
            i = i+1
            local text =  " #"..i.. "  " ..loot.odd.."% ".. loot.label.. " -> ".. fullName .." "
            if i== selectedItem then
                WriteText(text, nil, Graphic.SelectedBackground , 3, 3+i)
            else
                WriteText(text, nil, nil, 3, 3+i)
            end
            ButtonIndex[i] = fullName
        end
    end

    countOfMenuButtons = LOOT_LIST['count']
    DrawExit(LOOT_LIST['count'], 3, 3+i+1)

end

function SetNewOdd(show_text)
    show_text = "Новый шанс: "
    local new_odd = tonumber(TextInput(show_text, xCenter- string.len(show_text)/2 , screenHeight- 5))

    if new_odd ~= nil and new_odd>=0 and new_odd<100  then
        local item_index = ButtonIndex[selectedItem]
        if JSON_LOOT_LIST[item_index] == nil then
            JSON_LOOT_LIST[item_index] = {
                ["label"] = CHEST_LOOT_LIST[item_index]["label"]
            }
        end

        JSON_LOOT_LIST[item_index]["odd"] = new_odd
        SaveToFile(FILE_WITH_ODDS, JSON_LOOT_LIST)
        UpdateLootList()
    end
    ClearScreen()
end

----------------Настройка оплаты-----------------------
--[[ Логика меню Настроек ]]--
function MenuSettingsPay()
    if selectedItem == countOfMenuButtons then
        MenuBack()
        return
    else
        SetNewOddForPay()
    end
end


--[[ Рисовка меню Настроек ]]--
function DrawOddSetingsPay()
    local i = 0

    --countOfMenuButtons = i - 1
    if Tick >= 200 then
        Tick = 0
        UpdatePayList()
    end

    for fullName, loot  in pairs(JSON_PAY_LIST) do
        if fullName ~= "count" then
            i = i+1
            local text =  " #"..i.. "  +" ..loot.odd.."% ".. loot.label.. " -> ".. fullName .." "
            if i== selectedItem then
                WriteText(text, nil, Graphic.SelectedBackground , 3, 3+i)
            else
                WriteText(text, nil, nil, 3, 3+i)
            end
            ButtonIndex[i] = fullName
        end
    end

    countOfMenuButtons = i+1

    DrawExit(countOfMenuButtons, 3, 3+i+1)
end

function SetNewOddForPay()
    local show_text = "Новый шанс: "
    local new_odd = tonumber(TextInput(show_text, xCenter- string.len(show_text)/2 , screenHeight- 5))
    if new_odd ~= nil and new_odd<-1 and new_odd>100  then return end

    local item_index = ButtonIndex[selectedItem]
    if new_odd == -1 then
        JSON_PAY_LIST[item_index]= nil
    else
        JSON_PAY_LIST[item_index]["odd"] = new_odd
    end

    SaveToFile(FILE_WITH_PAY, JSON_PAY_LIST)
    UpdatePayList()
    ClearScreen()
end

function UpdatePayList()
    local allStacksInChest = tr.getAllStacks(chestInput).getAll()
    JSON_PAY_LIST = LoadFile(FILE_WITH_PAY)

    --CHEST--
    for i, item in pairs(allStacksInChest) do
        if item.name ~= nil then
            local fullName = GetFullName(item)

            if JSON_PAY_LIST[fullName] == nil then
                JSON_PAY_LIST[fullName] = {
                    ["label"]= item.label,
                    ["odd"] = 0,
                }
            end
        end
    end
end

----------------------------Работа с файлами --------------------------

function SaveToFile(fileName, array)
    local data = serialization.serialize(array)
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

function GetFullName(item)
    if item ~= nil and item.name ~= nil then
        return item.name .. "/" .. item.damage
    else
        return 'none'
    end
end

--[[ Получить слот, где есть предмет ]]--
function GetSlotWithItem(side)
    local all_items = tr.getAllStacks(side)
    local chest_size = tr.getInventorySize(side)

    for i = 1, chest_size do
        if all_items[i]~=nil then
            return i
        end
    end

    return 0
end


function GetItemFromChest(side, slot)
    if slot == nil then
        slot = GetSlotWithItem(side, slot)
    end
    if slot == 0 then return end
    local item =  tr.getStackInSlot(side, slot)

    if item == nil then return end

    return {
        ['name'] = item.name,
        ["slot"] = slot,
        ["fullName"] = GetFullName(item),
        ["label"]= item.label,
        ["damage"] = item.damage
    }
end

function PutItemFromTo(fromSide, toSide, count, fromSlot, toSlot )
    count = count or 64
    if fromSlot ~= nil then
        tr.transferItem(fromSide, toSide, count, fromSlot)
    else
        tr.transferItem(fromSide, toSide, count)
    end
    -- if fromSlot == nil then
    --     for slot, item in pairs(tr.getAllStacks(fromSide).getAll()) do
    --         if item ~= nil then
    --             tr.transferItem(fromSide, toSide, slot)
    --         end
    --     end 
    -- end
end

function UpdateLootList() 
    local allStacksInChest = tr.getAllStacks(chestLoot).getAll()
    JSON_LOOT_LIST = LoadFile(FILE_WITH_ODDS)
    CHEST_LOOT_LIST = {}
    LOOT_LIST = {}
    local buttnonsCount = 1

    --CHEST_LOOT_LIST--
    for i, item in pairs(allStacksInChest) do
        if item.name ~= nil then
            local itemName = item.name .. "/" .. item.damage
            if CHEST_LOOT_LIST[itemName] == nil then
                CHEST_LOOT_LIST[itemName] = {
                    ["slot"] = i+1,
                    ["label"]= item.label,
                    ["count"] = item.size,
                }    
                local json_loot = JSON_LOOT_LIST[itemName]
                local odd = 0
                if json_loot ~= nil then
                    odd = json_loot['odd']
                end
                LOOT_LIST[itemName] = {["odd"] = odd, ["label"] = item.label}
                buttnonsCount= buttnonsCount +1
            end
        end
    end
    CountOfLoots = buttnonsCount

    for fullName, loot in pairs(JSON_LOOT_LIST) do -- В файле
        if LOOT_LIST[fullName] == nil then
            LOOT_LIST[fullName] = loot
            buttnonsCount= buttnonsCount +1
        end
    end
    LOOT_LIST["count"] = buttnonsCount
    
end

----------------Лотерея----------------------

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

    --if #odds == 0 then WriteText("Не указаны предметы для выйгрыша")  os.sleep(5) os.exit() end

    UpdateLootList()
    UpdatePayList()
    ClearScreen()
end

function GetPay()
    WriteText("Положите плату для лотереи в входной сундук")
    while true do
        local item = GetItemFromChest(chestInput)
        if item ~= nil then
            ClearScreen()
            local fullName = GetFullName(item)
            WriteText("В качестве платы использовано: " ..item.label .." ("..fullName..")")
            os.sleep(3)

            if JSON_PAY_LIST[item.fullName] == nil then
                ClearScreen()
                WriteText("Неверная оплата!")
                PutItemFromTo(chestInput, chestOutput)
                os.sleep(3)
                ClearScreen()
                WriteText("Положите плату для лотереи в входной сундук")
            else             
                return JSON_PAY_LIST[item.fullName].odd
            end
        end
        os.sleep(1)
    end
end

function GetRandomLoot(payOdd)
    if CountOfLoots == 0 then
        PutItemFromTo(chestInput, chestOutput, 1)
        return
    end
    PutItemFromTo(chestInput, chestTrash, 1)

    
    while true do
        local randomItem = math.random(0, CountOfLoots)
        local i = 0
        os.sleep(1)

        for fullName, item in pairs(CHEST_LOOT_LIST) do
            if i == randomItem then
                ClearScreen()
                WriteText(item.label)
                os.sleep(1)
                local itemOdd = LOOT_LIST[fullName].odd

                if itemOdd + payOdd > math.random(0,100) then
                    ClearScreen()
                    WriteText(item.label, 0x925CAF)
                    PutItemFromTo(chestLoot, chestOutput, 1, item.slot)
                    os.sleep(4)
                    UpdateLootList()
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
        local pay = GetPay()
        GetRandomLoot(pay)
        os.sleep(2)
    end
end

--[[ Главное меню ]]--
while true do
    DrawMenu(DrawButtonsMenu, Menus["main"],  MainMenu)
end
