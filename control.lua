SECONDS = 60
MINUTES = 3600
GAME_DAY = 25000

require("defines")
require("util")
require("actor_system")
require("helpers.helpers")
require("helpers.gui_helpers")
require("helpers.coroutine_helpers")
require("actors.label_lamp_actor")


local function OnGameInit()
	modHasInitialised = true
	actor_system:Init()
end

local function OnGameLoad()
	actor_system:Load()
	LabelLamp.Load()
	if global.guiButtonCallbacks then
		GUI.buttonCallbacks = global.guiButtonCallbacks
	end
end

local function OnGameSave()
	actor_system:Save()
	LabelLamp.Save()
	global.guiButtonCallbacks = GUI.buttonCallbacks
end

local function OnPlayerCreated( player_index )
end

local function OnPlayerBuiltEntity( entity )
	actor_system:OnEntityCreate(entity)
end

local function OnEntityDestroy( entity )
	actor_system:OnEntityDestroy(entity)
end

local function OnTick()
	ResumeRoutines()
	actor_system:Tick()
end


game.on_init(OnGameInit)
game.on_load(OnGameLoad)
game.on_save(OnGameSave)
game.on_event(defines.events.on_built_entity, function(event) OnPlayerBuiltEntity(event.created_entity) end)
game.on_event(defines.events.on_entity_died, function(event) OnEntityDestroy(event.entity) end)
game.on_event(defines.events.on_preplayer_mined_item, function(event) OnEntityDestroy(event.entity) end)
game.on_event(defines.events.on_robot_pre_mined, function(event) OnEntityDestroy(event.entity) end)
game.on_event(defines.events.on_player_created, function(event) OnPlayerCreated(event.player_index) end)
game.on_event(defines.events.on_tick, OnTick)