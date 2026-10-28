-- Read-only client diagnosis. Never fades, teleports, changes cameras or steals focus.
local spawned = false
local loaded = false
local startedAt = GetGameTimer()
AddEventHandler('playerSpawned', function() spawned = true end)
RegisterNetEvent('esx:playerLoaded', function() loaded = true end)

local function report()
    local ped = PlayerPedId()
    local data = {
        elapsedMs = GetGameTimer() - startedAt,
        owner = GetConvar('linden_spawn_owner', 'unset'),
        esx = GetResourceState('es_extended'),
        skinchanger = GetResourceState('skinchanger'),
        fiveprs = GetResourceState('fiveprs'),
        multichar = GetResourceState('esx_multicharacter'),
        networkActive = NetworkIsPlayerActive(PlayerId()),
        playerSpawned = spawned,
        esxLoadedEvent = loaded,
        pedExists = DoesEntityExist(ped),
        fadedOut = IsScreenFadedOut(),
        fadedIn = IsScreenFadedIn(),
        nuiFocus = IsNuiFocused(),
        gameplayCamera = IsGameplayCamRendering(),
        switchInProgress = IsPlayerSwitchInProgress(),
        loadingScreen = GetIsLoadingScreenActive()
    }
    print('[Linden spawn diagnosis] ' .. json.encode(data))
end

RegisterCommand('linden_spawn_diag', report, false)
CreateThread(function()
    Wait(45000)
    if not spawned or not loaded or not IsScreenFadedIn() then
        report()
        print('[Linden] Lade-/Spawnzustand unvollständig. F8-Log an die Administration weitergeben.')
    end
end)
