local current = nil
local appId = 'rp-characters'
local function isRcore() return GetResourceState('rcore_clothing')=='started' end
local function currentSkin()
    if not isRcore() then return nil end
    local ok,skin=pcall(function() return exports['rcore_clothing']:getPlayerSkin(true) end)
    return ok and type(skin)=='table' and skin or nil
end

local function send(action,data)
    TriggerServerEvent('rp_identity:action',action,data or {})
end

local function refresh() send('refresh',{}) end
local function register()
    exports.fiveprs:registerApp({
        id=appId, label='Characters', color='#435e70', order=17,
        icon='M12 12a4 4 0 1 0 0-8 4 4 0 0 0 0 8z M4 21v-2a8 8 0 0 1 16 0v2',
        page=('https://cfx-nui-%s/html/index.html'):format(GetCurrentResourceName())
    })
end

CreateThread(function()
    while GetResourceState('fiveprs')~='started' do Wait(1000) end
    Wait(1200)
    local ok,err=pcall(register)
    if not ok then print('[RP Identity] FivePRS app registration failed: '..tostring(err)) end
end)

AddEventHandler('fiveprs:appAction',function(app,action,data)
    if app~=appId then return end
    data=type(data)=='table' and data or {}
    if action=='load' then refresh()
    elseif action=='redeem' then send('redeem',{code=data.code})
    elseif action=='temporary' then send('temporary',{department=data.department,firstName=data.firstName,lastName=data.lastName,rank=data.rank})
    elseif action=='select' then send('select',{characterId=data.characterId,previousAppearance=currentSkin()})
    elseif action=='appearance' then
        if not current or not current.activeId then
            exports.fiveprs:sendAppMessage(appId,'error',{message='Bitte erst einen Charakter auswählen.'})
        elseif isRcore() then
            -- API from rcore_clothing; use changing room for persistent outfits.
            TriggerEvent('rcore_clothing:openChangingRoom')
            exports.fiveprs:sendAppMessage(appId,'info',{message='Outfit-Menü geöffnet. Falls das Tablet im Vordergrund ist: ESC drücken.'})
        else exports.fiveprs:sendAppMessage(appId,'error',{message='rcore_clothing wurde nicht gestartet.'}) end
    elseif action=='appearance-edit' then
        if isRcore() then TriggerEvent('rcore_clothing:openClothingShopWithEverythingAndFree')
        else exports.fiveprs:sendAppMessage(appId,'error',{message='rcore_clothing wurde nicht gestartet.'}) end
    end
end)

RegisterNetEvent('rp_identity:data',function(data,changed)
    current=data
    exports.fiveprs:sendAppMessage(appId,'state',data)
    if changed then
        for _,character in ipairs(data.characters or {}) do
            if character.id==data.activeId and isRcore() then
                if type(character.appearance)=='table' then
                    local ok,err=pcall(function() exports['rcore_clothing']:setPlayerSkin(character.appearance,true) end)
                    if not ok then print('[RP Identity] rcore skin load failed: '..tostring(err)) end
                end
                break
            end
        end
    end
end)
RegisterNetEvent('rp_identity:refreshRequest',function() refresh() end)
RegisterNetEvent('rp_identity:error',function(errorText)
    exports.fiveprs:sendAppMessage(appId,'error',{message=tostring(errorText)})
end)
AddEventHandler('rcore_clothing:onClothingShopClosed',function()
    Wait(400)
    local skin=currentSkin()
    if skin and current and current.activeId then send('appearance',{appearance=skin}) end
end)

-- This command exists only as FiveM's mandatory keymapping mechanism.
-- The player uses M, never /character or any other user-facing character command.
RegisterCommand('rp_identity_tablet',function()
    if GetResourceState('fiveprs')=='started' then ExecuteCommand('fiveprs') end
end,false)
RegisterKeyMapping('rp_identity_tablet','RP Tablet / Charaktermenü','keyboard','M')

-- Fallback if an outfit-change event is missing in an rcore_clothing variant.
CreateThread(function()
    while true do
        Wait(90000)
        if current and current.activeId and isRcore() then
            local skin = currentSkin()
            if skin then send('appearance', { appearance = skin }) end
        end
    end
end)
