-- Linden RP read-only framework bridge (server). Identity data is authoritative.
-- ESX/QB/QBX may be selected one at a time; never trust client job/rank events.
local f = FrameworkConfig
local validModes = { esx=true, qb=true, qbx=true, standalone=true }
if not validModes[f.Mode] then error('[Linden] Invalid linden_framework mode: '..tostring(f.Mode)) end
local function running(name) return GetResourceState(name)=='started' end
local function validFramework()
    if f.Mode=='standalone' then return true end
    local resource = ({esx='es_extended', qb='qb-core', qbx='qbx_core'})[f.Mode]
    if not running(resource) then return false, resource..' is not started' end
    return true
end
local function currentProfile(src)
    local ok, profile = pcall(function() return exports[GetCurrentResourceName()]:GetActiveCharacter(src) end)
    if not ok or type(profile)~='table' then return nil end
    local okDuty, duty = pcall(function() return exports[GetCurrentResourceName()]:GetActiveDuty(src) end)
    return profile, okDuty and duty or nil
end
local function getCanonicalJob(src)
    src=tonumber(src)
    if not src or src<1 then return nil end
    local p, duty=currentProfile(src)
    if not p or not duty or p.trainingState=='training' then return nil end
    local department = (duty.department=='ff' and p.department=='civilian') and 'fire' or p.department
    if duty.department ~= p.department and not (duty.department=='ff' and p.department=='civilian') then return nil end
    local nativeName = f.JobNames[department]
    if not nativeName then return nil end
    return { name=nativeName, department=department, grade=tonumber(p.rank) or 0,
             label=p.rankLabel or nativeName, characterId=p.id, characterKind=p.kind,
             onDuty=true, source=src }
end
local function getNativeJob(src)
    local ok, player
    if f.Mode=='esx' and running('es_extended') then
        ok,player=pcall(function() return exports['es_extended']:getSharedObject().GetPlayerFromId(src) end)
        if ok and player and type(player.getJob)=='function' then return player.getJob() end
    elseif f.Mode=='qb' and running('qb-core') then
        ok,player=pcall(function() return exports['qb-core']:GetCoreObject().Functions.GetPlayer(src) end)
        if ok and player and player.PlayerData then return player.PlayerData.job end
    elseif f.Mode=='qbx' and running('qbx_core') then
        ok,player=pcall(function() return exports.qbx_core:GetPlayer(src) end)
        if ok and player and player.PlayerData then return player.PlayerData.job end
    end
    return nil
end
local function syncNativeJob(src)
    if not f.SyncNativeJobs then return false,'native job sync is disabled' end
    local ready,err=validFramework()
    if not ready then return false,err end
    local job=getCanonicalJob(src)
    local nativeName=job and job.name or f.OffDutyJob
    -- This is not an RP promotion: an existing native job must be registered, and
    -- grade zero is used to avoid unreviewed native-script permission escalation.
    local grade=f.DefaultGrade
    local ok, success=pcall(function()
        if f.Mode=='esx' then
            local ESX=exports['es_extended']:getSharedObject()
            if not ESX.DoesJobExist(nativeName,grade) then return false end
            local xPlayer=ESX.GetPlayerFromId(src)
            if not xPlayer then return false end
            xPlayer.setJob(nativeName,grade);return true
        elseif f.Mode=='qb' then
            local qb=exports['qb-core']:GetCoreObject()
            if not qb.Shared.Jobs[nativeName] then return false end
            local p=qb.Functions.GetPlayer(src)
            return p and p.Functions.SetJob(nativeName,grade) or false
        elseif f.Mode=='qbx' then
            local p=exports.qbx_core:GetPlayer(src)
            if not p then return false end
            -- Qbox job writes use its own exported API; not guessed here.
            return false
        end
        return false
    end)
    if not ok or not success then return false,'native job could not be synchronized; verify job configuration' end
    return true
end
exports('GetFrameworkMode',function() return f.Mode end)
exports('GetCanonicalJob',getCanonicalJob)
exports('GetNativeJob',getNativeJob)
exports('HasLindenJob',function(src,jobName)
    local j=getCanonicalJob(src)
    return j~=nil and (j.department==jobName or j.name==jobName)
end)
exports('SyncNativeJob',function(src)
    -- Only explicitly trusted server resources can request writes.
    local caller=GetInvokingResource()
    if caller and caller~=GetCurrentResourceName() then return false,'external synchronization denied' end
    return syncNativeJob(tonumber(src))
end)
AddEventHandler('rp_identity:server:characterChanged',function(src)
    if f.SyncNativeJobs then SetTimeout(300,function() syncNativeJob(src) end) end
end)
AddEventHandler('rp_identity:server:dutyStarted',function(src)
    if f.SyncNativeJobs then syncNativeJob(src) end
end)
AddEventHandler('rp_identity:server:dutyEnded',function(src)
    if f.SyncNativeJobs then syncNativeJob(src) end
end)
CreateThread(function()
    Wait(200)
    local ok,msg=validFramework()
    if not ok then print('^1[Linden bridge] '..tostring(msg)..'^7')
    else print(('[Linden bridge] mode=%s | native writeback=%s'):format(f.Mode,tostring(f.SyncNativeJobs))) end
end)
