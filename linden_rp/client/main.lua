local open = false
local currentMode = 'dispatch'

local function ui(mode)
  currentMode = mode or 'dispatch'
  open = true
  SetNuiFocus(true, true)
  SendNUIMessage({ type = 'open', mode = currentMode, name = GetPlayerName(PlayerId()) })
  TriggerServerEvent('ld:request', 'snapshot', {}, ('init-%d'):format(GetGameTimer()))
end

RegisterCommand('leitstelle', function() ui('dispatch') end, false)
RegisterCommand('notruf', function() ui('call') end, false)
RegisterCommand('fahrzeugfunk', function() ui('radio') end, false)
RegisterCommand('melder', function() ui('pager') end, false)
RegisterCommand('leitstellecreator', function() ui('creator') end, false)

local function closeUi()
  if not open then return end
  open = false
  SetNuiFocus(false, false)
  SetNuiFocusKeepInput(false)
  SendNUIMessage({ type = 'close' })
end

RegisterNUICallback('close', function(_, cb)
  closeUi()
  cb({ ok = true })
end)

RegisterNUICallback('rpc', function(data, cb)
  if not data or type(data.action) ~= 'string' or type(data.rid) ~= 'string' then cb({ ok = false }); return end
  TriggerServerEvent('ld:request', data.action, data.payload or {}, data.rid)
  cb({ ok = true })
end)

RegisterNUICallback('position', function(_, cb)
  local p = GetEntityCoords(PlayerPedId())
  local h1, h2 = GetStreetNameAtCoord(p.x, p.y, p.z)
  local street = h1 ~= 0 and GetStreetNameFromHashKey(h1) or 'Unbekannte Straße'
  local crossing = h2 ~= 0 and GetStreetNameFromHashKey(h2) or nil
  cb({ ok = true, x = p.x, y = p.y, z = p.z, street = street, crossing = crossing })
end)

RegisterNetEvent('ld:snapshot', function(state)
  SendNUIMessage({ type = 'snapshot', state = state })
end)
RegisterNetEvent('ld:response', function(rid, response)
  SendNUIMessage({ type = 'response', rid = rid, response = response })
end)
RegisterNetEvent('ld:notice', function(message, level)
  SendNUIMessage({ type = 'notice', message = message, level = level })
end)
RegisterNetEvent('ld:alert', function(alert)
  SendNUIMessage({ type = 'alert', alert = alert })
end)
RegisterNetEvent('ld:radio', function(channel)
  if GetResourceState('pma-voice') == 'started' then
    local ok, err = pcall(function() exports['pma-voice']:setRadioChannel(channel) end)
    if not ok then SendNUIMessage({ type = 'notice', message = 'Funkwechsel fehlgeschlagen: ' .. tostring(err), level = 'error' }) end
  end
end)

AddEventHandler('onClientResourceStop', function(name)
  if name == GetCurrentResourceName() then closeUi() end
end)

