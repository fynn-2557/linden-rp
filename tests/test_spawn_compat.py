import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from lupa.lua54 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
TEMP = ROOT/'tests/.tmp'
TEMP.mkdir(exist_ok=True)
SPEC = json.loads((ROOT/'compat/esx-1.16.3-fiveprs-ptb5.json').read_text(encoding='utf-8'))['changes']
modspec = importlib.util.spec_from_file_location('compat', ROOT/'tools/patch_spawn_compat.py')
compat = importlib.util.module_from_spec(modspec)
modspec.loader.exec_module(compat)

def vm():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute('''
        events = {}; threads = {}; timers = {}; net = {}; commands = {}
        owner = 'esx'; skinState = 'started'; skinMode = 'ok'; positioned = 0; spawned = 0
        ESX = { playerId=1 }; Core = {}; coords={ x=1,y=2,z=3,heading=4 }
        function GetConvar(name, default) if name=='linden_spawn_owner' then return owner end return default end
        function GetResourceState(name) if name=='skinchanger' then return skinState end return 'started' end
        function TranslateCap(s) return s end
        function AddEventHandler(name, fn) events[name] = fn end
        function RegisterNetEvent(name, fn) events[name] = fn; net[name] = true end
        function TriggerEvent(name, ...)
            if name=='skinchanger:loadSkin' then
                local skin, cb = ...; skinCallback = cb; receivedSkin = skin
                if skinMode=='ok' then cb() elseif skinMode=='reject' then cb(false) end
            elseif events[name] then events[name](...) end
        end
        function CreateThread(fn) table.insert(threads, fn) end
        function SetTimeout(ms, fn) table.insert(timers,fn); timeoutMs=ms end
        function Wait(ms) end
        promise = {new=function() return {resolve=function(self,value) self.value=value; self.settled=true end} end}
        Citizen = { Await=function(p) if not p.settled then timers[1]() end return p.value end }
        function PlayerPedId() return 1 end
        function PlayerId() return 1 end
        function RequestCollisionAtCoord(...) end
        function GetGameTimer() return 0 end
        function SetPlayerControl(...) end
        function SetEntityCollision(...) end
        function FreezeEntityPosition(...) end
        function SetEntityCoordsNoOffset(...) positioned=positioned+1 end
        function SetEntityHeading(...) end
        function HasCollisionLoadedAroundEntity(...) return true end
        function NetworkResurrectLocalPlayer(...) spawned=spawned+1 end
        function print(...) end
        LocalPlayer = {state={set=function(self,k,v) self[k]=v end}}
        exports = {spawnmanager={
            setAutoSpawnCallback=function(self,fn) autoCallback=fn end,
            spawnPlayer=function(self,spot) spawnSpot=spot; spawned=spawned+1 end
        }}
    ''')
    return lua

class SpawnTests(unittest.TestCase):
    def test_multichar_no_longer_activated_by_installed_resource(self):
        for version, expected in [('original', True), ('updated', False)]:
            lua=vm(); lua.execute(SPEC[0][version])
            self.assertEqual(lua.globals().Config.Multichar, expected)
            self.assertEqual(lua.globals().Config.Identity, expected)

    def test_join_event_registered_for_network_only_after_fix(self):
        source=(ROOT/'tests/fixtures/spawn/join-server.lua').read_text(encoding='utf-8')
        for multi, expected in [(True, None),(False,True)]:
            lua=vm(); lua.execute('Core.PlayerSession = {}; Config = {}')
            lua.globals().Config.Multichar=multi
            lua.execute(source)
            self.assertEqual(lua.globals().net['esx:onPlayerJoined'],expected)

    def test_client_join_runs_once_only_in_single_account_mode(self):
        source=(ROOT/'tests/fixtures/spawn/join-client.lua').read_text(encoding='utf-8')
        for multi, expected in [(True,None),(False,'esx:onPlayerJoined')]:
            lua=vm(); lua.execute('''
                Config={}; function NetworkIsPlayerActive() return true end
                function ESX.DisableSpawnManager() disabled=true end
                function DoScreenFadeOut(...) end
                function TriggerServerEvent(name) joined=name end
            ''')
            lua.globals().Config.Multichar=multi
            lua.execute(source); lua.execute('threads[1]()')
            self.assertEqual(lua.globals().joined,expected)

    def test_successful_spawn_uses_esx_position_and_new_account_default_skin(self):
        lua=vm(); lua.execute(SPEC[1]['updated'])
        self.assertTrue(lua.eval('ESX.SpawnPlayer(nil,coords,function() completed=true end)'))
        self.assertTrue(lua.globals().completed)
        self.assertEqual(lua.globals().receivedSkin.sex,0)
        self.assertEqual(lua.globals().spawned,1)

    def test_missing_skinchanger_fails_before_position_or_callback(self):
        lua=vm(); lua.execute(SPEC[1]['updated']); lua.globals().skinState='stopped'
        self.assertFalse(lua.eval('ESX.SpawnPlayer({},coords,function() completed=true end)'))
        self.assertIsNone(lua.globals().completed)
        self.assertEqual(lua.globals().positioned,0)

    def test_rejected_and_missing_callbacks_do_not_hang_or_spawn(self):
        for mode in ['reject','timeout']:
            lua=vm(); lua.execute(SPEC[1]['updated']); lua.globals().skinMode=mode
            self.assertFalse(lua.eval('ESX.SpawnPlayer({},coords,function() completed=true end)'))
            self.assertEqual(lua.globals().timeoutMs,10000)
            lua.execute('skinCallback(true)')  # Late callback must not resume a failed spawn.
            self.assertIsNone(lua.globals().completed)
            self.assertEqual(lua.globals().spawned,0)

    def test_fiveprs_handoff_never_installs_autospawn_or_spawns(self):
        lua=vm(); lua.execute(SPEC[3]['updated'])
        self.assertEqual(len(lua.globals().threads),0)
        self.assertIsNone(lua.globals().autoCallback)
        lua.execute("events['FivePRS:Local:SpawnHandled']=function(value) handled=value end; events['FivePRS:Local:SpawnTarget']()")
        self.assertTrue(lua.globals().handled)
        lua.execute("events['playerSpawned']()")
        self.assertTrue(lua.globals().LocalPlayer.state.fiveprsSpawned)
        self.assertEqual(lua.globals().spawned,0)

    def test_standalone_first_and_later_spawns_have_explicit_position(self):
        lua=vm(); lua.globals().owner='standalone'; lua.execute(SPEC[3]['updated'])
        lua.execute("threads[1](); events['FivePRS:Client:LastPosition'](false,0,0,0,0,''); autoCallback()")
        self.assertAlmostEqual(lua.globals().spawnSpot.x,222.2027)
        lua.execute('autoCallback()')
        self.assertEqual(lua.globals().spawnSpot.model,'mp_m_freemode_01')

    def test_saved_fiveprs_position_remains_supported_in_standalone(self):
        lua=vm(); lua.globals().owner='standalone'; lua.execute(SPEC[3]['updated'])
        lua.execute("threads[1](); events['FivePRS:Client:LastPosition'](true,10,20,30,40,'model'); autoCallback()")
        self.assertEqual(lua.globals().spawnSpot.x,10)

    def test_all_project_and_patched_lua_compile(self):
        lua=vm(); compile=lua.eval('function(src,name) local fn,err=load(src,name); assert(fn,err) end')
        for p in (ROOT/'linden_rp').rglob('*.lua'):
            compile(p.read_text(encoding='utf-8'),str(p))
        for row in SPEC: compile(row['updated'],row['path'])

    def test_nui_only_releases_owned_focus_on_close_or_client_stop(self):
        lua=vm()
        lua.execute('''
            nui={}; focusCalls=0; keepCalls=0
            function RegisterCommand(n,fn) commands[n]=fn end
            function RegisterNUICallback(n,fn) nui[n]=fn end
            function GetCurrentResourceName() return 'linden_rp' end
            function SetNuiFocus(a,b) focusCalls=focusCalls+1; focused=a end
            function SetNuiFocusKeepInput(a) keepCalls=keepCalls+1; keepInput=a end
            function SendNUIMessage(...) end
            function TriggerServerEvent(...) end
            function GetPlayerName(...) return 'test' end
        ''')
        lua.execute((ROOT/'linden_rp/client/main.lua').read_text(encoding='utf-8'))
        lua.execute("nui.close({},function() end); events.onClientResourceStop('linden_rp')")
        self.assertEqual(lua.globals().focusCalls,0)
        lua.execute("commands.leitstelle(); events.onClientResourceStop('other')")
        self.assertTrue(lua.globals().focused)
        lua.execute("events.onClientResourceStop('linden_rp')")
        self.assertFalse(lua.globals().focused)
        self.assertFalse(lua.globals().keepInput)
        self.assertEqual(lua.globals().keepCalls,1)

    def test_diagnostics_registers_one_delayed_observation_without_state_changes(self):
        lua=vm()
        lua.execute('''
            json={encode=function() return '{}' end}
            function RegisterCommand(n,fn) commands[n]=fn end
            function NetworkIsPlayerActive(...) return true end
            function DoesEntityExist(...) return true end
            function IsScreenFadedOut() return true end
            function IsScreenFadedIn() return false end
            function IsNuiFocused() return false end
            function IsGameplayCamRendering() return false end
            function IsPlayerSwitchInProgress() return false end
            function GetIsLoadingScreenActive() return true end
        ''')
        lua.execute((ROOT/'linden_rp/client/spawn_diagnostics.lua').read_text(encoding='utf-8'))
        self.assertEqual(len(lua.globals().threads),1)
        lua.execute('threads[1](); commands.linden_spawn_diag()')
        self.assertEqual(lua.globals().spawned,0)
        self.assertEqual(lua.globals().positioned,0)

    def test_installer_checks_all_files_before_writes_and_is_idempotent(self):
        with tempfile.TemporaryDirectory(dir=TEMP) as d:
            root=Path(d)
            for row in SPEC:
                p=root/row['path']; p.parent.mkdir(parents=True,exist_ok=True); p.write_bytes(row['original'].replace('\n','\r\n').encode())
            originals={p:p.read_bytes() for p in root.rglob('*.lua')}
            with patch.object(compat,'require_offline'):
                backup=compat.apply(root,True)
            self.assertEqual(compat.plan(root),[])
            self.assertIsNone(compat.apply(root,True))
            for p,b in originals.items(): self.assertEqual((backup/p.relative_to(root)).read_bytes(),b)
            (root/SPEC[-1]['path']).write_text('local modification',encoding='utf-8')
            with self.assertRaises(ValueError): compat.plan(root)

    def test_installer_rolls_back_byte_exact_on_write_failure(self):
        with tempfile.TemporaryDirectory(dir=TEMP) as d:
            root=Path(d)
            for row in SPEC:
                p=root/row['path'];p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(row['original'].encode())
            originals={p:p.read_bytes() for p in root.rglob('*.lua')}
            real=compat.atomic_write; count=0
            def fail_second(p,s):
                nonlocal count
                count+=1
                if count==2: raise OSError('injected')
                real(p,s)
            with patch.object(compat,'require_offline'), patch.object(compat,'atomic_write',side_effect=fail_second):
                with self.assertRaises(OSError): compat.apply(root,True)
            for p,b in originals.items(): self.assertEqual(p.read_bytes(),b)

    def test_version_mismatch_makes_no_backup_and_changes_no_files(self):
        with tempfile.TemporaryDirectory(dir=TEMP) as d:
            root=Path(d)
            for row in SPEC:
                p=root/row['path'];p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(row['original'].encode())
            (root/SPEC[-1]['path']).write_text('unknown release',encoding='utf-8')
            originals={p:p.read_bytes() for p in root.rglob('*.lua')}
            with self.assertRaises(ValueError): compat.apply(root,True)
            self.assertFalse((root/'.linden-compat').exists())
            for p,b in originals.items(): self.assertEqual(p.read_bytes(),b)

    def test_patch_apply_requires_explicit_offline_confirmation(self):
        with self.assertRaises(ValueError): compat.require_offline(False)

if __name__=='__main__': unittest.main(verbosity=2)
