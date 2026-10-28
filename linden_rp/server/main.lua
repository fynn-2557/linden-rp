local ready = false
local rate = {}
local operators = {}
local requestCooldown = Config.Cooldowns
local entityTypes = { org = true, station = true, vehicle = true, keyword = true, object = true, hospital = true, access = true, group = true, number = true }

local function clean(s, max)
  if type(s) ~= 'string' then return '' end
  s = s:gsub('[%z\1-\8\11\12\14-\31]', '')
  return s:sub(1, max or 180)
end
local function num(v, min, max)
  v = tonumber(v)
  if not v or v ~= v or v < min or v > max then return nil end
  return v
end
local function identity(src)
  return GetPlayerIdentifierByType(src, 'license') or ('player:' .. tostring(src))
end
local function framework()
  if Config.Framework ~= 'auto' then return Config.Framework end
  if GetResourceState('es_extended') == 'started' then return 'esx' end
  if GetResourceState('qb-core') == 'started' then return 'qb' end
  return 'standalone'
end
-- Job is authoritative: only active, trained AND on-duty identity profiles count.
-- Deliberately do not fall back to ESX/QB jobs in this combined standalone resource.
local function playerJob(src)
  local ok, job = pcall(function() return exports[GetCurrentResourceName()]:GetActiveJob(src) end)
  return ok and job or nil, nil
end
local function matchingJob(job, org)
  local map = { ['Polizei']='police', ['Feuerwehr']='fire', ['Rettungsdienst']='ambulance',
                police='police', fire='fire', ambulance='ambulance', ems='ambulance' }
  return job ~= nil and map[org] == job
end
local function trustedIntegration()
  local caller = GetInvokingResource()
  if caller == nil or caller == GetCurrentResourceName() then return true end
  return Config.TrustedResources[caller] == true
end
local function notifyIncident(kind, incidentId, details)
  TriggerEvent('linden_rp:incident:' .. kind, incidentId, details)
end
local function notifyVehicle(kind, callsign, details)
  TriggerEvent('linden_rp:vehicle:' .. kind, callsign, details)
end
local function creator(src)
  if src == 0 or IsPlayerAceAllowed(src, Config.CreatorAce) then return true end
  local _, group = playerJob(src)
  if group and Config.AdminGroups[group] then return true end
  if framework() == 'qb' then
    local ok, qb = pcall(function() return exports['qb-core']:GetCoreObject() end)
    if ok and qb then
      for groupName in pairs(Config.AdminGroups) do
        if qb.Functions.HasPermission(src, groupName) then return true end
      end
    end
  end
  return false
end
local function dispatcher(src)
  if creator(src) or IsPlayerAceAllowed(src, Config.DispatcherAce) then return true end
  local job = playerJob(src)
  if job and Config.DispatcherJobs[job] then return true end
  if job then
    local rows = MySQL.query.await("SELECT data FROM ld_entities WHERE kind = 'access'") or {}
    for _, r in ipairs(rows) do local d = json.decode(r.data) or {}; if d.job == job then return true end end
  end
  return false
end
local function respond(src, rid, success, data)
  TriggerClientEvent('ld:response', src, rid, { ok = success, data = success and data or nil, error = success and nil or data })
end
local function sendNotice(src, msg, level)
  TriggerClientEvent('ld:notice', src, clean(msg, 280), level or 'info')
end
local function cooldown(src, key, seconds)
  local k = tostring(src) .. ':' .. key
  local now = os.time()
  if (rate[k] or 0) > now then return false, rate[k] - now end
  rate[k] = now + (seconds or 1)
  return true
end
local function position(src)
  local ped = GetPlayerPed(src)
  if ped and ped ~= 0 then
    local c = GetEntityCoords(ped)
    if c then return { x = c.x + 0.0, y = c.y + 0.0, z = c.z + 0.0 } end
  end
  return { x = 0.0, y = 0.0, z = 0.0 }
end
local function logEntry(incidentId, kind, body, author)
  MySQL.insert.await('INSERT INTO ld_journal (incident_id, kind, message, actor) VALUES (?, ?, ?, ?)',
    { incidentId, clean(kind, 32), clean(body, 500), clean(author or 'SYSTEM', 80) })
end
local function sendSnapshot(src)
  if not ready then return end
  local allowed = dispatcher(src)
  local owner = identity(src)
  local job = playerJob(src)
  local service = Config.AllowedServiceJobs[job or ''] == true
  local unitRows = (allowed or service) and (MySQL.query.await('SELECT * FROM ld_vehicle_state ORDER BY callsign') or {}) or {}
  for _, unit in ipairs(unitRows) do unit.crew_assigned = unit.crew_identifier ~= nil; unit.crew_identifier = nil end
  local state = {
    role = { dispatcher = allowed, creator = creator(src), job = playerJob(src), framework = framework(), voice = (GetResourceState('pma-voice') == 'started' and 'pma-voice' or 'none') },
    entities = MySQL.query.await('SELECT id, kind, data FROM ld_entities ORDER BY kind, id DESC') or {},
    incidents = allowed and (MySQL.query.await('SELECT * FROM ld_incidents ORDER BY id DESC LIMIT 120') or {}) or
      (service and (MySQL.query.await('SELECT i.* FROM ld_incidents i JOIN ld_vehicle_state v ON v.incident_id = i.id WHERE v.crew_identifier = ? ORDER BY i.id DESC LIMIT 60', { owner }) or {}) or {}),
    vehicles = unitRows,
    journal = allowed and (MySQL.query.await('SELECT * FROM ld_journal ORDER BY id DESC LIMIT 180') or {}) or
      (service and (MySQL.query.await('SELECT j.* FROM ld_journal j JOIN ld_vehicle_state v ON v.incident_id = j.incident_id WHERE v.crew_identifier = ? ORDER BY j.id DESC LIMIT 90', { owner }) or {}) or {}),
    calls = allowed and (MySQL.query.await('SELECT * FROM ld_calls ORDER BY id DESC LIMIT 80') or {}) or (MySQL.query.await('SELECT * FROM ld_calls WHERE caller_identifier = ? ORDER BY id DESC LIMIT 20', { owner }) or {}),
    messages = allowed and (MySQL.query.await('SELECT * FROM ld_messages ORDER BY id DESC LIMIT 150') or {}) or (MySQL.query.await('SELECT m.* FROM ld_messages m JOIN ld_calls c ON c.id = m.call_id WHERE c.caller_identifier = ? ORDER BY m.id DESC LIMIT 100', { owner }) or {}),
    operators = allowed and operators or {},
  }
  TriggerClientEvent('ld:snapshot', src, state)
end
local function broadcast()
  for _, id in ipairs(GetPlayers()) do sendSnapshot(tonumber(id)) end
end
local function getIncident(id)
  return MySQL.single.await('SELECT * FROM ld_incidents WHERE id = ?', { id })
end
local function getVehicle(callsign)
  return MySQL.single.await('SELECT * FROM ld_vehicle_state WHERE callsign = ?', { callsign })
end
local function entityData(kind)
  local rows = MySQL.query.await('SELECT id, data FROM ld_entities WHERE kind = ?', { kind }) or {}
  for _, r in ipairs(rows) do r.value = json.decode(r.data) or {} end
  return rows
end
local function chooseAAO(incidentId, keywordName, x, y)
  local keywords = entityData('keyword')
  local chosen
  for _, r in ipairs(keywords) do if r.value.name == keywordName then chosen = r.value; break end end
  if not chosen then return {} end
  local needs = {}
  for typeName, qty in tostring(chosen.aao or ''):gmatch('([%w_%-]+):(%d+)') do needs[typeName] = math.min(tonumber(qty), 12) end
  local units = MySQL.query.await("SELECT * FROM ld_vehicle_state WHERE fms = 2 AND incident_id IS NULL") or {}
  local stations = entityData('station')
  local positions = {}
  for _, s in ipairs(stations) do positions[tostring(s.id)] = s.value end
  local options = {}
  for _, v in ipairs(units) do
    if needs[v.type] and needs[v.type] > 0 then
      local s = positions[tostring(v.station_id)] or {}
      local dx, dy = (tonumber(s.x) or 0) - x, (tonumber(s.y) or 0) - y
      options[#options + 1] = { v = v, dist = dx * dx + dy * dy }
    end
  end
  table.sort(options, function(a, b) return a.dist < b.dist end)
  local selected = {}
  for _, entry in ipairs(options) do
    local v = entry.v
    if needs[v.type] and needs[v.type] > 0 then
      needs[v.type] = needs[v.type] - 1
      local affected = MySQL.update.await('UPDATE ld_vehicle_state SET fms = 3, incident_id = ?, changed_at = CURRENT_TIMESTAMP WHERE callsign = ? AND fms = 2 AND incident_id IS NULL', { incidentId, v.callsign })
      if affected == 0 then goto continue_aao end
      notifyVehicle('dispatched', v.callsign, { incidentId = incidentId, source = 'AAO' })
      notifyVehicle('statusChanged', v.callsign, { status = 3, incidentId = incidentId })
      for _, onlineId in ipairs(GetPlayers()) do
        local pid = tonumber(onlineId)
        if v.crew_identifier and identity(pid) == v.crew_identifier then TriggerClientEvent('ld:alert', pid, { title = 'ALARM · ' .. v.callsign .. ' · ' .. keywordName, x = x, y = y, critical = false }) end
      end
      logEntry(incidentId, 'ALARM', v.callsign .. ' alarmiert – AAO ' .. keywordName, 'AAO')
      selected[#selected + 1] = v.callsign
      ::continue_aao::
    end
  end
  return selected
end
local function entityWrite(kind, id, data)
  if not entityTypes[kind] or type(data) ~= 'table' then return false, 'Ungültiger Objekttyp.' end
  local formatted = json.encode(data)
  if #formatted > 3500 then return false, 'Datensatz zu groß.' end
  data.name = clean(data.name, 100)
  data.org = clean(data.org, 80)
  data.job = clean(data.job, 64)
  data.callsign = clean(data.callsign, 48)
  data.type = clean(data.type, 32)
  data.plate = clean(data.plate, 16):upper()
  data.aao = clean(data.aao, 260)
  data.x = num(data.x, -10000, 10000) or 0
  data.y = num(data.y, -10000, 10000) or 0
  if data.name == '' and kind ~= 'vehicle' then return false, 'Name fehlt.' end
  if kind == 'vehicle' and (data.callsign == '' or data.type == '') then return false, 'Funkkennung und Fahrzeugtyp fehlen.' end
  local jsonText = json.encode(data)
  if id then
    local row = MySQL.single.await('SELECT id FROM ld_entities WHERE id = ? AND kind = ?', { id, kind })
    if not row then return false, 'Eintrag nicht gefunden.' end
    MySQL.update.await('UPDATE ld_entities SET data = ? WHERE id = ? AND kind = ?', { jsonText, id, kind })
  else
    id = MySQL.insert.await('INSERT INTO ld_entities (kind, data) VALUES (?, ?)', { kind, jsonText })
  end
  if kind == 'vehicle' then
    MySQL.query.await('INSERT INTO ld_vehicle_state (callsign, type, org, station_id, plate) VALUES (?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE type=VALUES(type), org=VALUES(org), station_id=VALUES(station_id), plate=VALUES(plate)',
      { data.callsign, data.type, data.org, tonumber(data.station_id) or 0, data.plate })
  end
  return true, id
end
local function seed()
  local n = MySQL.scalar.await('SELECT COUNT(*) FROM ld_entities') or 0
  if tonumber(n) == 0 then
    for _, o in ipairs(Config.InitialOrganizations) do entityWrite('org', nil, o) end
    for _, k in ipairs(Config.DefaultKeywords) do entityWrite('keyword', nil, k) end
  end
end
local function setup()
  local tables = {
    [[CREATE TABLE IF NOT EXISTS ld_meta (`key` VARCHAR(60) NOT NULL PRIMARY KEY, value VARCHAR(255) NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS ld_entities (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, kind VARCHAR(30) NOT NULL, data LONGTEXT NOT NULL, changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, INDEX (kind)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS ld_incidents (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, title VARCHAR(160) NOT NULL, keyword_name VARCHAR(100) NOT NULL, location_label VARCHAR(200) NOT NULL, postal VARCHAR(15) NOT NULL DEFAULT '', x DOUBLE NOT NULL, y DOUBLE NOT NULL, priority TINYINT UNSIGNED NOT NULL DEFAULT 2, state VARCHAR(20) NOT NULL DEFAULT 'OPEN', caller_id INT UNSIGNED NULL, created_by VARCHAR(100) NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, closed_at TIMESTAMP NULL, INDEX (state)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS ld_calls (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, number VARCHAR(10) NOT NULL, caller_identifier VARCHAR(100) NOT NULL, caller_name VARCHAR(120) NOT NULL, detail TEXT NOT NULL, status VARCHAR(20) NOT NULL DEFAULT 'OPEN', linked_incident INT UNSIGNED NULL, x DOUBLE NOT NULL, y DOUBLE NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, INDEX (caller_identifier), INDEX (status)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS ld_messages (id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY, call_id INT UNSIGNED NOT NULL, sender VARCHAR(120) NOT NULL, sender_type VARCHAR(20) NOT NULL, message TEXT NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, INDEX (call_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS ld_journal (id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY, incident_id INT UNSIGNED NOT NULL, kind VARCHAR(32) NOT NULL, message VARCHAR(500) NOT NULL, actor VARCHAR(80) NOT NULL, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, INDEX (incident_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS ld_vehicle_state (callsign VARCHAR(48) NOT NULL PRIMARY KEY, type VARCHAR(32) NOT NULL, org VARCHAR(80) NOT NULL, station_id INT UNSIGNED NULL, plate VARCHAR(16) NOT NULL DEFAULT '', fms TINYINT UNSIGNED NOT NULL DEFAULT 2, incident_id INT UNSIGNED NULL, crew_identifier VARCHAR(100) NULL, x DOUBLE NULL, y DOUBLE NULL, changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP, INDEX (incident_id)) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
    [[CREATE TABLE IF NOT EXISTS ld_call_blocks (caller_identifier VARCHAR(100) PRIMARY KEY, reason VARCHAR(250) NOT NULL, until_at TIMESTAMP NOT NULL) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]
  }
  for _, q in ipairs(tables) do MySQL.query.await(q) end
  MySQL.query.await("INSERT INTO ld_meta (`key`, value) VALUES ('schema', '1') ON DUPLICATE KEY UPDATE value=VALUES(value)")
  seed()
  ready = true
  print('^2[Linden Dispatch]^7 Schema 1 bereit. Framework: ' .. framework())
end
MySQL.ready(setup)

RegisterNetEvent('ld:request', function(action, payload, rid)
  local src = source
  if not ready then respond(src, rid, false, 'Datenbank noch nicht bereit.'); return end
  if type(action) ~= 'string' or type(payload) ~= 'table' or type(rid) ~= 'string' then return end
  if #rid > 40 then return end
  local d = payload
  local function fail(msg) respond(src, rid, false, msg) end
  local function ok(value) respond(src, rid, true, value) end
  local isDispatch = dispatcher(src)
  if action == 'snapshot' then sendSnapshot(src); ok(true); return end
  if action == 'operator:status' then
    if not isDispatch then fail('Keine Leitstellenberechtigung.'); return end
    local status = clean(d.status, 10)
    if status ~= 'green' and status ~= 'yellow' and status ~= 'red' then fail('Ungültiger Dienststatus.'); return end
    operators[identity(src)] = { name = clean(GetPlayerName(src), 80), status = status }
    ok(true); broadcast(); return
  end
  if action == 'call:create' then
    local pass, seconds = cooldown(src, 'call', requestCooldown.call)
    if not pass then fail('Erneuter Notruf in ' .. seconds .. ' s möglich.'); return end
    local license = identity(src)
    local ban = MySQL.single.await('SELECT reason FROM ld_call_blocks WHERE caller_identifier = ? AND until_at > CURRENT_TIMESTAMP', { license })
    if ban then fail('Notruf gesperrt: ' .. ban.reason); return end
    local number = clean(d.number, 10)
    if not Config.EmergencyNumbers[number] then fail('Ungültige Notrufnummer.'); return end
    local detail = clean(d.detail, Config.CallTextMaxLength)
    if #detail < 5 then fail('Bitte den Notfall beschreiben.'); return end
    local p = position(src)
    local id = MySQL.insert.await('INSERT INTO ld_calls (number, caller_identifier, caller_name, detail, x, y) VALUES (?, ?, ?, ?, ?, ?)', { number, license, clean(GetPlayerName(src), 120), detail, p.x, p.y })
    MySQL.insert.await('INSERT INTO ld_messages (call_id, sender, sender_type, message) VALUES (?, ?, ?, ?)', { id, clean(GetPlayerName(src), 120), 'CALLER', detail })
    ok({ id = id }); broadcast()
    for _, onlineId in ipairs(GetPlayers()) do
      local pid = tonumber(onlineId)
      if dispatcher(pid) then TriggerClientEvent('ld:alert', pid, { title = 'NOTRUF ' .. number .. ' · # ' .. id, x = p.x, y = p.y, critical = true }) end
    end
    return
  end
  if action == 'call:message' then
    local pass = cooldown(src, 'message', requestCooldown.message)
    if not pass then fail('Bitte kurz warten.'); return end
    local callId = num(d.callId, 1, 2147483647)
    local row = callId and MySQL.single.await('SELECT * FROM ld_calls WHERE id = ?', { callId })
    if not row then fail('Notruf nicht gefunden.'); return end
    if not isDispatch and row.caller_identifier ~= identity(src) then fail('Kein Zugriff auf diesen Notruf.'); return end
    local msg = clean(d.message, 550)
    if #msg < 1 then fail('Leere Nachricht.'); return end
    if row.status == 'CLOSED' then fail('Notruf ist abgeschlossen.'); return end
    MySQL.insert.await('INSERT INTO ld_messages (call_id, sender, sender_type, message) VALUES (?, ?, ?, ?)', { callId, clean(GetPlayerName(src), 120), isDispatch and 'DISPATCH' or 'CALLER', msg })
    ok(true); broadcast(); return
  end
  if action == 'call:hangup' then
    local id = num(d.id, 1, 2147483647)
    local row = id and MySQL.single.await('SELECT caller_identifier FROM ld_calls WHERE id = ?', { id })
    if not row or row.caller_identifier ~= identity(src) then fail('Notruf nicht gefunden oder kein Zugriff.'); return end
    MySQL.update.await("UPDATE ld_calls SET status = 'CLOSED' WHERE id = ? AND status != 'CLOSED'", { id })
    ok(true); broadcast(); return
  end
  if action == 'call:close' then
    if not isDispatch then fail('Leitstellenberechtigung fehlt.'); return end
    local id = num(d.id, 1, 2147483647)
    if not id then fail('Ungültige ID.'); return end
    MySQL.update.await("UPDATE ld_calls SET status = 'CLOSED' WHERE id = ?", { id })
    ok(true); broadcast(); return
  end
  if action == 'call:block' then
    if not creator(src) then fail('Creator-Berechtigung fehlt.'); return end
    local callId = num(d.id, 1, 2147483647)
    local days = num(d.days, 1, 30)
    if not callId or not days then fail('Dauer: 1–30 Tage.'); return end
    local call = MySQL.single.await('SELECT caller_identifier FROM ld_calls WHERE id = ?', { callId })
    if not call then fail('Anrufer unbekannt.'); return end
    MySQL.query.await('INSERT INTO ld_call_blocks (caller_identifier, reason, until_at) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL ? DAY)) ON DUPLICATE KEY UPDATE reason=VALUES(reason), until_at=VALUES(until_at)', { call.caller_identifier, clean(d.reason, 250), days })
    ok(true); return
  end
  if action == 'incident:preview' then
    if not creator(src) then fail('Creator-Berechtigung fehlt.'); return end
    local target = clean(d.keyword, 100)
    local needs, chosen = {}, {}
    for _, k in ipairs(entityData('keyword')) do
      if k.value.name == target then
        for typeName, qty in tostring(k.value.aao or ''):gmatch('([%w_%-]+):(%d+)') do needs[typeName] = math.min(tonumber(qty), 12) end
        break
      end
    end
    local units = MySQL.query.await('SELECT * FROM ld_vehicle_state WHERE fms = 2 AND incident_id IS NULL ORDER BY callsign') or {}
    for _, v in ipairs(units) do
      if needs[v.type] and needs[v.type] > 0 then needs[v.type] = needs[v.type] - 1; chosen[#chosen + 1] = v.callsign .. ' (' .. v.type .. ')' end
    end
    ok({ vehicles = chosen, missing = needs }); return
  end
  if action == 'entity:save' then
    if not creator(src) then fail('Creator-Berechtigung fehlt.'); return end
    local id = d.id and num(d.id, 1, 2147483647) or nil
    local success, result = entityWrite(clean(d.kind, 30), id, d.data)
    if not success then fail(result); return end
    ok({ id = result }); broadcast(); return
  end
  if action == 'entity:delete' then
    if not creator(src) then fail('Creator-Berechtigung fehlt.'); return end
    local id = num(d.id, 1, 2147483647)
    if not id then fail('Ungültige ID.'); return end
    local row = MySQL.single.await('SELECT kind, data FROM ld_entities WHERE id = ?', { id })
    if not row then fail('Eintrag nicht vorhanden.'); return end
    local value = json.decode(row.data) or {}
    if row.kind == 'vehicle' then
      local state = getVehicle(value.callsign or '')
      if state and state.incident_id then fail('Fahrzeug ist in einem Einsatz.'); return end
      MySQL.update.await('DELETE FROM ld_vehicle_state WHERE callsign = ?', { value.callsign })
    end
    MySQL.update.await('DELETE FROM ld_entities WHERE id = ?', { id })
    ok(true); broadcast(); return
  end
  if action == 'incident:create' then
    if not isDispatch then fail('Keine Leitstellenberechtigung.'); return end
    local x, y = num(d.x, -10000, 10000), num(d.y, -10000, 10000)
    if not x or not y then fail('Ungültige Koordinaten.'); return end
    local title = clean(d.title, 160)
    if #title < 3 then fail('Einsatztitel fehlt.'); return end
    local keyword = clean(d.keyword, 100)
    local callId = num(d.callId, 1, 2147483647)
    if callId and not MySQL.single.await('SELECT id FROM ld_calls WHERE id = ?', { callId }) then fail('Notruf existiert nicht.'); return end
    local id = MySQL.insert.await('INSERT INTO ld_incidents (title, keyword_name, location_label, postal, x, y, priority, caller_id, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      { title, keyword, clean(d.location, 200), clean(d.postal, 15), x, y, num(d.priority, 1, 3) or 2, callId, clean(GetPlayerName(src), 100) })
    if callId then MySQL.update.await('UPDATE ld_calls SET linked_incident = ?, status = ? WHERE id = ?', { id, 'DISPATCHED', callId }) end
    logEntry(id, 'CREATE', 'Einsatz erstellt: ' .. title, GetPlayerName(src))
    local alarmed = chooseAAO(id, keyword, x, y)
    notifyIncident('created', id, { keyword = keyword, title = title, x = x, y = y, alarmed = alarmed })
    ok({ id = id, alarmed = alarmed }); broadcast(); return
  end
  if action == 'incident:close' then
    if not isDispatch then fail('Keine Berechtigung.'); return end
    local id = num(d.id, 1, 2147483647)
    local inc = id and getIncident(id)
    if not inc then fail('Einsatz nicht gefunden.'); return end
    if inc.state == 'CLOSED' then fail('Bereits abgeschlossen.'); return end
    MySQL.update.await("UPDATE ld_incidents SET state = 'CLOSED', closed_at = NOW() WHERE id = ?", { id })
    MySQL.update.await('UPDATE ld_vehicle_state SET incident_id = NULL, fms = 2 WHERE incident_id = ?', { id })
    logEntry(id, 'CLOSE', 'Einsatz abgeschlossen.', GetPlayerName(src))
    notifyIncident('closed', id, { by = GetPlayerName(src) })
    ok(true); broadcast(); return
  end
  if action == 'incident:note' then
    if not isDispatch then fail('Keine Berechtigung.'); return end
    local id = num(d.id, 1, 2147483647)
    if not id or not getIncident(id) then fail('Einsatz nicht gefunden.'); return end
    local msg = clean(d.message, 500)
    if #msg < 2 then fail('Eintrag fehlt.'); return end
    logEntry(id, 'NOTE', msg, GetPlayerName(src))
    ok(true); broadcast(); return
  end
  if action == 'vehicle:assign' then
    if not isDispatch then fail('Keine Berechtigung.'); return end
    local incidentId = num(d.incidentId, 1, 2147483647)
    local callsign = clean(d.callsign, 48)
    local inc, veh = incidentId and getIncident(incidentId), getVehicle(callsign)
    if not inc or inc.state == 'CLOSED' or not veh then fail('Ungültiger Einsatz / Einheit.'); return end
    if veh.incident_id and tonumber(veh.incident_id) ~= incidentId then fail('Fahrzeug bereits gebunden.'); return end
    MySQL.update.await('UPDATE ld_vehicle_state SET incident_id = ?, fms = 3 WHERE callsign = ?', { incidentId, callsign })
    logEntry(incidentId, 'ALARM', callsign .. ' durch Leitstelle disponiert.', GetPlayerName(src))
    notifyVehicle('dispatched', callsign, { incidentId = incidentId, source = 'UI' })
    notifyVehicle('statusChanged', callsign, { status = 3, incidentId = incidentId })
    ok(true); broadcast(); return
  end
  if action == 'vehicle:crew' then
    local callsign = clean(d.callsign, 48)
    local v = getVehicle(callsign)
    if not v then fail('Fahrzeug nicht gefunden.'); return end
    local job = playerJob(src)
    if not creator(src) and not matchingJob(job, v.org) then fail('Dieses Fahrzeug gehört nicht zur aktiven Dienststelle.'); return end
    local ped = GetPlayerPed(src)
    local vehicle = ped ~= 0 and GetVehiclePedIsIn(ped, false) or 0
    if vehicle == 0 then fail('Du musst im Fahrzeug sitzen.'); return end
    if v.plate == '' then fail('Fahrzeug benötigt hinterlegtes Kennzeichen.'); return end
    local plate = clean(GetVehicleNumberPlateText(vehicle) or '', 16):gsub('%s+$', ''):gsub('^%s+', ''):upper()
    if plate ~= v.plate:gsub('%s+$', '') then fail('Kennzeichen stimmt nicht überein.'); return end
    if v.crew_identifier and v.crew_identifier ~= identity(src) and not creator(src) then fail('Fahrzeug ist bereits besetzt.'); return end
    MySQL.update.await('UPDATE ld_vehicle_state SET crew_identifier = ? WHERE callsign = ?', { identity(src), callsign })
    ok(true); broadcast(); return
  end
  if action == 'vehicle:status' then
    local pass = cooldown(src, 'status', requestCooldown.status)
    if not pass then fail('Status-Cooldown aktiv.'); return end
    local callsign, fms = clean(d.callsign, 48), num(d.fms, 0, 8)
    local v = getVehicle(callsign)
    if not fms or fms % 1 ~= 0 or not v then fail('Ungültiger FMS-Status oder Funkkennung.'); return end
    if not isDispatch and v.crew_identifier ~= identity(src) then fail('Du bist nicht für dieses Fahrzeug eingetragen.'); return end
    local p = position(src)
    MySQL.update.await('UPDATE ld_vehicle_state SET fms = ?, x = ?, y = ? WHERE callsign = ?', { fms, p.x, p.y, callsign })
    if v.incident_id then logEntry(v.incident_id, 'FMS', callsign .. ' → ' .. fms .. ': ' .. (Config.StatusLabels[tostring(fms)] or ''), GetPlayerName(src)) end
    notifyVehicle('statusChanged', callsign, { status = fms, incidentId = v.incident_id, source = 'UI' })
    ok(true); broadcast(); return
  end
  if action == 'vehicle:panic' or action == 'vehicle:request' then
    local pass = cooldown(src, 'panic', requestCooldown.panic)
    if not pass then fail('Cooldown aktiv.'); return end
    local callsign = clean(d.callsign, 48)
    local v = getVehicle(callsign)
    if not v or (not isDispatch and v.crew_identifier ~= identity(src)) then fail('Keine Berechtigung für das Fahrzeug.'); return end
    local p = position(src)
    local message = action == 'vehicle:panic' and 'NOTRUFKNOPF' or 'SPRECHWUNSCH'
    if v.incident_id then logEntry(v.incident_id, message, callsign .. ' meldet ' .. message .. (' (%.0f / %.0f)'):format(p.x, p.y), GetPlayerName(src)) end
    for _, id in ipairs(GetPlayers()) do
      id = tonumber(id)
      if dispatcher(id) then TriggerClientEvent('ld:alert', id, { title = message .. ' · ' .. callsign, x = p.x, y = p.y, critical = action == 'vehicle:panic' }) end
    end
    ok(true); broadcast(); return
  end
  if action == 'radio:join' then
    local channel = num(d.channel, 0, 9999)
    if not channel then fail('Ungültige Funkgruppe.'); return end
    local job = playerJob(src)
    if not isDispatch and not Config.AllowedServiceJobs[job or ''] then fail('Funk nicht freigegeben.'); return end
    if GetResourceState('pma-voice') ~= 'started' then fail('pma-voice ist nicht aktiv. Textfunk bleibt verfügbar.'); return end
    TriggerClientEvent('ld:radio', src, channel)
    ok({ channel = channel }); return
  end
  fail('Unbekannte Aktion: ' .. clean(action, 40))
end)

AddEventHandler('playerDropped', function()
  local src = source
  local owner = identity(src)
  operators[owner] = nil
  rate[tostring(src) .. ':call'] = nil
  if Config.ReleaseUnitWhenDisconnected and ready then
    MySQL.update('UPDATE ld_vehicle_state SET crew_identifier = NULL WHERE crew_identifier = ?', { owner })
  end
  if ready then SetTimeout(500, broadcast) end
end)

CreateThread(function()
  while true do
    Wait(math.max(10, Config.AutoArrivalIntervalSeconds) * 1000)
    if ready and Config.AutoArrival then
      local units = MySQL.query.await('SELECT * FROM ld_vehicle_state WHERE fms = 3 AND incident_id IS NOT NULL AND crew_identifier IS NOT NULL') or {}
      for _, v in ipairs(units) do
        local inc = getIncident(v.incident_id)
        if inc then
          for _, sid in ipairs(GetPlayers()) do
            local pid = tonumber(sid)
            if identity(pid) == v.crew_identifier then
              local p = position(pid)
              local dist = ((p.x - inc.x)^2 + (p.y - inc.y)^2)^0.5
              if dist <= Config.AutoArrivalDistance then
                MySQL.update.await('UPDATE ld_vehicle_state SET fms = 4, x = ?, y = ? WHERE callsign = ? AND fms = 3', { p.x, p.y, v.callsign })
                logEntry(v.incident_id, 'FMS', v.callsign .. ' automatisch Status 4 (Ankunft)', 'SYSTEM')
                broadcast()
              end
              break
            end
          end
        end
      end
    end
  end
end)

exports('CreateIncident', function(data)
  if not trustedIntegration() then return nil, 'Resource not trusted' end
  if not ready or type(data) ~= 'table' then return nil, 'Not ready / invalid payload' end
  local x, y = num(data.x, -10000, 10000), num(data.y, -10000, 10000)
  if not x or not y then return nil, 'Invalid position' end
  local id = MySQL.insert.await('INSERT INTO ld_incidents (title, keyword_name, location_label, postal, x, y, priority, created_by) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    { clean(data.title or 'Externer Einsatz', 160), clean(data.keyword, 100), clean(data.location, 200), clean(data.postal, 15), x, y, 2, 'EXPORT' })
  logEntry(id, 'CREATE', 'Einsatz über Server-Export erzeugt.', 'API')
  local alarmed = chooseAAO(id, clean(data.keyword, 100), x, y)
  notifyIncident('created', id, { title = clean(data.title or 'Externer Einsatz', 160), keyword = clean(data.keyword, 100), x = x, y = y, alarmed = alarmed })
  broadcast()
  return id
end)
exports('GetVehicleStatus', function(callsign)
  if not trustedIntegration() or not ready then return nil end
  local vehicle = getVehicle(clean(callsign, 48))
  if vehicle then vehicle.status = vehicle.fms end -- backwards-compatible convenience alias
  return vehicle
end)
exports('GetIncident', function(id) if not trustedIntegration() or not ready then return nil end return getIncident(num(id, 1, 2147483647)) end)


-- Public server-side adapter API; callers must be allowlisted in Config.TrustedResources.
exports('RegisterVehicle', function(data)
  if not trustedIntegration() then return false, 'Resource nicht autorisiert' end
  if not ready or type(data) ~= 'table' then return false, 'Nicht bereit oder Daten ungültig' end
  local callsign, typeName = clean(data.callsign,48), clean(data.type,32)
  local org = clean(data.org,80)
  if callsign == '' or typeName == '' or not ({['Polizei']=true,['Feuerwehr']=true,['Rettungsdienst']=true})[org] then
    return false, 'Funkkennung, Fahrzeugtyp oder Organisation ungültig'
  end
  local stationId = num(data.stationId,0,2147483647) or 0
  local plate = clean(data.plate or '',16):upper()
  -- Keep the Creator entity catalogue AND the active fleet table consistent.
  local oldEntityId = nil
  for _, item in ipairs(entityData('vehicle')) do
    if item.value.callsign == callsign then oldEntityId = item.id; break end
  end
  local saved, idOrErr = entityWrite('vehicle', oldEntityId, {
    name = callsign, callsign = callsign, type = typeName, org = org,
    station_id = stationId, plate = plate
  })
  if not saved then return false, idOrErr end
  notifyVehicle('registered', callsign, { type = typeName, org = org, entityId = idOrErr })
  broadcast()
  return true
end)

exports('GetAvailableUnits', function(filter)
  if not trustedIntegration() or not ready then return {} end
  filter = type(filter) == 'table' and filter or {}
  local rows = MySQL.query.await('SELECT callsign,type,org,station_id,plate,fms,x,y FROM ld_vehicle_state WHERE fms = 2 AND incident_id IS NULL ORDER BY callsign') or {}
  local list = {}
  for _, row in ipairs(rows) do
    if (not filter.org or row.org == filter.org) and (not filter.type or row.type == filter.type) then
      list[#list+1] = row
    end
  end
  return list
end)

exports('SetVehicleStatus', function(callsign, status)
  if not trustedIntegration() then return false, 'Resource nicht autorisiert' end
  if not ready then return false, 'Noch nicht bereit' end
  callsign, status = clean(callsign,48), num(status,0,8)
  if not status or status % 1 ~= 0 then return false, 'Ungültiger FMS-Status' end
  local v = getVehicle(callsign)
  if not v then return false, 'Fahrzeug nicht registriert' end
  MySQL.update.await('UPDATE ld_vehicle_state SET fms = ? WHERE callsign = ?', {status,callsign})
  if v.incident_id then logEntry(v.incident_id,'FMS',callsign .. ' → ' .. status, 'SCRIPT') end
  notifyVehicle('statusChanged', callsign, {status=status, incidentId=v.incident_id, source='EXPORT'})
  broadcast()
  return true
end)

exports('DispatchVehicle', function(callsign, incidentId)
  if not trustedIntegration() then return false, 'Resource nicht autorisiert' end
  if not ready then return false, 'Noch nicht bereit' end
  callsign, incidentId = clean(callsign,48), num(incidentId,1,2147483647)
  local incident = incidentId and getIncident(incidentId)
  if not incident or incident.state ~= 'OPEN' then return false, 'Einsatz fehlt oder abgeschlossen' end
  local updated = MySQL.update.await('UPDATE ld_vehicle_state SET incident_id=?, fms=3 WHERE callsign=? AND fms=2 AND incident_id IS NULL', {incidentId,callsign})
  if not updated or updated < 1 then return false, 'Fahrzeug nicht frei oder unbekannt' end
  local v=getVehicle(callsign)
  logEntry(incidentId,'ALARM',callsign .. ' über Script alarmiert','API')
  for _, id in ipairs(GetPlayers()) do
    local pid=tonumber(id)
    if v and v.crew_identifier and identity(pid)==v.crew_identifier then
      TriggerClientEvent('ld:alert',pid,{title='ALARM · ' .. callsign .. ' · ' .. incident.keyword_name,x=incident.x,y=incident.y,critical=false})
    end
  end
  notifyVehicle('dispatched',callsign,{incidentId=incidentId,source='EXPORT'})
  notifyVehicle('statusChanged',callsign,{status=3,incidentId=incidentId,source='EXPORT'})
  broadcast()
  return true
end)

exports('CloseIncident', function(id)
  if not trustedIntegration() then return false, 'Resource nicht autorisiert' end
  if not ready then return false, 'Noch nicht bereit' end
  id = num(id,1,2147483647)
  local inc = id and getIncident(id)
  if not inc or inc.state == 'CLOSED' then return false, 'Einsatz fehlt oder ist bereits abgeschlossen' end
  MySQL.update.await("UPDATE ld_incidents SET state='CLOSED',closed_at=NOW() WHERE id=? AND state='OPEN'",{id})
  MySQL.update.await('UPDATE ld_vehicle_state SET incident_id=NULL,fms=2 WHERE incident_id=?',{id})
  logEntry(id,'CLOSE','Einsatz über Server-Export geschlossen.','API')
  notifyIncident('closed',id,{by='API'})
  broadcast()
  return true
end)

exports('SendPagerAlert', function(data)
  if not trustedIntegration() then return false, 'Resource nicht autorisiert' end
  if not ready or type(data)~='table' then return false,'Daten fehlen' end
  local callsign=clean(data.callsign,48)
  if callsign=='' then return false,'Funkkennung fehlt' end
  local v=getVehicle(callsign)
  if not v or not v.crew_identifier then return false,'Fahrzeug hat keine Besatzung' end
  local sent=0
  for _, id in ipairs(GetPlayers()) do
    local pid=tonumber(id)
    if identity(pid)==v.crew_identifier then
      TriggerClientEvent('ld:alert',pid,{title=clean(data.message or ('Alarm für ' .. callsign),200),x=num(data.x,-10000,10000) or 0,y=num(data.y,-10000,10000) or 0,critical=data.critical==true})
      sent=sent+1
    end
  end
  return sent>0, sent>0 and sent or 'Keine Besatzung online'
end)

-- Text-only; voice integration with LoveRP Sepura requires its documented API.
exports('SendRadioMessage', function(data)
  if not trustedIntegration() then return false, 'Resource nicht autorisiert' end
  if type(data)~='table' then return false,'Daten fehlen' end
  local org=clean(data.org,80)
  local msg=clean(data.message,240)
  if msg=='' or not ({['Polizei']=true,['Feuerwehr']=true,['Rettungsdienst']=true})[org] then return false,'Organisation/Meldung fehlt' end
  for _, player in ipairs(GetPlayers()) do
    local src=tonumber(player)
    local job=playerJob(src)
    if matchingJob(job,org) then sendNotice(src,'FUNK · ' .. org .. ': ' .. msg) end
  end
  TriggerEvent('linden_rp:radio:textSent',{org=org,message=msg})
  return true
end)

exports('RequestBackup', function(data)
  if not trustedIntegration() then return nil,'Resource nicht autorisiert' end
  if not ready then return nil,'Noch nicht bereit' end
  if type(data)~='table' then return nil,'Daten fehlen' end
  local typeName=clean(data.type or 'Unterstützung',120)
  local x,y=num(data.x,-10000,10000),num(data.y,-10000,10000)
  if not x or not y then return nil,'Koordinaten fehlen' end
  local id=MySQL.insert.await('INSERT INTO ld_incidents (title,keyword_name,location_label,postal,x,y,priority,created_by) VALUES (?,?,?,?,?,?,?,?)',
    { 'Unterstützung · ' .. typeName,clean(data.keyword or 'H1 – Hilfeleistung',100),clean(data.location or '',200),clean(data.postal or '',15),x,y,1,'BACKUP'})
  logEntry(id,'CREATE','Unterstützung angefordert','API')
  local alarmed=chooseAAO(id,clean(data.keyword or 'H1 – Hilfeleistung',100),x,y)
  notifyIncident('created',id,{title='Unterstützung · ' .. typeName,x=x,y=y,alarmed=alarmed})
  broadcast()
  return id
end)


-- Console-only diagnostic, does not require connecting any real player.
RegisterCommand('linden_rp_diag', function(src)
  if src ~= 0 then return end
  print(('[LindenRP] v0.3 dispatch_ready=%s fiveprs=%s oxmysql=%s test_mode=%s')
    :format(tostring(ready),GetResourceState('fiveprs'),GetResourceState('oxmysql'),tostring(Config.TestMode)))
  print('[LindenRP] Discord API: ' .. (IdentityConfig.ApiSecret ~= '' and 'Geheimnis konfiguriert' or 'FEHLT'))
  print('[LindenRP] Dispatch-Rollen werden aus der aktiven RP-Identität UND einem laufenden Dienst gelesen.')
end, true)

-- Smoke-test creates one marked SQL incident but deliberately does not dispatch the AAO.
RegisterCommand('linden_rp_test_incident', function(src)
  if src ~= 0 then return end
  if not Config.TestMode then print('[LindenRP] Testmode nicht aktiviert. set linden_rp_test_mode true VOR ensure linden_rp') return end
  if not ready then print('[LindenRP] Datenbank noch nicht bereit') return end
  local id = MySQL.insert.await('INSERT INTO ld_incidents (title,keyword_name,location_label,postal,x,y,priority,created_by) VALUES (?,?,?,?,?,?,?,?)',
    {'[TEST] Integrationstest – KEINE ALARMIERUNG', 'TEST', 'Testserver', '', 0, 0, 3, 'TESTMODE'})
  logEntry(id,'TEST','Nur Testdatensatz, keine AAO oder Alarmierung.', 'SYSTEM')
  print(('[LindenRP] Testeinsatz #%s angelegt; nicht alarmiert. Aus der Leitstelle schließen.'):format(tostring(id)))
  notifyIncident('created',id,{title='[TEST] Integrationstest',test=true,x=0,y=0,alarmed={}})
  broadcast()
end, true)
