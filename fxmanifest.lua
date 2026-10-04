fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'dps-chat'
author 'Del Perro Sands'
description 'Command box only (voice-only server): T opens a fixed box, type a /command, Enter runs it. No chat feed.'
version '1.1.0'

-- Takes the place of the default chat and okokChat. Scripts that send chat messages or
-- register suggestions keep working; messages are dropped (voice only), suggestions are kept.
provide 'chat'

ui_page 'html/index.html'
files { 'html/index.html', 'html/style.css', 'html/app.js' }

shared_script 'shared/logic.lua'
client_script 'client.lua'
server_script 'server.lua'
