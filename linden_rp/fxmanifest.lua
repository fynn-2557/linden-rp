fx_version 'cerulean'
game 'gta5'
lua54 'yes'
name 'Linden RP NRW'
author 'Linden RP Projekt'
description 'Discord-Charakterbridge, ESX/QB/QBX adapter, ox_lib und Linden Dispatch'
version '0.4.0'
ui_page 'web/index.html'
shared_scripts { '@ox_lib/init.lua', 'shared/framework_config.lua', 'dispatch_config.lua', 'identity_config.lua' }
server_scripts { '@oxmysql/lib/MySQL.lua', 'server/identity.lua', 'server/framework_bridge.lua', 'server/main.lua' }
client_scripts { 'client/framework_bridge.lua', 'client/identity.lua', 'client/main.lua' }
files { 'web/index.html','web/style.css','web/app.js','web/assets/*.webp',
        'html/index.html','html/style.css','html/app.js' }
dependencies { 'ox_lib', 'oxmysql', 'fiveprs' }
