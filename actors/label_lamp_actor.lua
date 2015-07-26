local static_gui = {}
local next_uid = 0
local lamp_count = 0

ActorClass("LabelLamp",{
	entity_type = "label_lamp",
	do_alert = true
})

function LabelLamp.Save()
	global.label_lamp_static_gui = static_gui
	global.label_lamp_next_uid = next_uid
	global.label_lamp_count = lamp_count
end

function LabelLamp.Load()
	static_gui = global.label_lamp_static_gui
	next_uid = global.label_lamp_next_uid or 1
	lamp_count = global.label_lamp_count or 0
end

function LabelLamp:InitStaticGUI()
	if static_gui == nil then
		static_gui = {}
	end
	for playerIndex = 1, #game.players do
		local player = game.players[playerIndex]
		if static_gui[playerIndex] and not player.gui.top.circuit_gui then
			static_gui[playerIndex] = nil
		end
		if player.gui.top.circuit_gui then
			static_gui[playerIndex] = player.gui.top.circuit_gui
		else
			if (player.force == self.entity.force) and (not static_gui[playerIndex]) then
				GUI.PushParent(player.gui.top)
				static_gui[playerIndex] = GUI.PushParent(GUI.Frame("circuit_gui", "Circuit Network", GUI.VERTICAL))
				GUI.PushParent(GUI.Flow("flow", GUI.VERTICAL))
				GUI.PopAll()
			end
		end
	end
end

function LabelLamp:Init()
	self.gui = {}
	self.help_gui = {}
	self.message = ""
	self.uid = next_uid
	next_uid = next_uid + 1
	self:InitStaticGUI()
	lamp_count = lamp_count + 1
end

function LabelLamp:OnLoad()
	if static_gui == nil then
		self:InitStaticGUI()
	end
end

function LabelLamp:OnDestroy()
	lamp_count = lamp_count - 1
	for playerIndex = 1, #game.players do
		self:CloseGUI(playerIndex)
	end
	if self.message_is_showing then
		self:HideMessage()
	end
	if lamp_count == 0 then
		for playerIndex = 1, #game.players do
			local player = game.players[playerIndex]
			if player.gui.top.circuit_gui then
				player.gui.top.circuit_gui.destroy()
				static_gui[playerIndex] = nil
			end
		end
	end
end

function LabelLamp:LabelID()
	return "label_"..self.uid
end

function LabelLamp:GetStaticFrame( playerIndex )
	if static_gui[playerIndex] then
		return static_gui[playerIndex].flow
	else
		return nil
	end
end

function LabelLamp:SetStaticLabelCaption( playerIndex, caption )
	local frame = self:GetStaticFrame(playerIndex)
	local labelID = self:LabelID()
	if frame and frame[labelID] then
		frame[labelID].caption = caption
		return true
	else
		return false
	end
end

function LabelLamp:OnTick()
	if not self.entity.valid then
		return
	end

	-- Open GUI if a player get's near.
	if ModuloTimer(2 * SECONDS) then
		for playerIndex = 1, #game.players do
			local player = game.players[playerIndex]
			local distance = util.distance(player.position, self.entity.position)
			if distance < 2 then
				self:OpenGUI(playerIndex)
			else
				self:CloseGUI(playerIndex)
			end
		end

		if self.message_is_set and self.entity.energy > 1 then
			local condition = self.entity.get_circuit_condition(1)
			if condition.fulfilled and not self.message_is_showing then
				self:ShowMessage()
			elseif not condition.fulfilled and self.message_is_showing then
				self:HideMessage()
			end
		end
	end

	-- update message
	if ModuloTimer(2 * SECONDS) then
		local msg = self:ParseMessage(self.message)

		for playerIndex = 1, #game.players do
			if self.gui[playerIndex] then
				local inputText = self.gui[playerIndex].flow.input.text
				self.message = inputText
				self.message_is_set = (self.message and (self.message ~= ""))
			end

			if self.message_is_showing then
				if self.message_is_set then
					self:SetStaticLabelCaption(playerIndex, msg)
				else
					self:HideMessage()
				end
			end
		end
	end
end

local function _getPlayTime()
	local time = game.tick
	return FormatTicksToTime(time)
end

local function _getDayTime()
	return string.format("%.2f", game.daytime)
end

local function _getPollution( entity )
	return entity.surface.get_pollution(entity.position)
end

local function _getEvolution()
	return string.format("$.2d", game.evolution_factor)
end

local function _getResearch( force )
	return string.format("%.2f%%", force.research_progress)
end

local function _getLocation( entity )
	return string.format("[%.1d, %.1d]", entity.position.x, entity.position.y)
end

function LabelLamp:ParseMessage( msg )
	-- $A = first_signal
	-- $B = second_signal
	-- $C = comparitor
	-- {itemname} = count item name in nearby chests.
	-- $T = Play Time.
	-- $D = Day Time.
	-- $E = Evolution factor.
	-- $P = Pollution.
	-- $R = research.
	-- $L = location.
	-- $S = game speed.
	local first_signal = ""
	local second_signal = ""
	local comparator = ""

	local condition = self.entity.get_circuit_condition(1)
	if condition then
		if condition.condition.comparator then
			comparator = tostring(condition.condition.comparator)
		end
		if condition.condition.first_signal then
			first_signal = condition.condition.first_signal.name
		end
		if condition.condition.second_signal then
			second_signal = condition.condition.second_signal.name
		elseif condition.condition.constant then
			second_signal = tostring(condition.condition.constant)
		end
	end

	local items = {}
	local has_item_tags = false
	for itemWord in string.gmatch(msg, "{(.-)}") do
		if not items[itemWord] and game.item_prototypes[itemWord] then
			items[itemWord] = {name = itemWord, count = 0}
			has_item_tags = true
		end
	end

	if has_item_tags then
		local area = SquareArea(self.entity.position, 2)
		local chests = self.entity.surface.find_entities_filtered{name = "smart-chest", area = area}
		for _, chest in ipairs(chests) do
			for itemName, itemData in pairs(items) do
				itemData.count = itemData.count + chest.get_item_count(itemName)
			end
		end

		msg = string.gsub(msg, "{(.-)}", function(match)
			return string.format("[%s x%i]", match, items[match].count)
		end)
	end

	local subs = {
		["$A"] = first_signal,
		["$B"] = second_signal,
		["$C"] = comparator,
		["$T"] = _getPlayTime(),
		["$D"] = _getDayTime(),
		["$P"] = _getPollution(self.entity),
		["$E"] = _getEvolution(),
		["$R"] = _getResearch(self.entity.force),
		["$L"] = _getLocation(self.entity),
		["$S"] = game.speed
	}

	msg = string.gsub(msg, "($%u)", function(match)
		local result = subs[match]
		if result then
			return result
		else
			return match
		end
	end)

	--msg = string.gsub(msg, "($A)", first_signal or "")
	--msg = string.gsub(msg, "($B)", second_signal or "")
	--msg = string.gsub(msg, "($C)", comparator or "")
	--msg = string.gsub(msg, "()")

	return msg
end

function LabelLamp:ShowMessage()
	local msg = self:ParseMessage(self.message)

	for playerIndex = 1, #game.players do
		local player = game.players[playerIndex]
		local frame = self:GetStaticFrame(playerIndex)
		if self.entity.force == player.force and frame then
			local labelID = self:LabelID()
			if frame[labelID] then
				frame[labelID].destroy()
			end
			GUI.PushParent(frame)
			GUI.Label(labelID, msg)
			GUI.PopParent()
			self.message_is_showing = true
			if self.do_alert then
				player.print(msg)
			end
		end
	end
end

function LabelLamp:HideMessage()
	for playerIndex = 1, #game.players do
		local player = game.players[playerIndex]
		local frame = self:GetStaticFrame(playerIndex)
		if self.entity.force == player.force and frame then
			frame[self:LabelID()].destroy()
			self.message_is_showing = false
		end
	end
end

function LabelLamp:OpenGUI( playerIndex )
	if self.gui[playerIndex] then
		return 
	end

	GUI.PushLeftSection(playerIndex)
	self.gui[playerIndex] = GUI.PushParent(GUI.Frame("labellamp_"..self.uid, "Set Message", GUI.HORIZONTAL))
	GUI.Button("help", "?", "ToggleHelpGUI", self)
	GUI.PushParent(GUI.Flow("flow", GUI.VERTICAL))
	
	
	local textInput = GUI.TextField("input", self.message)
	textInput.text = self.message
	GUI.Checkbox("alert_checkbox", "Alert", self.do_alert, "OnAlertCheckboxClick", self)
	GUI.PopAll()
end

function LabelLamp:CloseGUI( playerIndex )
	if self.help_gui[playerIndex] then
		self.help_gui[playerIndex].destroy()
		self.help_gui[playerIndex] = nil
	end

	if self.gui[playerIndex] then
		self.gui[playerIndex].destroy()
		self.gui[playerIndex] = nil
	end
end

function LabelLamp:ToggleHelpGUI( event )
	local helpGui = self.help_gui[event.player_index]
	if helpGui then
		helpGui.destroy()
		self.help_gui[event.player_index] = nil
		return 
	end

	GUI.PushLeftSection(event.player_index)
	self.help_gui[event.player_index] = GUI.PushParent(GUI.Frame("labellamp_help_"..self.uid, "Help", GUI.VERTICAL))
	GUI.PushParent(GUI.Flow("flow", GUI.VERTICAL))
	GUI.Label("info1", "$A = first signal")
	GUI.Label("info2", "$B = second signal")
	GUI.Label("info3", "$C = comparator")
	GUI.Label("info4", "$T = play time")
	GUI.Label("info5", "$D = day time")
	GUI.Label("info6", "$E = evolution factor")
	GUI.Label("info7", "$P = pollution")
	GUI.Label("info8", "$R = research progress")
	GUI.Label("info9", "$L = location")
	GUI.Label("info10", "$S = game speed")
	GUI.Label("info11", "{item-name} = count items in nearby smart chests")
	GUI.PopAll()
end

function LabelLamp:OnAlertCheckboxClick( event, args )
	self.do_alert = event.element.state
end
