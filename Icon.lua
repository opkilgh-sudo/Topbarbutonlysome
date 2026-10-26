local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer

local Signal = require(script.Parent.Packages.Signal)
local Janitor = require(script.Parent.Packages.Janitor)
local Utility = require(script.Parent.Utility)
local Widget = require(script.Parent.Elements.Widget)

local Icon = {}
Icon.__index = Icon

local iconsDict = {}
local anyIconSelected = Signal.new()
local totalCreatedIcons = 0

Icon.baseDisplayOrderChanged = Signal.new()
Icon.baseDisplayOrder = 10
Icon.iconsDictionary = iconsDict
Icon.insetHeightChanged = Signal.new()
Icon.topbarEnabled = true
Icon.iconAdded = Signal.new()
Icon.iconRemoved = Signal.new()
Icon.iconChanged = Signal.new()

function Icon.getIcons()
	return Icon.iconsDictionary
end

function Icon.getIconByUID(UID)
	return Icon.iconsDictionary[UID]
end

function Icon.getIcon(nameOrUID)
	local match = Icon.getIconByUID(nameOrUID)
	if match then
		return match
	end
	for _, icon in pairs(iconsDict) do
		if icon.name == nameOrUID then
			return icon
		end
	end
	return nil
end

function Icon.setTopbarEnabled(bool)
	if typeof(bool) ~= "boolean" then
		bool = Icon.topbarEnabled
	end
	Icon.topbarEnabled = bool
	if Icon.container then
		for _, screenGui in pairs(Icon.container) do
			screenGui.Enabled = bool
		end
	end
end

function Icon.setDisplayOrder(int)
	Icon.baseDisplayOrder = int
	Icon.baseDisplayOrderChanged:Fire(int)
end

function Icon.new()
	local self = {}
	setmetatable(self, Icon)

	local janitor = Janitor.new()
	self.janitor = janitor
	self.singleClickJanitor = janitor:Add(Janitor.new())

	local iconUID = Utility.generateUID()
	iconsDict[iconUID] = self
	janitor:Add(function()
		iconsDict[iconUID] = nil
	end)

	self.selected = janitor:Add(Signal.new())
	self.deselected = janitor:Add(Signal.new())
	self.toggled = janitor:Add(Signal.new())
	self.stateChanged = janitor:Add(Signal.new())
	self.alignmentChanged = janitor:Add(Signal.new())
	self.updateSize = janitor:Add(Signal.new())
	self.resizingComplete = janitor:Add(Signal.new())

	self.UID = iconUID
	self.isEnabled = true
	self.enabled = self.isEnabled
	self.isSelected = false
	self.isViewing = false
	self.joinedFrame = false
	self.parentIconUID = false
	self.deselectWhenOtherIconSelected = true
	self.activeState = "Deselected"
	self.alignment = ""
	self.originalAlignment = ""
	self.cachedInstances = {}
	self.cachedNamesToInstances = {}
	self.cachedCollectives = {}
	self.bindedToggleKeys = {}
	self.customBehaviours = {}
	self.toggleItems = {}
	self.bindedEvents = {}
	self.creationTime = os.clock()

	local widget = janitor:Add(Widget(self, Icon))
	self.widget = widget
	self:setAlignment("Left")
	
	totalCreatedIcons += 1
	local ourOrder = 1 + (totalCreatedIcons * 0.01)
	self:setOrder(ourOrder)

	local clickRegion = self:getInstance("ClickRegion")
	local hasUsedMouseButton1Click = false
	local lastToggleTime = 0
	local DEBOUNCE_TIME = 0.1

	local function handleToggle()
		if self.locked then
			return
		end
		local currentTime = tick()
		if currentTime - lastToggleTime < DEBOUNCE_TIME then
			return
		end
		lastToggleTime = currentTime

		if self.isSelected then
			self:deselect("User", self)
		else
			self:select("User", self)
		end
	end

	clickRegion.MouseButton1Click:Connect(function()
		hasUsedMouseButton1Click = true
		handleToggle()
	end)

	clickRegion.TouchTap:Connect(function()
		if not hasUsedMouseButton1Click then
			handleToggle()
		end
	end)

	janitor:Add(UserInputService.InputBegan:Connect(function(input, touchingAnObject)
		if self.locked then
			return
		end
		if self.bindedToggleKeys[input.KeyCode] and not touchingAnObject then
			handleToggle()
		end
	end))

	janitor:Add(anyIconSelected:Connect(function(incomingIcon)
		if incomingIcon ~= self and self.deselectWhenOtherIconSelected and incomingIcon.deselectWhenOtherIconSelected then
			self:deselect("AutoDeselect", incomingIcon)
		end
	end))

	Icon.iconAdded:Fire(self)
	return self
end

function Icon:setName(name)
	self.widget.Name = name
	self.name = name
	return self
end

function Icon:setState(incomingStateName, fromSource, sourceIcon)
	if not incomingStateName then
		incomingStateName = (self.isSelected and "Selected") or "Deselected"
	end
	local stateName = Utility.formatStateName(incomingStateName)
	local previousStateName = self.activeState
	if previousStateName == stateName then
		return
	end
	local currentIsSelected = self.isSelected
	self.activeState = stateName
	if stateName == "Deselected" then
		self.isSelected = false
		if currentIsSelected then
			self.toggled:Fire(false, fromSource, sourceIcon)
			self.deselected:Fire(fromSource, sourceIcon)
		end
		self:_setToggleItemsVisible(false, fromSource, sourceIcon)
	elseif stateName == "Selected" then
		self.isSelected = true
		if not currentIsSelected then
			self.toggled:Fire(true, fromSource, sourceIcon)
			self.selected:Fire(fromSource, sourceIcon)
			anyIconSelected:Fire(self, fromSource, sourceIcon)
		end
		self:_setToggleItemsVisible(true, fromSource, sourceIcon)
	end
	self.stateChanged:Fire(stateName, fromSource, sourceIcon)
end

function Icon:getInstance(name)
	local instance = self.cachedNamesToInstances[name]
	if instance then
		return instance
	end
	local function cacheInstance(childName, child)
		if not self.cachedInstances[child] then
			local collectiveName = child:GetAttribute("Collective")
			if collectiveName and self.cachedCollectives[collectiveName] then
				table.insert(self.cachedCollectives[collectiveName], child)
			end
			self.cachedNamesToInstances[childName] = child
			self.cachedInstances[child] = true
			child.Destroying:Once(function()
				self.cachedNamesToInstances[childName] = nil
				self.cachedInstances[child] = nil
			end)
		end
	end
	local widget = self.widget
	if name == "Widget" then
		return widget
	end

	local returnChild
	local function scanChildren(parentInstance)
		for _, child in pairs(parentInstance:GetChildren()) do
			local widgetUID = child:GetAttribute("WidgetUID")
			if widgetUID and widgetUID ~= self.UID then
				continue
			end
			scanChildren(child)
			if child:IsA("GuiBase") or child:IsA("UIBase") or child:IsA("ValueBase") then
				local childName = child.Name
				cacheInstance(childName, child)
				if childName == name then
					returnChild = child
				end
			end
		end
	end
	scanChildren(widget)
	return returnChild
end

function Icon:refresh()
	self.updateSize:Fire()
	return self
end

function Icon:updateParent()
	local parentIcon = Icon.getIconByUID(self.parentIconUID)
	if parentIcon then
		parentIcon.updateSize:Fire()
	end
end

function Icon:setEnabled(bool)
	self.isEnabled = bool
	self.enabled = self.isEnabled
	self.widget.Visible = bool
	self:updateParent()
	return self
end

function Icon:select(fromSource, sourceIcon)
	self:setState("Selected", fromSource, sourceIcon)
	return self
end

function Icon:deselect(fromSource, sourceIcon)
	self:setState("Deselected", fromSource, sourceIcon)
	return self
end

function Icon:setImage(imageId)
	local assetId = (tonumber(imageId)) and ("rbxassetid://" .. tostring(imageId)) or tostring(imageId)
	local img = self:getInstance("IconImage")
	if img then
		img.Image = assetId
	end
	return self
end

function Icon:setLabel(text)
	local lbl = self:getInstance("IconLabel")
	if lbl then
		lbl.Text = tostring(text or "")
	end
	return self
end

function Icon:setOrder(int)
	local newInt = int * 100
	local spot = self:getInstance("IconSpot")
	if spot then spot.LayoutOrder = newInt end
	local w = self:getInstance("Widget")
	if w then w.LayoutOrder = newInt end
	return self
end

function Icon:align(leftCenterOrRight)
	local direction = tostring(leftCenterOrRight):lower()
	if direction == "mid" or direction == "centre" then
		direction = "center"
	end
	if direction ~= "left" and direction ~= "center" and direction ~= "right" then
		direction = "left"
	end
	self.originalAlignment = string.upper(string.sub(direction, 1, 1)) .. string.sub(direction, 2)
	self.alignment = self.originalAlignment
	self.alignmentChanged:Fire(self.alignment)
	Icon.iconChanged:Fire(self)
	return self
end
Icon.setAlignment = Icon.align

function Icon:setLeft()
	return self:setAlignment("Left")
end

function Icon:setMid()
	return self:setAlignment("Center")
end

function Icon:setRight()
	return self:setAlignment("Right")
end

function Icon:bindToggleItem(guiObjectOrLayerCollector)
	if not guiObjectOrLayerCollector:IsA("GuiObject") and not guiObjectOrLayerCollector:IsA("LayerCollector") then
		error("Toggle item must be a GuiObject or LayerCollector!")
	end
	self.toggleItems[guiObjectOrLayerCollector] = true
	return self
end

function Icon:unbindToggleItem(guiObjectOrLayerCollector)
	self.toggleItems[guiObjectOrLayerCollector] = nil
	return self
end

function Icon:_setToggleItemsVisible(bool, fromSource, sourceIcon)
	for toggleItem, _ in pairs(self.toggleItems) do
		if not sourceIcon or sourceIcon == self or sourceIcon.toggleItems[toggleItem] == nil then
			local property = "Visible"
			if toggleItem:IsA("LayerCollector") then
				property = "Enabled"
			end
			toggleItem[property] = bool
		end
	end
end

function Icon:bindEvent(iconEventName, eventFunction)
	local event = self[iconEventName]
	assert(event and typeof(event) == "table" and event.Connect, "argument[1] must be a valid icon event name!")
	assert(typeof(eventFunction) == "function", "argument[2] must be a function!")
	self.bindedEvents[iconEventName] = event:Connect(function(...)
		eventFunction(self, ...)
	end)
	return self
end

function Icon:unbindEvent(iconEventName)
	local eventConnection = self.bindedEvents[iconEventName]
	if eventConnection then
		eventConnection:Disconnect()
		self.bindedEvents[iconEventName] = nil
	end
	return self
end

function Icon:bindToggleKey(keyCodeEnum)
	assert(typeof(keyCodeEnum) == "EnumItem", "argument[1] must be a KeyCode EnumItem!")
	self.bindedToggleKeys[keyCodeEnum] = true
	return self
end

function Icon:unbindToggleKey(keyCodeEnum)
	assert(typeof(keyCodeEnum) == "EnumItem", "argument[1] must be a KeyCode EnumItem!")
	self.bindedToggleKeys[keyCodeEnum] = nil
	return self
end

function Icon:call(callback, ...)
	local packedArgs = table.pack(...)
	task.spawn(function()
		callback(self, table.unpack(packedArgs))
	end)
	return self
end

function Icon:addToJanitor(callback, methodName, index)
	self.janitor:Add(callback, methodName, index)
	return self
end

function Icon:lock()
	local clickRegion = self:getInstance("ClickRegion")
	if clickRegion then clickRegion.Visible = false end
	self.locked = true
	return self
end

function Icon:unlock()
	local clickRegion = self:getInstance("ClickRegion")
	if clickRegion then clickRegion.Visible = true end
	self.locked = false
	return self
end

function Icon:debounce(seconds)
	self:lock()
	task.wait(seconds)
	self:unlock()
	return self
end

function Icon:autoDeselect(bool)
	if bool == nil then
		bool = true
	end
	self.deselectWhenOtherIconSelected = bool
	return self
end

function Icon:oneClick(bool)
	local singleClickJanitor = self.singleClickJanitor
	singleClickJanitor:Cleanup()
	if bool or bool == nil then
		singleClickJanitor:Add(self.selected:Connect(function()
			self:deselect("OneClick", self)
		end))
	end
	self.oneClickEnabled = true
	return self
end

function Icon:destroy()
	if self.isDestroyed then
		return
	end
	self.isDestroyed = true
	self.janitor:Cleanup()
	Icon.iconRemoved:Fire(self)
end
Icon.Destroy = Icon.destroy

return Icon

