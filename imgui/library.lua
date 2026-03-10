local ImGui = {
	Animations = {
		Buttons = {
			MouseEnter = { BackgroundTransparency = 0.45 },
			MouseLeave = { BackgroundTransparency = 0.72 }
		},
		Tabs = {
			MouseEnter = { BackgroundTransparency = 0.45 },
			MouseLeave = { BackgroundTransparency = 1 }
		},
		Inputs = {
			MouseEnter = { BackgroundTransparency = 0 },
			MouseLeave = { BackgroundTransparency = 0.5 }
		},
		WindowBorder = {
			Selected   = { Transparency = 0,   Thickness = 1 },
			Deselected = { Transparency = 0.7, Thickness = 1 }
		}
	},

	Windows    = {},
	Animation  = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	UIAssetId  = "rbxassetid://76246418997296",
	NoWarnings = true,
}

local NullFn   = function() end
local CloneRef = cloneref or function(x) return x end

local function GetService(name)
	return CloneRef(game:GetService(name))
end

local TweenService     = GetService("TweenService")
local UserInputService = GetService("UserInputService")
local Players          = GetService("Players")
local CoreGui          = GetService("CoreGui")
local RunService       = GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui   = LocalPlayer.PlayerGui
local Mouse       = LocalPlayer:GetMouse()
local IsStudio    = RunService:IsStudio()

ImGui.NoWarnings = not IsStudio

function ImGui:Warn(...)
	if self.NoWarnings then return end
	warn("[ImGui]", ...)
end

function ImGui:FetchUI()
	local key = "DepsoImGui"
	if _G[key] then
		self:Warn("Prefabs loaded from cache")
		return _G[key]
	end

	local ui
	if IsStudio then
		ui = PlayerGui:FindFirstChild(key) or script.DepsoImGui
	else
		ui = game:GetObjects(ImGui.UIAssetId)[1]
	end

	_G[key] = ui
	return ui
end

local UI      = ImGui:FetchUI()
local Prefabs = UI.Prefabs
ImGui.Prefabs = Prefabs
Prefabs.Visible = false

local StyleHandlers = {
	[{ Name = "Border" }] = function(obj, val, cls)
		local stroke = obj:FindFirstChildOfClass("UIStroke")
		if not stroke then return end
		if cls.BorderThickness then stroke.Thickness = cls.BorderThickness end
		stroke.Enabled = val
	end,

	[{ Name = "Ratio" }] = function(obj, val, cls)
		local ratio = obj:FindFirstChildOfClass("UIAspectRatioConstraint")
			or ImGui:CreateInstance("UIAspectRatioConstraint", obj)
		ratio.DominantAxis = Enum.DominantAxis[cls.RatioAxis or "Height"]
		ratio.AspectType   = cls.AspectType or Enum.AspectType.ScaleWithParentSize
		ratio.AspectRatio  = cls.Ratio or (4/3)
	end,

	[{ Name = "CornerRadius", Recursive = true }] = function(obj, val, cls)
		local corner = obj:FindFirstChildOfClass("UICorner")
			or ImGui:CreateInstance("UICorner", obj)
		corner.CornerRadius = cls.CornerRadius
	end,

	[{ Name = "Label" }] = function(obj, val, cls)
		local lbl = obj:FindFirstChild("Label")
		if not lbl then return end
		lbl.Text = cls.Label
		function cls:SetLabel(text)
			lbl.Text = text
			return cls
		end
	end,

	[{ Name = "NoGradient", Aliases = { "NoGradientAll" }, Recursive = true }] = function(obj, val)
		local grad = obj:FindFirstChildOfClass("UIGradient")
		if grad then grad.Enabled = not val end
	end,

	[{ Name = "Callback" }] = function(obj, val, cls)
		function cls:SetCallback(fn) cls.Callback = fn; return cls end
		function cls:FireCallback()   return cls.Callback(obj) end
	end,

	[{ Name = "Value" }] = function(obj, val, cls)
		function cls:GetValue() return cls.Value end
	end,
}

function ImGui:GetName(name)
	return name .. "_"
end

function ImGui:CreateInstance(class, parent, props)
	local inst = Instance.new(class)
	inst.Parent = parent
	for k, v in next, props or {} do
		inst[k] = v
	end
	return inst
end

function ImGui:ApplyColors(overrides, obj, elemType)
	for info, val in next, overrides do
		local key       = typeof(info) == "table" and (info.Name or "") or info
		local recursive = typeof(info) == "table" and info.Recursive or false

		if typeof(val) == "table" then
			local child = obj:FindFirstChild(key, recursive)
			if not child and elemType == "Window" then
				child = obj.Content:FindFirstChild(key, recursive)
			end
			if child then
				ImGui:ApplyColors(val, child)
			end
			continue
		end

		obj[key] = val
	end
end

function ImGui:CheckStyles(obj, cls, colors)
	for info, handler in next, StyleHandlers do
		local val = cls[info.Name]
		if val == nil and info.Aliases then
			for _, alias in info.Aliases do
				val = cls[alias]
				if val ~= nil then break end
			end
		end
		if val == nil then continue end

		handler(obj, val, cls)
		if info.Recursive then
			for _, child in obj:GetChildren() do
				handler(child, val, cls)
			end
		end
	end

	local elemType = obj.Name
	obj.Name = self:GetName(elemType)

	local overrides = (colors or {})[elemType]
	if overrides then
		ImGui:ApplyColors(overrides, obj, elemType)
	end

	for k, v in next, cls do
		pcall(function() obj[k] = v end)
	end
end

function ImGui:MergeMetatables(cls, inst)
	return setmetatable({}, {
		__index = function(_, key)
			local ok, val = pcall(function()
				local v = inst[key]
				if typeof(v) == "function" then
					return function(...) return v(inst, ...) end
				end
				return v
			end)
			return ok and val or cls[key]
		end,
		__newindex = function(_, key, val)
			if cls[key] ~= nil or typeof(val) == "function" then
				cls[key] = val
			else
				inst[key] = val
			end
		end
	})
end

function ImGui:Concat(tbl, sep)
	local parts = {}
	for _, v in ipairs(tbl) do
		parts[#parts + 1] = tostring(v)
	end
	return table.concat(parts, sep or " ")
end

function ImGui:Tween(inst, props, info, noAnim)
	local ti = info or (noAnim and TweenInfo.new(0) or self.Animation)
	local t  = TweenService:Create(inst, ti, props)
	t:Play()
	return t
end

function ImGui:GetAnimation(animate)
	return animate and self.Animation or TweenInfo.new(0)
end

function ImGui:ApplyAnimations(inst, class, target)
	local colorProps = self.Animations[class]
	if not colorProps then
		warn("[ImGui] No animation class:", class)
		return
	end

	local connections = {}
	for event, props in next, colorProps do
		if typeof(props) ~= "table" then continue end
		local dest = target or inst
		local fn   = function() ImGui:Tween(dest, props) end
		connections[event] = fn
		inst[event]:Connect(fn)
	end

	if connections["MouseLeave"] then
		connections["MouseLeave"]()
	end

	return connections
end

function ImGui:HeaderAnimate(header, animate, open, titleBar, toggle)
	local btn = toggle or titleBar.Toggle.ToggleButton

	ImGui:Tween(btn, { Rotation = open and 90 or 0 })

	local container = header:FindFirstChild("ChildContainer")
	if not container then return end

	local layout    = container.UIListLayout
	local padding   = container:FindFirstChildOfClass("UIPadding")
	local content   = layout.AbsoluteContentSize

	if padding then
		local py = padding.PaddingTop.Offset + padding.PaddingBottom.Offset
		content  = Vector2.new(content.X, content.Y + py)
	end

	container.AutomaticSize = Enum.AutomaticSize.None

	if not open then
		container.Size = UDim2.new(1, -10, 0, content.Y)
	end

	local tween = ImGui:Tween(container, {
		Size    = UDim2.new(1, -10, 0, open and content.Y or 0),
		Visible = open,
	})

	tween.Completed:Connect(function()
		if not open then return end
		container.AutomaticSize = Enum.AutomaticSize.Y
		container.Size          = UDim2.new(1, -10, 0, 0)
	end)
end

function ImGui:ConnectHover(config)
	local parent      = config.Parent
	local connections = {}
	config.Hovering   = false

	local function addConn(signal, fn)
		connections[#connections + 1] = signal:Connect(fn)
	end

	addConn(parent.MouseEnter, function() config.Hovering = true end)
	addConn(parent.MouseLeave, function() config.Hovering = false end)

	if config.OnInput then
		addConn(UserInputService.InputBegan, function(input)
			config.OnInput(config.Hovering, input)
		end)
	end

	function config:Disconnect()
		for _, c in connections do c:Disconnect() end
	end

	return config
end

function ImGui:ApplyDraggable(frame, header)
	header = header or frame

	local dragging   = false
	local startInput = nil
	local startPos   = frame.Position

	local allowed = {
		Enum.UserInputType.MouseButton1,
		Enum.UserInputType.Touch,
	}

	header.InputBegan:Connect(function(input)
		if not table.find(allowed, input.UserInputType) then return end
		dragging   = true
		startInput = input.Position
		startPos   = frame.Position
	end)

	UserInputService.InputEnded:Connect(function(input)
		if table.find(allowed, input.UserInputType) then
			dragging = false
		end
	end)

	local function onMove(input)
		if not dragging then return end
		local delta = input.Position - startInput
		ImGui:Tween(frame, {
			Position = UDim2.new(
				startPos.X.Scale,  startPos.X.Offset + delta.X,
				startPos.Y.Scale,  startPos.Y.Offset + delta.Y
			)
		})
	end

	UserInputService.TouchMoved:Connect(onMove)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			onMove(input)
		end
	end)
end

function ImGui:ApplyResizable(minSize, frame, dragger, config)
	minSize = minSize or Vector2.new(160, 90)

	local dragStart   = nil
	local originSize  = nil

	dragger.MouseButton1Down:Connect(function()
		if dragStart then return end
		originSize = frame.AbsoluteSize
		dragStart  = Vector2.new(Mouse.X, Mouse.Y)
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragStart or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local delta   = Vector2.new(Mouse.X, Mouse.Y) - dragStart
		local newSize = UDim2.fromOffset(
			math.max(minSize.X, originSize.X + delta.X),
			math.max(minSize.Y, originSize.Y + delta.Y)
		)
		frame.Size = newSize
		if config then config.Size = newSize end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragStart = nil
		end
	end)
end

function ImGui:ApplyWindowSelectEffect(window, titleBar)
	local stroke = window:FindFirstChildOfClass("UIStroke")
	local palette = {
		Selected   = { BackgroundColor3 = titleBar.BackgroundColor3 },
		Deselected = { BackgroundColor3 = Color3.fromRGB(0, 0, 0) },
	}

	self:ConnectHover({
		Parent   = window,
		OnInput  = function(hovering, input)
			if not input.UserInputType.Name:find("Mouse") then return end
			local t = hovering and "Selected" or "Deselected"
			ImGui:Tween(titleBar, palette[t])
			ImGui:Tween(stroke,   ImGui.Animations.WindowBorder[t])
		end,
	})
end

function ImGui:SetWindowProps(props, ignore)
	local mod = { OldProperties = {} }

	for win in next, ImGui.Windows do
		if table.find(ignore, win) then continue end
		local old = {}
		mod.OldProperties[win] = old
		for k, v in next, props do
			old[k]  = win[k]
			win[k]  = v
		end
	end

	function mod:Revert()
		for win in next, ImGui.Windows do
			local old = mod.OldProperties[win]
			if not old then continue end
			for k, v in next, old do win[k] = v end
		end
	end

	return mod
end

function ImGui:Dropdown(config)
	local parent = config.Parent
	if not parent then return end

	local selection = Prefabs.Selection:Clone()
	local stroke    = selection:FindFirstChildOfClass("UIStroke")
	local pad       = stroke.Thickness * 2
	local abPos     = parent.AbsolutePosition
	local abSize    = parent.AbsoluteSize

	selection.Parent   = self.ScreenGui
	selection.Position = UDim2.fromOffset(abPos.X + pad, abPos.Y + abSize.Y)

	local hover = self:ConnectHover({
		Parent  = selection,
		OnInput = function(hovering, input)
			if not input.UserInputType.Name:find("Mouse") then return end
			if not hovering then config:Close() end
		end,
	})

	function config:Close()
		if config.Closed then config.Closed() end
		hover:Disconnect()
		selection:Destroy()
	end

	local template = selection.Template
	template.Visible = false

	for idx, val in next, config.Items do
		local item  = template:Clone()
		local label = tostring(typeof(idx) ~= "number" and idx or val)
		local value = typeof(idx) ~= "number" and idx or val

		item.Text    = label
		item.Parent  = selection
		item.Visible = true
		item.Activated:Connect(function()
			config:Close()
			config:SetValue(value)
		end)
		self:ApplyAnimations(item, "Tabs")
	end

	local maxY  = config.MaxSizeY or 200
	local sizeY = math.clamp(selection.AbsoluteCanvasSize.Y, abSize.Y, maxY)
	selection.Size = UDim2.fromOffset(abSize.X - pad, sizeY)

	return config
end

function ImGui:ContainerClass(frame, cls, windowKey)
	local container   = cls or {}
	local windowCfg   = ImGui.Windows[windowKey]

	function container:NewInstance(inst, icls, parent)
		icls = icls or {}
		inst.Parent  = parent or frame
		inst.Visible = true

		if windowCfg and windowCfg.NoGradientAll then
			icls.NoGradient = true
		end

		local colors = windowCfg and windowCfg.Colors
		ImGui:CheckStyles(inst, icls, colors)

		if icls.NewInstanceCallback then
			icls.NewInstanceCallback(inst)
		end

		return ImGui:MergeMetatables(icls, inst)
	end

	function container:Button(cfg)
		cfg = cfg or {}
		local btn = Prefabs.Button:Clone()
		local obj = self:NewInstance(btn, cfg)
		btn.Activated:Connect(function(...) (cfg.Callback or NullFn)(obj, ...) end)
		ImGui:ApplyAnimations(btn, "Buttons")
		return obj
	end

	function container:Image(cfg)
		cfg = cfg or {}
		if tonumber(cfg.Image) then
			cfg.Image = "rbxassetid://" .. cfg.Image
		end
		local img = Prefabs.Image:Clone()
		local obj = self:NewInstance(img, cfg)
		img.Activated:Connect(function(...) (cfg.Callback or NullFn)(obj, ...) end)
		ImGui:ApplyAnimations(img, "Buttons")
		return obj
	end

	function container:ScrollingBox(cfg)
		cfg = cfg or {}
		local box      = Prefabs.ScrollBox:Clone()
		local boxClass = ImGui:ContainerClass(box, cfg, windowKey)
		return self:NewInstance(box, boxClass)
	end

	function container:Label(cfg)
		cfg = cfg or {}
		return self:NewInstance(Prefabs.Label:Clone(), cfg)
	end

	function container:Checkbox(cfg)
		cfg = cfg or {}
		local isRadio = cfg.IsRadio
		local cb      = Prefabs.CheckBox:Clone()
		local tickbox = cb.Tickbox
		local tick    = tickbox.Tick
		local lbl     = cb.Label
		local obj     = self:NewInstance(cb, cfg)
		local value   = cfg.Value or false

		if isRadio then
			tick.ImageTransparency   = 1
			tick.BackgroundTransparency = 0
		else
			tickbox:FindFirstChildOfClass("UIPadding"):Remove()
			tickbox:FindFirstChildOfClass("UICorner"):Remove()
		end

		ImGui:ApplyAnimations(cb, "Buttons", tickbox)

		local function fire(...)
			return (cfg.Callback or NullFn)(obj, ...)
		end

		function cfg:SetTicked(newVal, instant)
			value     = newVal
			cfg.Value = value
			ImGui:Tween(tick, { Size = value and UDim2.fromScale(1, 1) or UDim2.fromScale(0, 0) }, nil, instant)
			ImGui:Tween(lbl,  { TextTransparency = value and 0 or 0.3 }, nil, instant)
			fire(value)
			return cfg
		end

		function cfg:Toggle()
			return cfg:SetTicked(not value)
		end

		local function clicked()
			cfg:SetTicked(not value)
		end

		cb.Activated:Connect(clicked)
		tickbox.Activated:Connect(clicked)
		cfg:SetTicked(value, true)

		return obj
	end

	function container:RadioButton(cfg)
		cfg = cfg or {}
		cfg.IsRadio = true
		return self:Checkbox(cfg)
	end

	function container:Viewport(cfg)
		cfg = cfg or {}
		local holder     = Prefabs.Viewport:Clone()
		local viewport   = holder.Viewport
		local worldModel = viewport.WorldModel

		cfg.WorldModel = worldModel
		cfg.Viewport   = viewport

		function cfg:SetCamera(cam)
			viewport.CurrentCamera = cam
			cfg.Camera = cam
			cam.CFrame = CFrame.new(0, 0, 0)
			return cfg
		end

		cfg:SetCamera(cfg.Camera or ImGui:CreateInstance("Camera", viewport))

		function cfg:SetModel(model, pivotTo)
			worldModel:ClearAllChildren()
			if cfg.Clone then model = model:Clone() end
			if pivotTo then model:PivotTo(pivotTo) end
			model.Parent = worldModel
			cfg.Model    = model
			return model
		end

		if cfg.Model then cfg:SetModel(cfg.Model) end

		local vc = ImGui:ContainerClass(holder, cfg, windowKey)
		return self:NewInstance(holder, vc)
	end

	function container:InputText(cfg)
		cfg = cfg or {}
		local wrap    = Prefabs.TextInput:Clone()
		local box     = wrap.Input
		local obj     = self:NewInstance(wrap, cfg)

		box.Text            = cfg.Value or ""
		box.PlaceholderText = cfg.PlaceHolder or ""
		box.MultiLine       = cfg.MultiLine == true

		ImGui:ApplyAnimations(wrap, "Inputs")

		box:GetPropertyChangedSignal("Text"):Connect(function()
			cfg.Value = box.Text
			;(cfg.Callback or NullFn)(obj, box.Text)
		end)

		function cfg:SetValue(text)
			box.Text  = tostring(text)
			cfg.Value = text
			return cfg
		end

		function cfg:Clear()
			box.Text = ""
			return cfg
		end

		return obj
	end

	function container:InputTextMultiline(cfg)
		cfg = cfg or {}
		cfg.Label     = ""
		cfg.Size      = UDim2.new(1, 0, 0, 38)
		cfg.MultiLine = true
		return container:InputText(cfg)
	end

	function container:GetRemainingHeight()
		local padding  = frame:FindFirstChildOfClass("UIPadding")
		local layout   = frame:FindFirstChildOfClass("UIListLayout")
		local layoutPad = layout.Padding
		local padTotal  = padding.PaddingTop + padding.PaddingBottom + layoutPad
		local usedY     = frame.AbsoluteSize.Y + padTotal.Offset + 3
		return UDim2.new(1, 0, 1, -usedY)
	end

	function container:Console(cfg)
		cfg = cfg or {}
		local console = Prefabs.Console:Clone()
		local source  = console.Source
		local lines   = console.Lines

		if cfg.Fill then
			console.Size = container:GetRemainingHeight()
		end

		source.TextEditable = cfg.ReadOnly ~= true
		source.Text         = cfg.Text or ""
		source.TextWrapped  = cfg.TextWrapped == true
		source.RichText     = cfg.RichText == true
		lines.Visible       = cfg.LineNumbers == true

		function cfg:UpdateLineNumbers()
			if not cfg.LineNumbers then return end
			local count  = #source.Text:split("\n")
			local fmt    = cfg.LinesFormat or "%s"
			local result = {}
			for i = 1, count do
				result[i] = fmt:format(i)
			end
			lines.Text  = table.concat(result, "\n")
			source.Size = UDim2.new(1, -lines.AbsoluteSize.X, 0, 0)
			return cfg
		end

		function cfg:UpdateScroll()
			console.CanvasPosition = Vector2.new(0, console.AbsoluteCanvasSize.Y)
			return cfg
		end

		function cfg:SetText(text)
			if not cfg.Enabled then return end
			source.Text = text
			cfg:UpdateLineNumbers()
			return cfg
		end

		function cfg:GetValue()
			return source.Text
		end

		function cfg:Clear()
			source.Text = ""
			cfg:UpdateLineNumbers()
			return cfg
		end

		function cfg:AppendText(...)
			if not cfg.Enabled then return end
			local maxLines = cfg.MaxLines or 100
			source.Text ..= "\n" .. ImGui:Concat({...}, " ")
			cfg:UpdateLineNumbers()
			if cfg.AutoScroll then cfg:UpdateScroll() end
			local split = source.Text:split("\n")
			if #split > maxLines then
				source.Text = source.Text:sub(#split[1] + 2)
			end
			return cfg
		end

		source.Changed:Connect(cfg.UpdateLineNumbers)

		return self:NewInstance(console, cfg)
	end

	function container:Table(cfg)
		cfg = cfg or {}
		local tbl          = Prefabs.Table:Clone()
		local baseChildren = #tbl:GetChildren()
		local rowName      = "Row"
		local rowCount     = 0

		if cfg.Fill then
			tbl.Size = container:GetRemainingHeight()
		end

		function cfg:CreateRow()
			local rowClass     = {}
			local row          = tbl.RowTemp:Clone()
			local layout       = row:FindFirstChildOfClass("UIListLayout")
			local baseRowChildren = #row:GetChildren()

			layout.VerticalAlignment = Enum.VerticalAlignment[cfg.Align or "Center"]
			row.Name    = rowName
			row.Visible = true

			if cfg.RowBackground then
				row.BackgroundTransparency = rowCount % 2 == 1 and 0.92 or 1
			end

			function rowClass:CreateColumn(ccfg)
				ccfg = ccfg or {}
				local col    = row.ColumnTemp:Clone()
				col.Visible  = true
				col.Name     = "Column"
				local stroke = col:FindFirstChildOfClass("UIStroke")
				stroke.Enabled = cfg.Border ~= false
				local cc = ImGui:ContainerClass(col, ccfg, windowKey)
				return cc:NewInstance(col, cc, row)
			end

			function rowClass:UpdateColumns()
				if not row or not tbl then return end
				local cols  = row:GetChildren()
				local count = #cols - baseRowChildren
				for _, col in cols do
					if not col:IsA("Frame") then continue end
					col.Size = UDim2.new(1 / count, 0, 0, 0)
				end
				return rowClass
			end

			row.ChildAdded:Connect(rowClass.UpdateColumns)
			row.ChildRemoved:Connect(rowClass.UpdateColumns)

			rowCount += 1
			return container:NewInstance(row, rowClass, tbl)
		end

		function cfg:UpdateRows()
			local children = tbl:GetChildren()
			local padY     = tbl.UIListLayout.Padding.Offset + 2
			local count    = #children - baseChildren
			for _, row in children do
				if not row:IsA("Frame") then continue end
				row.Size = UDim2.new(1, 0, 1 / count, -padY)
			end
			return cfg
		end

		if cfg.RowsFill then
			tbl.AutomaticSize = Enum.AutomaticSize.None
			tbl.ChildAdded:Connect(cfg.UpdateRows)
			tbl.ChildRemoved:Connect(cfg.UpdateRows)
		end

		function cfg:ClearRows()
			rowCount = 0
			local postName = ImGui:GetName(rowName)
			for _, row in tbl:GetChildren() do
				if row:IsA("Frame") and row.Name == postName then
					row:Destroy()
				end
			end
			return cfg
		end

		return self:NewInstance(tbl, cfg)
	end

	function container:Grid(cfg)
		cfg = cfg or {}
		cfg.Grid = true
		return self:Table(cfg)
	end

	function container:CollapsingHeader(cfg)
		cfg = cfg or {}
		local title  = cfg.Title or ""
		cfg.Name     = title

		local header   = Prefabs.CollapsingHeader:Clone()
		local titleBar = header.TitleBar
		local inner    = header.ChildContainer
		titleBar.Title.Text = title

		ImGui:ApplyAnimations(titleBar, cfg.IsTree and "Tabs" or "Buttons")

		function cfg:SetOpen(open)
			cfg.Open = open
			ImGui:HeaderAnimate(header, cfg.NoAnimation ~= true, open, titleBar)
			return cfg
		end

		local toggleBtn = titleBar.Toggle.ToggleButton
		local function toggle()
			cfg:SetOpen(not cfg.Open)
		end

		titleBar.Activated:Connect(toggle)
		toggleBtn.Activated:Connect(toggle)

		if cfg.Image then toggleBtn.Image = cfg.Image end

		cfg:SetOpen(cfg.Open or false)

		local cc = ImGui:ContainerClass(inner, cfg, windowKey)
		return self:NewInstance(header, cc)
	end

	function container:TreeNode(cfg)
		cfg = cfg or {}
		cfg.IsTree = true
		return self:CollapsingHeader(cfg)
	end

	function container:Separator(cfg)
		cfg = cfg or {}
		local sep = Prefabs.SeparatorText:Clone()
		local lbl = sep.TextLabel
		lbl.Text    = cfg.Text or ""
		lbl.Visible = cfg.Text ~= nil
		return self:NewInstance(sep, cfg)
	end

	function container:Row(cfg)
		cfg = cfg or {}
		local row    = Prefabs.Row:Clone()
		local layout = row:FindFirstChildOfClass("UIListLayout")
		local pad    = row:FindFirstChildOfClass("UIPadding")

		if cfg.Spacing then
			layout.Padding = UDim.new(0, cfg.Spacing)
		end

		function cfg:Fill()
			local children = row:GetChildren()
			local count    = #children - 2
			local spacing  = layout.Padding.Offset * 2

			layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			pad.PaddingLeft  = layout.Padding
			pad.PaddingRight = layout.Padding

			for _, child in children do
				local yScale = child:IsA("ImageButton") and 1 or 0
				pcall(function()
					child.Size = UDim2.new(1 / count, -spacing, yScale, 0)
				end)
			end
			return cfg
		end

		local cc = ImGui:ContainerClass(row, cfg, windowKey)
		return self:NewInstance(row, cc)
	end

	function container:Slider(cfg)
		cfg = cfg or {}
		local value     = cfg.Value or 0
		local fmt       = cfg.Format or "%.d"
		local isProgress = cfg.Progress
		cfg.Name        = cfg.Label or ""

		local slider    = Prefabs.Slider:Clone()
		local uiPad     = slider:FindFirstChildOfClass("UIPadding")
		local grab      = slider.Grab
		local valText   = slider.ValueText
		local lbl       = slider.Label

		local dragging   = false
		local moveConn   = nil
		local inputType  = Enum.UserInputType.MouseButton1
		local obj        = self:NewInstance(slider, cfg)

		local function fire(...)
			return (cfg.Callback or NullFn)(obj, ...)
		end

		if isProgress then
			local grad    = grab:FindFirstChildOfClass("UIGradient")
			local padSide = UDim.new(0, 2)
			local diff    = uiPad.PaddingLeft - padSide

			grab.AnchorPoint        = Vector2.new(0, 0.5)
			grad.Enabled            = true
			uiPad.PaddingLeft       = padSide
			uiPad.PaddingRight      = padSide
			lbl.Position            = UDim2.new(1, 15 - diff.Offset, 0, 0)
		end

		function cfg:SetValue(v, fromSlider)
			local min  = cfg.MinValue
			local max  = cfg.MaxValue
			local diff = max - min
			local pct

			if fromSlider then
				pct = v
				v   = min + diff * pct
			else
				v   = tonumber(v)
				pct = (v - min) / diff
			end

			ImGui:Tween(grab, isProgress
				and { Size     = UDim2.fromScale(pct, 1) }
				or  { Position = UDim2.fromScale(pct, 0.5) }
			)

			cfg.Value  = v
			valText.Text = fmt:format(v, max)
			fire(v)
			return cfg
		end

		local function onMove()
			if cfg.ReadOnly or not dragging then return end
			local mouseX = UserInputService:GetMouseLocation().X
			local leftX  = slider.AbsolutePosition.X
			local pct    = math.clamp((mouseX - leftX) / slider.AbsoluteSize.X, 0, 1)
			cfg:SetValue(pct, true)
		end

		UserInputService.InputEnded:Connect(function(input)
			if not dragging or input.UserInputType ~= inputType then return end
			dragging = false
			if moveConn then moveConn:Disconnect() end
		end)

		ImGui:ConnectHover({
			Parent  = slider,
			OnInput = function(hovering, input)
				if not hovering or input.UserInputType ~= inputType then return end
				dragging = true
				moveConn = Mouse.Move:Connect(onMove)
			end,
		})

		slider.Activated:Connect(onMove)
		cfg:SetValue(value)

		return obj
	end

	function container:ProgressSlider(cfg)
		cfg = cfg or {}
		cfg.Progress = true
		return self:Slider(cfg)
	end

	function container:ProgressBar(cfg)
		cfg = cfg or {}
		cfg.Progress  = true
		cfg.ReadOnly  = true
		cfg.MinValue  = 0
		cfg.MaxValue  = 100
		cfg.Format    = "% i%%"
		cfg = self:Slider(cfg)
		function cfg:SetPercentage(v) return cfg:SetValue(v) end
		return cfg
	end

	function container:Keybind(cfg)
		cfg = cfg or {}
		local key      = cfg.Value
		local nullKey  = cfg.NullKey or Enum.KeyCode.Backspace

		local keybind  = Prefabs.Keybind:Clone()
		local valText  = keybind.ValueText
		local obj      = nil

		local function fire(...)
			return (cfg.Callback or NullFn)(obj, ...)
		end

		function cfg:SetValue(newKey)
			if not newKey then return end
			if newKey == nullKey then
				valText.Text = "Not set"
				cfg.Value    = nil
			else
				valText.Text = newKey.Name
				cfg.Value    = newKey
			end
		end

		keybind.Activated:Connect(function()
			valText.Text = "..."
			local input = UserInputService.InputBegan:Wait()
			if not UserInputService.WindowFocused then return end
			local prev = cfg.Value
			if input.KeyCode.Name == "Unknown" then
				return cfg:SetValue(prev)
			end
			task.wait(0.1)
			cfg:SetValue(input.KeyCode)
		end)

		cfg.Connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
			if not cfg.IgnoreGameProcessed and gameProcessed then return end
			if input.KeyCode == nullKey then return end
			if input.KeyCode ~= cfg.Value then return end
			fire(input.KeyCode)
		end)

		cfg:SetValue(key)
		obj = self:NewInstance(keybind, cfg)
		return obj
	end

	function container:Combo(cfg)
		cfg = cfg or {}
		cfg.Open  = false
		cfg.Value = ""

		local combo    = Prefabs.Combo:Clone()
		local toggle   = combo.Toggle.ToggleButton
		local valText  = combo.ValueText
		valText.Text   = cfg.Placeholder or ""

		local dropdown = nil
		local obj      = self:NewInstance(combo, cfg)

		local hoverCfg = ImGui:ConnectHover({ Parent = combo })

		local function fire(v, ...)
			local items    = cfg.Items or {}
			local resolved = items[v]
			cfg.Open       = false
			;(cfg.Callback or NullFn)(obj, resolved or v, ...)
		end

		function cfg:SetValue(v)
			valText.Text = tostring(v)
			cfg.Value    = v
			fire(v)
			return cfg
		end

		function cfg:SetOpen(open)
			ImGui:HeaderAnimate(combo, cfg.NoAnimation ~= true, open, combo, toggle)
			cfg.Open = open

			if open then
				dropdown = ImGui:Dropdown({
					Parent   = combo,
					Items    = cfg.Items or {},
					SetValue = cfg.SetValue,
					Closed   = function()
						if not hoverCfg.Hovering then
							cfg:SetOpen(false)
						end
					end,
				})
			end

			return cfg
		end

		local function toggleOpen()
			if dropdown then dropdown:Close() end
			cfg:SetOpen(not cfg.Open)
		end

		combo.Activated:Connect(toggleOpen)
		toggle.Activated:Connect(toggleOpen)
		ImGui:ApplyAnimations(combo, "Buttons")

		if cfg.Selected then cfg:SetValue(cfg.Selected) end

		return obj
	end

	return container
end

function ImGui:CreateWindow(wcfg)
	local window  = Prefabs.Window:Clone()
	window.Parent  = ImGui.ScreenGui
	window.Visible = true
	wcfg.Window   = window

	local content = window.Content
	local body    = content.Body

	local resize = window.ResizeGrab
	resize.Visible = wcfg.NoResize ~= true
	ImGui:ApplyResizable(wcfg.MinSize or Vector2.new(160, 90), window, resize, wcfg)

	local titleBar = content.TitleBar
	titleBar.Visible = wcfg.NoTitleBar ~= true

	local collapseToggle = titleBar.Left.Toggle
	collapseToggle.Visible = wcfg.NoCollapse ~= true
	ImGui:ApplyAnimations(collapseToggle.ToggleButton, "Tabs")

	local toolbar = content.ToolBar
	toolbar.Visible = wcfg.TabsBar ~= false

	if not wcfg.NoDrag then
		ImGui:ApplyDraggable(window)
	end

	local closeBtn = titleBar.Close
	closeBtn.Visible = wcfg.NoClose ~= true

	function wcfg:Close()
		wcfg:SetVisible(false)
		if wcfg.CloseCallback then wcfg.CloseCallback(wcfg) end
		return wcfg
	end
	closeBtn.Activated:Connect(wcfg.Close)

	function wcfg:GetHeaderSizeY()
		local toolY  = toolbar.Visible  and toolbar.AbsoluteSize.Y  or 0
		local titleY = titleBar.Visible and titleBar.AbsoluteSize.Y or 0
		return toolY + titleY
	end

	function wcfg:UpdateBody()
		body.Size = UDim2.new(1, 0, 1, -self:GetHeaderSizeY())
	end
	wcfg:UpdateBody()

	wcfg.Open = true
	function wcfg:SetOpen(open, instant)
		local abSize   = window.AbsoluteSize
		local titleAbY = titleBar.AbsoluteSize.Y
		self.Open      = open

		ImGui:HeaderAnimate(titleBar, true, open, titleBar, collapseToggle.ToggleButton)
		ImGui:Tween(resize, { TextTransparency = open and 0.6 or 1, Interactable = open }, nil, instant)
		ImGui:Tween(window, { Size = open and self.Size or UDim2.fromOffset(abSize.X, titleAbY) }, nil, instant)
		ImGui:Tween(body,   { Visible = open }, nil, instant)
		return self
	end

	function wcfg:SetVisible(v)
		window.Visible = v
		return self
	end

	function wcfg:SetTitle(text)
		titleBar.Left.Title.Text = tostring(text)
		return self
	end

	function wcfg:SetPosition(pos)
		window.Position = pos
		return self
	end

	function wcfg:SetSize(size)
		local headerY = self:GetHeaderSizeY()
		if typeof(size) == "Vector2" then
			size = UDim2.fromOffset(size.X, size.Y)
		end
		local newSize = UDim2.new(
			size.X.Scale, size.X.Offset,
			size.Y.Scale, size.Y.Offset + headerY
		)
		self.Size     = newSize
		window.Size   = newSize
		return self
	end

	function wcfg:Remove()
		window:Destroy()
		return self
	end

	function wcfg:Center()
		local sz  = window.AbsoluteSize
		self:SetPosition(UDim2.new(0.5, -sz.X / 2, 0.5, -sz.Y / 2))
		return self
	end

	function wcfg:ShowTab(tabCls)
		local target = tabCls.Content
		if not target.Visible and not tabCls.NoAnimation then
			target.Position = UDim2.fromOffset(0, 6)
		end
		for _, page in body:GetChildren() do
			page.Visible = (page == target)
		end
		ImGui:Tween(target, { Position = UDim2.fromOffset(0, 0) })
		return self
	end

	function wcfg:CreateTab(tcfg)
		tcfg = tcfg or {}
		local name = tcfg.Name or ""

		local tabBtn = toolbar.TabButton:Clone()
		tabBtn.Name    = name
		tabBtn.Text    = name
		tabBtn.Visible = true
		tabBtn.Parent  = toolbar
		tcfg.Button    = tabBtn

		local autoAxis = wcfg.AutoSize or "Y"
		local tabContent = body.Template:Clone()
		tabContent.AutomaticSize = Enum.AutomaticSize[autoAxis]
		tabContent.Visible       = tcfg.Visible or false
		tabContent.Name          = name
		tabContent.Parent        = body
		tcfg.Content             = tabContent

		if autoAxis == "Y" then
			tabContent.Size = UDim2.fromScale(1, 0)
		elseif autoAxis == "X" then
			tabContent.Size = UDim2.fromScale(0, 1)
		end

		tabBtn.Activated:Connect(function()
			wcfg:ShowTab(tcfg)
		end)

		function tcfg:GetContentSize()
			return tabContent.AbsoluteSize
		end

		tcfg = ImGui:ContainerClass(tabContent, tcfg, window)
		ImGui:ApplyAnimations(tabBtn, "Tabs")

		wcfg:UpdateBody()

		if wcfg.AutoSize then
			tabContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				wcfg:SetSize(tcfg:GetContentSize())
			end)
		end

		return tcfg
	end

	collapseToggle.ToggleButton.Activated:Connect(function()
		wcfg:SetOpen(not wcfg.Open)
	end)

	wcfg:SetTitle(wcfg.Title or "Depso UI")

	if not wcfg.Open then
		wcfg:SetOpen(true, true)
	end

	ImGui.Windows[window] = wcfg
	ImGui:CheckStyles(window, wcfg, wcfg.Colors)

	if not wcfg.NoSelectEffect then
		ImGui:ApplyWindowSelectEffect(window, titleBar)
	end

	return ImGui:MergeMetatables(wcfg, window)
end

function ImGui:CreateModal(cfg)
	local overlay = Prefabs.ModalEffect:Clone()
	overlay.BackgroundTransparency = 1
	overlay.Parent  = ImGui.FullScreenGui
	overlay.Visible = true

	ImGui:Tween(overlay, { BackgroundTransparency = 0.6 })

	cfg = cfg or {}
	cfg.TabsBar         = cfg.TabsBar ~= nil and cfg.TabsBar or false
	cfg.NoCollapse      = true
	cfg.NoResize        = true
	cfg.NoClose         = true
	cfg.NoSelectEffect  = true
	cfg.AnchorPoint     = Vector2.new(0.5, 0.5)
	cfg.Position        = UDim2.fromScale(0.5, 0.5)

	local win    = self:CreateWindow(cfg)
	local tab    = win:CreateTab({ Visible = true })
	local mgr    = ImGui:SetWindowProps({ Interactable = false }, { win.Window })
	local winClose = win.Close

	function tab:Close()
		local t = ImGui:Tween(overlay, { BackgroundTransparency = 1 })
		t.Completed:Connect(function() overlay:Destroy() end)
		mgr:Revert()
		winClose()
	end

	return tab
end

local guiParent = IsStudio and PlayerGui or CoreGui

ImGui.ScreenGui = ImGui:CreateInstance("ScreenGui", guiParent, {
	DisplayOrder  = 9999,
	ResetOnSpawn  = false,
})

ImGui.FullScreenGui = ImGui:CreateInstance("ScreenGui", guiParent, {
	DisplayOrder  = 99999,
	ResetOnSpawn  = false,
	ScreenInsets  = Enum.ScreenInsets.None,
})

return ImGui
