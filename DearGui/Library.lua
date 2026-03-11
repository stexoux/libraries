local ImGui = {
	Animations = {
		Buttons = {
			MouseEnter = { BackgroundTransparency = 0.5 },
			MouseLeave = { BackgroundTransparency = 0.7 },
		},
		Tabs = {
			MouseEnter = { BackgroundTransparency = 0.5 },
			MouseLeave = { BackgroundTransparency = 1 },
		},
		Inputs = {
			MouseEnter = { BackgroundTransparency = 0 },
			MouseLeave = { BackgroundTransparency = 0.5 },
		},
		WindowBorder = {
			Selected   = { Transparency = 0,   Thickness = 1 },
			Deselected = { Transparency = 0.7, Thickness = 1 },
		},
	},
	Windows   = {},
	Animation = TweenInfo.new(0.1),
	UIAssetId = "rbxassetid://76246418997296",
	NoWarnings = true,
}

local NullFn   = function() end
local CloneRef = cloneref or function(s) return s end

local function GetService(name)
	return CloneRef(game:GetService(name))
end

local TweenService     = GetService("TweenService")
local UserInputService = GetService("UserInputService")
local Players          = GetService("Players")
local CoreGui          = GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer
local Mouse       = LocalPlayer:GetMouse()

function ImGui:Warn(...)
	if not self.NoWarnings then warn("[ImGui]", ...) end
end

function ImGui:NewInstance(className, parent, props)
	local inst = Instance.new(className, parent)
	for k, v in next, props or {} do inst[k] = v end
	return inst
end

function ImGui:GetName(name)
	return name .. "_"
end

function ImGui:Concat(tbl, sep)
	local parts = {}
	for i, v in ipairs(tbl) do parts[i] = tostring(v) end
	return table.concat(parts, sep or " ")
end

function ImGui:GetTweenInfo(animated)
	return animated and self.Animation or TweenInfo.new(0)
end

function ImGui:Tween(obj, props, info, noAnim)
	local tween = TweenService:Create(obj, info or self:GetTweenInfo(not noAnim), props)
	tween:Play()
	return tween
end

function ImGui:ConnectHover(cfg)
	local conns = {}
	cfg.Hovering = false

	table.insert(conns, cfg.Parent.MouseEnter:Connect(function() cfg.Hovering = true end))
	table.insert(conns, cfg.Parent.MouseLeave:Connect(function() cfg.Hovering = false end))

	if cfg.OnInput then
		table.insert(conns, UserInputService.InputBegan:Connect(function(input)
			cfg.OnInput(cfg.Hovering, input)
		end))
	end

	function cfg:Disconnect()
		for _, c in next, conns do c:Disconnect() end
	end

	return cfg
end

function ImGui:ApplyAnimations(obj, animClass, target)
	local set = self.Animations[animClass]
	if not set then return warn("[ImGui] Missing animation class:", animClass) end

	local conns = {}
	for event, props in next, set do
		if type(props) ~= "table" then continue end
		local dest = target or obj
		conns[event] = function() self:Tween(dest, props) end
		obj[event]:Connect(conns[event])
	end

	if conns.MouseLeave then conns.MouseLeave() end
	return conns
end

local StyleHandlers = {
	[{ Name = "Border" }] = function(obj, _, class)
		local stroke = obj:FindFirstChildOfClass("UIStroke")
		if not stroke then return end
		if class.BorderThickness then stroke.Thickness = class.BorderThickness end
		stroke.Enabled = class.Border
	end,
	[{ Name = "Ratio" }] = function(obj, _, class)
		local c = obj:FindFirstChildOfClass("UIAspectRatioConstraint") or ImGui:NewInstance("UIAspectRatioConstraint", obj)
		c.DominantAxis = Enum.DominantAxis[class.RatioAxis or "Height"]
		c.AspectType   = class.AspectType or Enum.AspectType.ScaleWithParentSize
		c.AspectRatio  = class.Ratio or (4 / 3)
	end,
	[{ Name = "CornerRadius", Recursive = true }] = function(obj, _, class)
		local c = obj:FindFirstChildOfClass("UICorner") or ImGui:NewInstance("UICorner", obj)
		c.CornerRadius = class.CornerRadius
	end,
	[{ Name = "Label" }] = function(obj, _, class)
		local lbl = obj:FindFirstChild("Label")
		if not lbl then return end
		lbl.Text = class.Label
		function class:SetLabel(text) lbl.Text = text return class end
	end,
	[{ Name = "NoGradient", Aliases = { "NoGradientAll" }, Recursive = true }] = function(obj, value)
		local g = obj:FindFirstChildOfClass("UIGradient")
		if g then g.Enabled = not value end
	end,
	[{ Name = "Callback" }] = function(obj, _, class)
		function class:SetCallback(fn) class.Callback = fn return class end
		function class:FireCallback() return class.Callback(obj) end
	end,
	[{ Name = "Value" }] = function(_, _, class)
		function class:GetValue() return class.Value end
	end,
}

function ImGui:ApplyColors(overwrites, obj, elementType)
	for info, value in next, overwrites do
		local key = type(info) == "table" and info.Name or info
		if type(value) == "table" then
			local child = obj:FindFirstChild(key, type(info) == "table" and info.Recursive)
			if not child and elementType == "Window" then
				child = obj.Content:FindFirstChild(key, true)
			end
			if child then ImGui:ApplyColors(value, child) end
		else
			obj[key] = value
		end
	end
end

function ImGui:ApplyStyles(obj, class, colors)
	for info, handler in next, StyleHandlers do
		local value = class[info.Name]
		if not value and info.Aliases then
			for _, alias in ipairs(info.Aliases) do
				value = class[alias]
				if value then break end
			end
		end
		if value == nil then continue end
		handler(obj, value, class)
		if info.Recursive then
			for _, child in next, obj:GetChildren() do handler(child, value, class) end
		end
	end

	local elementType = obj.Name
	obj.Name = self:GetName(elementType)

	local overwrites = colors and colors[elementType]
	if overwrites then ImGui:ApplyColors(overwrites, obj, elementType) end

	for k, v in next, class do
		pcall(function() obj[k] = v end)
	end
end

function ImGui:MergeMetatables(class, inst)
	return setmetatable({}, {
		__index = function(_, key)
			local ok, val = pcall(function()
				local v = inst[key]
				if type(v) == "function" then
					return function(...) return v(inst, ...) end
				end
				return v
			end)
			return ok and val or class[key]
		end,
		__newindex = function(_, key, val)
			if class[key] ~= nil or type(val) == "function" then
				class[key] = val
			else
				inst[key] = val
			end
		end,
	})
end

function ImGui:AnimateHeader(header, animated, open, titleBar, toggleOverride)
	local toggleBtn = toggleOverride or titleBar.Toggle.ToggleButton
	self:Tween(toggleBtn, { Rotation = open and 90 or 0 })

	local container = header:FindFirstChild("ChildContainer")
	if not container then return end

	local layout  = container.UIListLayout
	local padding = container:FindFirstChildOfClass("UIPadding")
	local content = layout.AbsoluteContentSize

	if padding then
		content = Vector2.new(content.X, content.Y + padding.PaddingTop.Offset + padding.PaddingBottom.Offset)
	end

	container.AutomaticSize = Enum.AutomaticSize.None
	if not open then container.Size = UDim2.new(1, -10, 0, content.Y) end

	local t = self:Tween(container, {
		Size    = UDim2.new(1, -10, 0, open and content.Y or 0),
		Visible = open,
	})
	t.Completed:Connect(function()
		if not open then return end
		container.AutomaticSize = Enum.AutomaticSize.Y
		container.Size = UDim2.new(1, -10, 0, 0)
	end)
end

function ImGui:MakeDraggable(frame, handle)
	handle = handle or frame
	local dragging, startInput, startPos = false, nil, frame.Position

	local allowed = { Enum.UserInputType.MouseButton1, Enum.UserInputType.Touch }

	handle.InputBegan:Connect(function(input)
		if not table.find(allowed, input.UserInputType) then return end
		dragging   = true
		startInput = input.Position
		startPos   = frame.Position
	end)

	UserInputService.InputEnded:Connect(function(input)
		if table.find(allowed, input.UserInputType) then dragging = false end
	end)

	local function move(input)
		if not dragging then return end
		local d = input.Position - startInput
		self:Tween(frame, {
			Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		})
	end

	UserInputService.TouchMoved:Connect(move)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then move(input) end
	end)
end

function ImGui:MakeResizable(frame, dragger, config, minSize)
	minSize = minSize or Vector2.new(160, 90)
	local dragStart, origSize = nil, nil

	dragger.MouseButton1Down:Connect(function()
		if dragStart then return end
		origSize  = frame.AbsoluteSize
		dragStart = Vector2.new(Mouse.X, Mouse.Y)
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not dragStart or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local d = Vector2.new(Mouse.X, Mouse.Y) - dragStart
		local newSize = UDim2.fromOffset(math.max(minSize.X, origSize.X + d.X), math.max(minSize.Y, origSize.Y + d.Y))
		frame.Size = newSize
		if config then config.Size = newSize end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragStart = nil end
	end)
end

function ImGui:ApplyWindowSelectEffect(window, titleBar)
	local stroke = window:FindFirstChildOfClass("UIStroke")
	local states = {
		Selected   = { BackgroundColor3 = titleBar.BackgroundColor3 },
		Deselected = { BackgroundColor3 = Color3.fromRGB(0, 0, 0) },
	}
	self:ConnectHover({
		Parent  = window,
		OnInput = function(hovering, input)
			if not input.UserInputType.Name:find("Mouse") then return end
			local key = hovering and "Selected" or "Deselected"
			self:Tween(titleBar, states[key])
			self:Tween(stroke, self.Animations.WindowBorder[key])
		end,
	})
end

function ImGui:SetWindowProps(props, ignore)
	local manager = { saved = {} }
	for win in next, self.Windows do
		if table.find(ignore or {}, win) then continue end
		local saved = {}
		manager.saved[win] = saved
		for k, v in next, props do
			saved[k] = win[k]
			win[k]   = v
		end
	end
	function manager:Revert()
		for win in next, ImGui.Windows do
			local saved = manager.saved[win]
			if not saved then continue end
			for k, v in next, saved do win[k] = v end
		end
	end
	return manager
end

function ImGui:OpenDropdown(cfg)
	local parent = cfg.Parent
	if not parent then return end

	local dropdown = ImGui:NewInstance("ScrollingFrame", self.ScreenGui)
	local stroke   = dropdown:FindFirstChildOfClass("UIStroke")
	local padding  = stroke and stroke.Thickness * 2 or 0
	local absPos   = parent.AbsolutePosition
	local absSize  = parent.AbsoluteSize

	dropdown.Position = UDim2.fromOffset(absPos.X + padding, absPos.Y + absSize.Y)

	local hoverConn = self:ConnectHover({
		Parent  = dropdown,
		OnInput = function(hovering, input)
			if not input.UserInputType.Name:find("Mouse") then return end
			if not hovering then cfg:Close() end
		end,
	})

	function cfg:Close()
		hoverConn:Disconnect()
		dropdown:Destroy()
		if cfg.Closed then cfg.Closed() end
	end

	for index, value in next, cfg.Items do
		local displayValue = type(index) ~= "number" and index or value
		local btn = ImGui:NewInstance("TextButton", dropdown, { Text = tostring(displayValue), Visible = true })
		btn.Activated:Connect(function()
			cfg:Close()
			cfg:SetValue(displayValue)
		end)
		self:ApplyAnimations(btn, "Tabs")
	end

	local maxY  = cfg.MaxSizeY or 200
	local sizeY = math.clamp(dropdown.AbsoluteCanvasSize.Y, absSize.Y, maxY)
	dropdown.Size = UDim2.fromOffset(absSize.X - padding, sizeY)

	return cfg
end

function ImGui:ContainerClass(frame, class, windowRef)
	local container = class or {}
	local winConfig = ImGui.Windows[windowRef]

	function container:NewInstance(inst, cfg, parent)
		cfg          = cfg or {}
		inst.Parent  = parent or frame
		inst.Visible = true

		if winConfig and winConfig.NoGradientAll then cfg.NoGradient = true end

		ImGui:ApplyStyles(inst, cfg, winConfig and winConfig.Colors)
		if cfg.NewInstanceCallback then cfg.NewInstanceCallback(inst) end
		return ImGui:MergeMetatables(cfg, inst)
	end

	function container:Button(cfg)
		cfg = cfg or {}
		local btn = ImGui:NewInstance("TextButton", nil)
		local obj = self:NewInstance(btn, cfg)
		btn.Activated:Connect(function(...) (cfg.Callback or NullFn)(obj, ...) end)
		ImGui:ApplyAnimations(btn, "Buttons")
		return obj
	end

	function container:Image(cfg)
		cfg = cfg or {}
		if tonumber(cfg.Image) then cfg.Image = "rbxassetid://" .. cfg.Image end
		local img = ImGui:NewInstance("ImageButton", nil)
		local obj = self:NewInstance(img, cfg)
		img.Activated:Connect(function(...) (cfg.Callback or NullFn)(obj, ...) end)
		ImGui:ApplyAnimations(img, "Buttons")
		return obj
	end

	function container:ScrollingBox(cfg)
		cfg = cfg or {}
		local box = ImGui:NewInstance("ScrollingFrame", nil)
		local inner = ImGui:ContainerClass(box, cfg, windowRef)
		return self:NewInstance(box, inner)
	end

	function container:Label(cfg)
		cfg = cfg or {}
		local lbl = ImGui:NewInstance("TextLabel", nil)
		return self:NewInstance(lbl, cfg)
	end

	function container:Checkbox(cfg)
		cfg = cfg or {}
		local isRadio = cfg.IsRadio

		local box     = ImGui:NewInstance("Frame", nil)
		local tickbox = ImGui:NewInstance("ImageButton", box)
		local tick    = ImGui:NewInstance("ImageLabel", tickbox)
		local label   = ImGui:NewInstance("TextLabel", box)
		local obj     = self:NewInstance(box, cfg)

		if isRadio then
			tick.ImageTransparency    = 1
			tick.BackgroundTransparency = 0
		end

		ImGui:ApplyAnimations(box, "Buttons", tickbox)

		local value = cfg.Value or false

		function cfg:SetTicked(newVal, noAnim)
			value     = newVal
			cfg.Value = value
			ImGui:Tween(tick,  { Size = value and UDim2.fromScale(1, 1) or UDim2.fromScale(0, 0) }, nil, noAnim)
			ImGui:Tween(label, { TextTransparency = value and 0 or 0.3 }, nil, noAnim)
			;(cfg.Callback or NullFn)(obj, value)
			return cfg
		end

		function cfg:Toggle()
			return cfg:SetTicked(not value)
		end

		local function onClick()
			cfg:SetTicked(not value)
		end

		box.Activated:Connect(onClick)
		tickbox.Activated:Connect(onClick)
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
		local holder     = ImGui:NewInstance("Frame", nil)
		local viewport   = ImGui:NewInstance("ViewportFrame", holder)
		local worldModel = ImGui:NewInstance("WorldModel", viewport)
		local camera     = cfg.Camera or ImGui:NewInstance("Camera", viewport)

		cfg.WorldModel = worldModel
		cfg.Viewport   = viewport

		function cfg:SetCamera(cam)
			viewport.CurrentCamera = cam
			cfg.Camera = cam
			cam.CFrame = CFrame.new(0, 0, 0)
			return cfg
		end

		function cfg:SetModel(model, pivotTo)
			worldModel:ClearAllChildren()
			if cfg.Clone then model = model:Clone() end
			if pivotTo then model:PivotTo(pivotTo) end
			model.Parent = worldModel
			cfg.Model = model
			return model
		end

		cfg:SetCamera(camera)
		if cfg.Model then cfg:SetModel(cfg.Model) end

		local inner = ImGui:ContainerClass(holder, cfg, windowRef)
		return self:NewInstance(holder, inner)
	end

	function container:InputText(cfg)
		cfg = cfg or {}
		local wrap    = ImGui:NewInstance("Frame", nil)
		local textbox = ImGui:NewInstance("TextBox", wrap)

		textbox.Text            = cfg.Value or ""
		textbox.PlaceholderText = cfg.PlaceHolder or ""
		textbox.MultiLine       = cfg.MultiLine == true

		local obj = self:NewInstance(wrap, cfg)
		ImGui:ApplyAnimations(wrap, "Inputs")

		textbox:GetPropertyChangedSignal("Text"):Connect(function()
			cfg.Value = textbox.Text
			;(cfg.Callback or NullFn)(obj, textbox.Text)
		end)

		function cfg:SetValue(text)
			textbox.Text = tostring(text)
			cfg.Value    = text
			return cfg
		end

		function cfg:Clear()
			textbox.Text = ""
			return cfg
		end

		return obj
	end

	function container:InputTextMultiline(cfg)
		cfg           = cfg or {}
		cfg.Label     = ""
		cfg.Size      = UDim2.new(1, 0, 0, 38)
		cfg.MultiLine = true
		return container:InputText(cfg)
	end

	function container:GetRemainingHeight()
		local pad    = frame:FindFirstChildOfClass("UIPadding")
		local layout = frame:FindFirstChildOfClass("UIListLayout")
		local extra  = pad.PaddingTop + pad.PaddingBottom + layout.Padding
		return UDim2.new(1, 0, 1, -(frame.AbsoluteSize.Y + extra.Offset + 3))
	end

	function container:Console(cfg)
		cfg = cfg or {}
		local scroll = ImGui:NewInstance("ScrollingFrame", nil)
		local source = ImGui:NewInstance("TextBox", scroll)
		local lines  = ImGui:NewInstance("TextLabel", scroll)

		if cfg.Fill then scroll.Size = container:GetRemainingHeight() end

		source.TextEditable = cfg.ReadOnly ~= true
		source.Text         = cfg.Text or ""
		source.TextWrapped  = cfg.TextWrapped == true
		source.RichText     = cfg.RichText == true
		lines.Visible       = cfg.LineNumbers == true

		function cfg:UpdateLineNumbers()
			if not cfg.LineNumbers then return end
			local count  = #source.Text:split("\n")
			local fmt    = cfg.LinesFormat or "%s"
			lines.Text   = ""
			for i = 1, count do
				lines.Text ..= fmt:format(i) .. (i ~= count and "\n" or "")
			end
			source.Size = UDim2.new(1, -lines.AbsoluteSize.X, 0, 0)
			return cfg
		end

		function cfg:UpdateScroll()
			scroll.CanvasPosition = Vector2.new(0, scroll.AbsoluteCanvasSize.Y)
			return cfg
		end

		function cfg:SetText(text)
			if not cfg.Enabled then return end
			source.Text = text
			cfg:UpdateLineNumbers()
			return cfg
		end

		function cfg:GetValue() return source.Text end

		function cfg:Clear()
			source.Text = ""
			cfg:UpdateLineNumbers()
			return cfg
		end

		function cfg:AppendText(...)
			if not cfg.Enabled then return end
			local max    = cfg.MaxLines or 100
			local new    = "\n" .. ImGui:Concat({...}, " ")
			source.Text ..= new
			cfg:UpdateLineNumbers()
			if cfg.AutoScroll then cfg:UpdateScroll() end
			local split = source.Text:split("\n")
			if #split > max then source.Text = source.Text:sub(#split[1] + 2) end
			return cfg
		end

		source.Changed:Connect(cfg.UpdateLineNumbers)
		return self:NewInstance(scroll, cfg)
	end

	function container:Table(cfg)
		cfg = cfg or {}
		local tbl        = ImGui:NewInstance("Frame", nil)
		local childCount = #tbl:GetChildren()
		local rowCount   = 0

		if cfg.Fill then tbl.Size = container:GetRemainingHeight() end

		function cfg:CreateRow()
			local rowClass = {}
			local row      = ImGui:NewInstance("Frame", nil)
			local layout   = ImGui:NewInstance("UIListLayout", row)
			layout.VerticalAlignment = Enum.VerticalAlignment[cfg.Align or "Center"]

			local rowChildCount = #row:GetChildren()
			row.Name    = "Row"
			row.Visible = true

			if cfg.RowBackground then
				row.BackgroundTransparency = rowCount % 2 == 1 and 0.92 or 1
			end

			function rowClass:CreateColumn(ccfg)
				ccfg = ccfg or {}
				local col    = ImGui:NewInstance("Frame", nil)
				local stroke = ImGui:NewInstance("UIStroke", col)
				stroke.Enabled = cfg.Border ~= false
				col.Visible = true
				col.Name    = "Column"
				local inner = ImGui:ContainerClass(col, ccfg, windowRef)
				return inner:NewInstance(col, inner, row)
			end

			function rowClass:UpdateColumns()
				local cols = row:GetChildren()
				local n    = #cols - rowChildCount
				for _, col in next, cols do
					if col:IsA("Frame") then col.Size = UDim2.new(1 / n, 0, 0, 0) end
				end
				return rowClass
			end

			row.ChildAdded:Connect(rowClass.UpdateColumns)
			row.ChildRemoved:Connect(rowClass.UpdateColumns)

			rowCount += 1
			return container:NewInstance(row, rowClass, tbl)
		end

		function cfg:UpdateRows()
			local rows    = tbl:GetChildren()
			local paddY   = tbl.UIListLayout.Padding.Offset + 2
			local n       = #rows - childCount
			for _, row in next, rows do
				if row:IsA("Frame") then row.Size = UDim2.new(1, 0, 1 / n, -paddY) end
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
			local postName = ImGui:GetName("Row")
			for _, row in next, tbl:GetChildren() do
				if row:IsA("Frame") and row.Name == postName then row:Destroy() end
			end
			return cfg
		end

		return self:NewInstance(tbl, cfg)
	end

	function container:Grid(cfg)
		cfg      = cfg or {}
		cfg.Grid = true
		return self:Table(cfg)
	end

	function container:CollapsingHeader(cfg)
		cfg      = cfg or {}
		local title = cfg.Title or ""
		cfg.Name    = title

		local header    = ImGui:NewInstance("Frame", nil)
		local titlebar  = ImGui:NewInstance("TextButton", header)
		local titleLbl  = ImGui:NewInstance("TextLabel", titlebar)
		local childCont = ImGui:NewInstance("Frame", header)
		titleLbl.Text   = title

		if cfg.IsTree then
			ImGui:ApplyAnimations(titlebar, "Tabs")
		else
			ImGui:ApplyAnimations(titlebar, "Buttons")
		end

		local toggleBtn = ImGui:NewInstance("ImageButton", titlebar)
		if cfg.Image then toggleBtn.Image = cfg.Image end

		function cfg:SetOpen(open)
			cfg.Open = open
			ImGui:AnimateHeader(header, cfg.NoAnimation ~= true, open, titlebar)
			return cfg
		end

		local function toggle() cfg:SetOpen(not cfg.Open) end
		titlebar.Activated:Connect(toggle)
		toggleBtn.Activated:Connect(toggle)
		cfg:SetOpen(cfg.Open or false)

		local inner = ImGui:ContainerClass(childCont, cfg, windowRef)
		return self:NewInstance(header, inner)
	end

	function container:TreeNode(cfg)
		cfg        = cfg or {}
		cfg.IsTree = true
		return self:CollapsingHeader(cfg)
	end

	function container:Separator(cfg)
		cfg = cfg or {}
		local sep = ImGui:NewInstance("Frame", nil)
		local lbl = ImGui:NewInstance("TextLabel", sep)
		lbl.Text    = cfg.Text or ""
		lbl.Visible = cfg.Text ~= nil
		return self:NewInstance(sep, cfg)
	end

	function container:Row(cfg)
		cfg = cfg or {}
		local row    = ImGui:NewInstance("Frame", nil)
		local layout = ImGui:NewInstance("UIListLayout", row)
		local pad    = ImGui:NewInstance("UIPadding", row)

		if cfg.Spacing then layout.Padding = UDim.new(0, cfg.Spacing) end

		function cfg:Fill()
			local children = row:GetChildren()
			local n        = #children - 2
			layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
			pad.PaddingLeft  = layout.Padding
			pad.PaddingRight = layout.Padding
			local p = layout.Padding.Offset * 2
			for _, child in next, children do
				local yScale = child:IsA("ImageButton") and 1 or 0
				pcall(function() child.Size = UDim2.new(1 / n, -p, yScale, 0) end)
			end
			return cfg
		end

		local inner = ImGui:ContainerClass(row, cfg, windowRef)
		return self:NewInstance(row, inner)
	end

	function container:Slider(cfg)
		cfg = cfg or {}

		local value      = cfg.Value or 0
		local valueFmt   = cfg.Format or "%.d"
		local isProgress = cfg.Progress
		cfg.Name         = cfg.Label or ""

		local slider    = ImGui:NewInstance("TextButton", nil)
		local grab      = ImGui:NewInstance("Frame", slider)
		local valueTxt  = ImGui:NewInstance("TextLabel", slider)
		local labelTxt  = ImGui:NewInstance("TextLabel", slider)

		local dragging        = false
		local mouseMoveConn   = nil
		local inputType       = Enum.UserInputType.MouseButton1
		local obj             = self:NewInstance(slider, cfg)

		function cfg:SetValue(v, fromSlider)
			local mn   = cfg.MinValue
			local mx   = cfg.MaxValue
			local diff = mx - mn
			local pct

			if fromSlider then
				pct = v
				v   = mn + diff * pct
			else
				v   = tonumber(v)
				pct = (v - mn) / diff
			end

			if isProgress then
				ImGui:Tween(grab, { Size = UDim2.fromScale(pct, 1) })
			else
				ImGui:Tween(grab, { Position = UDim2.fromScale(pct, 0.5) })
			end

			cfg.Value    = v
			valueTxt.Text = valueFmt:format(v, mx)
			;(cfg.Callback or NullFn)(obj, v)
			return cfg
		end

		local function onMouseMove()
			if cfg.ReadOnly or not dragging then return end
			local mx  = UserInputService:GetMouseLocation().X
			local pct = math.clamp((mx - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
			cfg:SetValue(pct, true)
		end

		UserInputService.InputEnded:Connect(function(input)
			if dragging and input.UserInputType == inputType then
				dragging = false
				if mouseMoveConn then mouseMoveConn:Disconnect() end
			end
		end)

		ImGui:ConnectHover({
			Parent  = slider,
			OnInput = function(hovering, input)
				if not hovering or input.UserInputType ~= inputType then return end
				dragging      = true
				mouseMoveConn = Mouse.Move:Connect(onMouseMove)
			end,
		})

		slider.Activated:Connect(onMouseMove)
		cfg:SetValue(value)
		return obj
	end

	function container:ProgressSlider(cfg)
		cfg          = cfg or {}
		cfg.Progress = true
		return self:Slider(cfg)
	end

	function container:ProgressBar(cfg)
		cfg          = cfg or {}
		cfg.Progress = true
		cfg.ReadOnly = true
		cfg.MinValue = 0
		cfg.MaxValue = 100
		cfg.Format   = "%i%%"
		cfg          = self:Slider(cfg)

		function cfg:SetPercentage(v) cfg:SetValue(v) end
		return cfg
	end

	function container:Keybind(cfg)
		cfg = cfg or {}

		local key      = cfg.Value
		local nullKey  = cfg.NullKey or Enum.KeyCode.Backspace
		local keybind  = ImGui:NewInstance("TextButton", nil)
		local valueTxt = ImGui:NewInstance("TextLabel", keybind)
		local obj      = nil

		function cfg:SetValue(newKey)
			if not newKey then return end
			if newKey == nullKey then
				valueTxt.Text = "Not set"
				cfg.Value     = nil
			else
				valueTxt.Text = newKey.Name
				cfg.Value     = newKey
			end
		end

		keybind.Activated:Connect(function()
			valueTxt.Text = "..."
			local input = UserInputService.InputBegan:Wait()
			if not UserInputService.WindowFocused then return end
			if input.KeyCode.Name == "Unknown" then return cfg:SetValue(cfg.Value) end
			task.wait(0.1)
			cfg:SetValue(input.KeyCode)
		end)

		cfg.Connection = UserInputService.InputBegan:Connect(function(input, processed)
			if not cfg.IgnoreGameProcessed and processed then return end
			if input.KeyCode == nullKey or input.KeyCode ~= cfg.Value then return end
			;(cfg.Callback or NullFn)(obj, input.KeyCode)
		end)

		cfg:SetValue(key)
		obj = self:NewInstance(keybind, cfg)
		return obj
	end

	function container:Combo(cfg)
		cfg       = cfg or {}
		cfg.Open  = false
		cfg.Value = ""

		local combo    = ImGui:NewInstance("TextButton", nil)
		local toggle   = ImGui:NewInstance("ImageButton", combo)
		local valueTxt = ImGui:NewInstance("TextLabel", combo)
		valueTxt.Text  = cfg.Placeholder or ""

		local dropdown = nil
		local obj      = self:NewInstance(combo, cfg)
		local hoverCfg = ImGui:ConnectHover({ Parent = combo })

		function cfg:SetValue(v)
			local items    = cfg.Items or {}
			valueTxt.Text  = tostring(v)
			cfg.Value      = v
			cfg:SetOpen(false)
			;(cfg.Callback or NullFn)(obj, items[v] or v)
			return cfg
		end

		function cfg:SetOpen(open)
			ImGui:AnimateHeader(combo, cfg.NoAnimation ~= true, open, combo, toggle)
			cfg.Open = open

			if open then
				dropdown = ImGui:OpenDropdown({
					Parent   = combo,
					Items    = cfg.Items or {},
					SetValue = cfg.SetValue,
					Closed   = function()
						if not hoverCfg.Hovering then cfg:SetOpen(false) end
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
	local window  = ImGui:NewInstance("Frame", self.ScreenGui, { Visible = true })
	local content = ImGui:NewInstance("Frame", window)
	local body    = ImGui:NewInstance("Frame", content)
	wcfg.Window   = window

	local resize  = ImGui:NewInstance("TextButton", window)
	resize.Visible = wcfg.NoResize ~= true
	self:MakeResizable(window, resize, wcfg, wcfg.MinSize)

	local titleBar = ImGui:NewInstance("Frame", content)
	titleBar.Visible = wcfg.NoTitleBar ~= true

	local titleLbl = ImGui:NewInstance("TextLabel", titleBar)
	local collapse = ImGui:NewInstance("ImageButton", titleBar)
	collapse.Visible = wcfg.NoCollapse ~= true
	self:ApplyAnimations(collapse, "Tabs")

	local toolbar = ImGui:NewInstance("Frame", content)
	toolbar.Visible = wcfg.TabsBar ~= false

	if not wcfg.NoDrag then self:MakeDraggable(window) end

	local closeBtn = ImGui:NewInstance("TextButton", titleBar)
	closeBtn.Visible = wcfg.NoClose ~= true

	function wcfg:Close()
		wcfg:SetVisible(false)
		if wcfg.CloseCallback then wcfg.CloseCallback(wcfg) end
		return wcfg
	end
	closeBtn.Activated:Connect(wcfg.Close)

	function wcfg:GetHeaderSizeY()
		return (toolbar.Visible and toolbar.AbsoluteSize.Y or 0)
			 + (titleBar.Visible and titleBar.AbsoluteSize.Y or 0)
	end

	function wcfg:UpdateBody()
		body.Size = UDim2.new(1, 0, 1, -self:GetHeaderSizeY())
	end
	wcfg:UpdateBody()

	wcfg.Open = true

	function wcfg:SetOpen(open, noAnim)
		self.Open = open
		ImGui:AnimateHeader(titleBar, true, open, titleBar, collapse)
		ImGui:Tween(resize, { TextTransparency = open and 0.6 or 1, Interactable = open }, nil, noAnim)
		ImGui:Tween(window, { Size = open and self.Size or UDim2.fromOffset(window.AbsoluteSize.X, titleBar.AbsoluteSize.Y) }, nil, noAnim)
		ImGui:Tween(body, { Visible = open }, nil, noAnim)
		return self
	end

	function wcfg:SetVisible(v)
		window.Visible = v
		return self
	end

	function wcfg:SetTitle(text)
		titleLbl.Text = tostring(text)
		return self
	end

	function wcfg:SetPosition(pos)
		window.Position = pos
		return self
	end

	function wcfg:SetSize(size)
		local headerY = self:GetHeaderSizeY()
		if typeof(size) == "Vector2" then size = UDim2.fromOffset(size.X, size.Y) end
		local newSize = UDim2.new(size.X.Scale, size.X.Offset, size.Y.Scale, size.Y.Offset + headerY)
		self.Size  = newSize
		window.Size = newSize
		return self
	end

	function wcfg:Remove()
		window:Destroy()
		return self
	end

	collapse.Activated:Connect(function()
		wcfg:SetOpen(not wcfg.Open)
	end)

	function wcfg:ShowTab(tabClass)
		local target = tabClass.Content
		if not target.Visible and not tabClass.NoAnimation then
			target.Position = UDim2.fromOffset(0, 5)
		end
		for _, page in next, body:GetChildren() do
			page.Visible = page == target
		end
		ImGui:Tween(target, { Position = UDim2.fromOffset(0, 0) })
		return self
	end

	function wcfg:CreateTab(cfg)
		cfg = cfg or {}
		local name = cfg.Name or ""

		local tabBtn = ImGui:NewInstance("TextButton", toolbar, { Text = name, Visible = true, Name = name })
		cfg.Button   = tabBtn

		local autoAxis  = wcfg.AutoSize or "Y"
		local tabContent = ImGui:NewInstance("Frame", body, {
			AutomaticSize = Enum.AutomaticSize[autoAxis],
			Visible       = cfg.Visible or false,
			Name          = name,
		})

		if autoAxis == "Y" then
			tabContent.Size = UDim2.fromScale(1, 0)
		elseif autoAxis == "X" then
			tabContent.Size = UDim2.fromScale(0, 1)
		end

		cfg.Content = tabContent
		tabBtn.Activated:Connect(function() wcfg:ShowTab(cfg) end)

		function cfg:GetContentSize() return tabContent.AbsoluteSize end

		cfg = ImGui:ContainerClass(tabContent, cfg, window)
		ImGui:ApplyAnimations(tabBtn, "Tabs")
		self:UpdateBody()

		if wcfg.AutoSize then
			tabContent:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
				self:SetSize(cfg:GetContentSize())
			end)
		end

		return cfg
	end

	function wcfg:Center()
		local s = window.AbsoluteSize
		self:SetPosition(UDim2.new(0.5, -s.X / 2, 0.5, -s.Y / 2))
		return self
	end

	wcfg:SetTitle(wcfg.Title or "ImGui Window")

	if not wcfg.Open then
		wcfg:SetOpen(true, true)
	end

	ImGui.Windows[window] = wcfg
	self:ApplyStyles(window, wcfg, wcfg.Colors)

	if not wcfg.NoSelectEffect then
		self:ApplyWindowSelectEffect(window, titleBar)
	end

	return self:MergeMetatables(wcfg, window)
end

function ImGui:CreateModal(cfg)
	local overlay = self:NewInstance("Frame", self.FullScreenGui, {
		BackgroundTransparency = 1,
		Visible                = true,
		Size                   = UDim2.fromScale(1, 1),
	})

	self:Tween(overlay, { BackgroundTransparency = 0.6 })

	cfg              = cfg or {}
	cfg.TabsBar      = cfg.TabsBar ~= nil and cfg.TabsBar or false
	cfg.NoCollapse   = true
	cfg.NoResize     = true
	cfg.NoClose      = true
	cfg.NoSelectEffect = true
	cfg.AnchorPoint  = Vector2.new(0.5, 0.5)
	cfg.Position     = UDim2.fromScale(0.5, 0.5)

	local win    = self:CreateWindow(cfg)
	local tab    = win:CreateTab({ Visible = true })
	local mgr    = self:SetWindowProps({ Interactable = false }, { win.Window })
	local winClose = win.Close

	function tab:Close()
		local t = ImGui:Tween(overlay, { BackgroundTransparency = 1 })
		t.Completed:Connect(function() overlay:Destroy() end)
		mgr:Revert()
		winClose()
	end

	return tab
end

ImGui.ScreenGui = ImGui:NewInstance("ScreenGui", CoreGui, {
	DisplayOrder = 9999,
	ResetOnSpawn = false,
})

ImGui.FullScreenGui = ImGui:NewInstance("ScreenGui", CoreGui, {
	DisplayOrder  = 99999,
	ResetOnSpawn  = false,
	ScreenInsets  = Enum.ScreenInsets.None,
})

return ImGui
