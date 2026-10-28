local lastCall = {}
local assigned = {}
local activeProfiles = {}
local activeDutySources = {}
local departments = { police = true, fire = true, ems = true }
local function identity(source)
    local discord = GetPlayerIdentifierByType(source, 'discord')
    local license = GetPlayerIdentifierByType(source, 'license')
    if not discord or not license then return nil, nil end
    return discord:match('^discord:(%d+)$'), license
end

local function api(endpoint, data, cb)
    if IdentityConfig.ApiSecret == '' then print('^1[RP Identity] Missing rp_identity_api_secret^7') cb(false, 'API key fehlt.') return end
    PerformHttpRequest(IdentityConfig.ApiBase .. '/v1/' .. endpoint, function(status, body)
        if status ~= 200 then
            local ok, parsed = pcall(json.decode, body or '')
            cb(false, ok and parsed.error or ('API nicht erreichbar (HTTP ' .. tostring(status) .. ')'))
            return
        end
        local ok, parsed = pcall(json.decode, body or '')
        if not ok or not parsed or not parsed.ok then cb(false, 'Ungültige API-Antwort.') return end
        cb(true, parsed.result)
    end, 'POST', json.encode(data), { ['Content-Type'] = 'application/json', ['Authorization'] = 'Bearer ' .. IdentityConfig.ApiSecret })
end

if IdentityConfig.EnableWhitelist then
    AddEventHandler('playerConnecting', function(_, _, deferrals)
        local source = source
        deferrals.defer()
        Wait(0)
        deferrals.update('Discord-Freischaltung wird geprüft...')
        local discordId = identity(source)
        if not discordId then deferrals.done('Discord und FiveM-Lizenz müssen mit FiveM verbunden sein.') return end
        api('whitelist', { discordId = discordId }, function(ok, result)
            if not ok then deferrals.done('RP-Whitelist nicht erreichbar: ' .. tostring(result))
            elseif not result.allowed then deferrals.done('Keine genehmigte Discord-Whitelist vorhanden.')
            else deferrals.done() end
        end)
    end)
end

local function setRoleAce(source, data)
    local selected
    for _, character in ipairs(data.characters or {}) do
        if character.id == data.activeId then selected = character break end
    end
    activeProfiles[source] = selected
    TriggerEvent('rp_identity:server:characterChanged', source, selected)
    if not IdentityConfig.EnableFivePrsAce then return end
    local license = GetPlayerIdentifierByType(source,'license')
    if not license then return end
    local principal = 'identifier.' .. license
    for dept in pairs(departments) do
        ExecuteCommand(('remove_principal %s group.rp_%s'):format(principal, dept))
    end
    if selected and departments[selected.department] and selected.trainingState ~= 'training' then
        ExecuteCommand(('add_principal %s group.rp_%s'):format(principal, selected.department))
        assigned[source] = { department = selected.department, license = license }
    elseif selected and data.activeDuty and data.activeDuty.dept=='ff' and selected.department=='civilian' and data.ff and data.ff.orientationPassed then
        ExecuteCommand(('add_principal %s group.rp_fire'):format(principal))
        assigned[source] = { department = 'fire', license = license }
    else assigned[source] = nil end
end

AddEventHandler('playerDropped',function()
    local src=source
    lastCall[src]=nil
    activeProfiles[src]=nil
    local bound=activeDutySources[src]
    activeDutySources[src]=nil
    if bound then
        -- Unexpected disconnect: session is closed but does not count as completed duty.
        api('duty-stop',{discordId=bound.discordId,license=bound.license,count=false},function() end)
        local lp=GetPlayerIdentifierByType(src,'license') or bound.license
        if IdentityConfig.EnableFivePrsAce then ExecuteCommand('remove_principal identifier.'..lp..' group.rp_fire') end
    end
    if not IdentityConfig.EnableFivePrsAce or not assigned[src] then return end
    local record=assigned[src]
    if record.license then ExecuteCommand('remove_principal identifier.'..record.license..' group.rp_'..record.department) end
    assigned[src]=nil
end)

RegisterNetEvent('rp_identity:action', function(action, data)
    local src=source
    if type(action)~='string' or type(data)~='table' then return end
    local now=GetGameTimer()
    if lastCall[src] and now-lastCall[src]<IdentityConfig.CooldownMs then
        TriggerClientEvent('rp_identity:error',src,'Bitte nicht so schnell hintereinander.') return
    end
    lastCall[src]=now
    local discordId,license=identity(src)
    if not discordId then TriggerClientEvent('rp_identity:error',src,'Discord-Identifier oder FiveM-Lizenz fehlt.') return end
    local payload={discordId=discordId,license=license}
    local endpoint
    if action=='refresh' then endpoint='state'
    elseif action=='redeem' and type(data.code)=='string' then
        endpoint='redeem';payload.code=data.code:sub(1,40)
    elseif action=='temporary' then
        endpoint='temporary';payload.department=data.department;payload.firstName=data.firstName;payload.lastName=data.lastName;payload.rank=tonumber(data.rank)
    elseif action=='select' and type(data.characterId)=='string' then
        endpoint='select';payload.characterId=data.characterId
        if type(data.previousAppearance)=='table' then payload.previousAppearance=data.previousAppearance end
    elseif action=='appearance' and type(data.appearance)=='table' then
        endpoint='appearance';payload.appearance=data.appearance
    else TriggerClientEvent('rp_identity:error',src,'Unbekannte Anfrage.') return end
    if #json.encode(payload)>160000 then TriggerClientEvent('rp_identity:error',src,'Datenpaket zu groß.') return end
    api(endpoint,payload,function(ok,result)
        if GetPlayerName(src)==nil then return end
        if not ok then TriggerClientEvent('rp_identity:error',src,result) return end
        if action=='appearance' then return end
        if type(result)=='table' then
            setRoleAce(src,result)
            TriggerClientEvent('rp_identity:data',src,result,action=='select')
        end
    end)
end)

-- Other resources can read the active profile on demand, but not set the rank.
exports('getCharacter', function(playerId) return activeProfiles[playerId] end)

exports('getIdentity',function(playerId)
    local id,license=identity(playerId)
    if not id then return nil end
    return {discordId=id,license=license}
end)


-- Server-only duty integration for a FivePRS core fork or trusted adapter.
-- Never RegisterNetEvent these endpoints: clients must not increment probation by themselves.
local function dutyAction(src, mode, options, cb)
    local did, license = identity(src)
    if not did then if cb then cb(false, 'Keine Discord-/Lizenzbindung.') end return end
    local data = {discordId=did,license=license}
    if mode=='start' then data.ff=type(options)=='table' and options.ff==true end
    if mode=='stop' then data.count=not (type(options)=='table' and options.count==false) end
    api(mode=='start' and 'duty-start' or 'duty-stop',data,function(ok,result)
        if ok then
            if mode=='start' then activeDutySources[src]={discordId=did,license=license,department=result.department} TriggerEvent('rp_identity:server:dutyStarted',src,result)
            else activeDutySources[src]=nil TriggerEvent('rp_identity:server:dutyEnded',src,result) end
            TriggerClientEvent('rp_identity:refreshRequest',src)
        end
        if cb then cb(ok,result) end
    end)
end
exports('startDuty',function(src,opts,cb) dutyAction(src,'start',opts,cb) end)
exports('stopDuty',function(src,opts,cb) dutyAction(src,'stop',opts,cb) end)

-- These exports are available to the dispatch module of this SAME resource.
exports('GetActiveCharacter', function(playerId) return activeProfiles[tonumber(playerId)] end)
exports('GetActiveDuty', function(playerId) return activeDutySources[tonumber(playerId)] end)
exports('GetActiveJob', function(playerId)
    local src=tonumber(playerId)
    local c=activeProfiles[src]
    local duty=activeDutySources[src]
    if not c or not duty or c.trainingState == 'training' then return nil end
    if duty.department == 'ff' and c.department == 'civilian' then return 'fire' end
    if duty.department ~= c.department then return nil end
    return ({ police='police', fire='fire', ems='ambulance' })[c.department]
end)
