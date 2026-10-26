-- ── CONFIG — เปลี่ยนลิงก์นี้ให้ตรงกับ GitHub Repository ของคุณ ────────
local BASE_URL = "https://raw.githubusercontent.com/Therealtobu/Topbar-Plus-For-Executor/main/"
-- ───────────────────────────────────────────────────────────────────────

local function load(path)
	local ok, result = pcall(function()
		local fn = loadstring(game:HttpGet(BASE_URL .. path))
		assert(fn, "Failed to compile: " .. path)
		return fn()
	end)
	if not ok then
		error("[TopbarMinimal] Failed to load module '" .. path .. "': " .. tostring(result), 2)
	end
	return result
end

local _M = {}

-- โหลดโมดูลตามโครงสร้างโฟลเดอร์ที่เราจัดไว้
_M.Signal  = load("Packages/Signal.lua")
_M.Janitor = load("Packages/Janitor.lua")
_M.Utility = load("Utility.lua")
_M.Widget  = load("Elements/Widget.lua")
_M.Icon    = load("Icon.lua")

-- สร้าง Container พื้นฐานสำหรับวางปุ่มไอคอนบนจอเกม
local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local screenGui = playerGui:FindFirstChild("TopbarStandard") or Instance.new("ScreenGui")
screenGui.Name = "TopbarStandard"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = _M.Icon.baseDisplayOrder
screenGui.Parent = playerGui

local holders = screenGui:FindFirstChild("Holders") or Instance.new("Frame")
holders.Name = "Holders"
holders.BackgroundTransparency = 1
holders.Size = UDim2.new(1, 0, 1, 0)
holders.Parent = screenGui

local left = holders:FindFirstChild("Left") or Instance.new("ScrollingFrame")
left.Name = "Left"
left.BackgroundTransparency = 1
left.Size = UDim2.new(1, -24, 1, 0)
left.ScrollingEnabled = false
left.ScrollBarThickness = 0
left.Parent = holders

local layout = left:FindFirstChildOfClass("UIListLayout") or Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
layout.Padding = UDim.new(0, 12)
layout.Parent = left

_M.Icon.container = {
	TopbarStandard = screenGui,
	TopbarCentered = screenGui
}

_M.Icon.baseDisplayOrderChanged:Connect(function(newOrder)
	screenGui.DisplayOrder = newOrder
end)

return _M.Icon

