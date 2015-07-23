require("helpers.coroutine_helpers")

actor_system = {
	actors = {},
	actor_classes = {}
}

function actor_system:Init()
	self.has_initialised = true
end

function actor_system:Save()
	global.actors = self.actors
end

function actor_system:_afterLoad()
	for _, actor in ipairs(self.actors) do
		if actor.OnLoad then
			actor:OnLoad()
		end
	end
end

function actor_system:Load()
	if not self.has_initialised then
		if global.actors then
			for i, glob_actor in ipairs(global.actors) do
				if glob_actor.className and ((glob_actor.entity and glob_actor.entity.valid) or (not glob_actor.entity)) then
					local class = _ENV[glob_actor.className]
					local actor = class.CreateActor(glob_actor)
					table.insert(self.actors, actor)
				end
			end
		end

		-- defer the loading of actors, so that we aren't changing game state here.
		StartCoroutine(function()
			WaitForTicks(1*SECONDS)
			self:_afterLoad()
		end)

		self.has_initialised = true
	end
end

function actor_system:Tick()
	for i = 1, #self.actors do
		local actor = self.actors[i]
		if actor.OnTick then
			actor:OnTick()
		end
	end
end

function actor_system:OnEntityDestroy( entity )
	for i=1, #self.actors do
		local actor = self.actors[i]
		if actor and actor.entity and actor.entity == entity then
			table.remove(self.actors, i)
			if actor.OnDestroy then
				actor:OnDestroy()
			end
			return
		end
	end
end

function actor_system:OnEntityCreate( entity )
	for index, class in ipairs(self.actor_classes) do
		if class.entity_type and class.entity_type == entity.name then
			self:AddActor( class.CreateActor{entity = entity} )
			return
		end
	end
end

function actor_system:AddActor( actor )
	table.insert(self.actors, actor)
	if actor.Init then
		actor:Init()
	end
	return actor
end


function ActorClass( name, class )
	_ENV[name] = class
	class.className = name
	class.CreateActor = function(existing) 
		local actor = existing or {}
		actor.className = name
		setmetatable(actor, {__index = class})
		return actor
	end
	table.insert(actor_system.actor_classes, class)
	return class
end