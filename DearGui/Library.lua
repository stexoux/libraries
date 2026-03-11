local ImGui = {}
ImGui.__index = ImGui

local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

--// classic dear imgui navy/steel palette
local T = {
	WindowBg         = Color3.fromRGB(15,  15,  20),
	WindowBorder     = Color3.fromRGB(110, 110, 128),
	TitleBg          = Color3.fromRGB(35,  50,  100),
	TitleBgActive    = Color3.fromRGB(41,  74,  122),
	TitleBgCollapsed = Color3.fromRGB(26,  26,  51),
	FrameBg          = Color3.fromRGB(41,  74,  122),
	FrameBgHover     = Color3.fromRGB(66,  99,  148),
	FrameBgActive    = Color3.fromRGB(66,  99,  148),
	Button           = Color3.fromRGB(66,  113, 174),
	ButtonHover      = Color3.fromRGB(79,  135, 208),
	ButtonActive     = Color3.fromRGB(15,  135, 250),
	CheckMark        = Color3.fromRGB(102, 179, 255),
	SliderGrab       = Color3.fromRGB(61,  133, 224),
	SliderGrabActive = Color3.fromRGB(66,  150, 250),
	SliderTrack      = Color3.fromRGB(41,  74,  122),
	Tab              = Color3.fromRGB(46,  89,  148),
	TabHovered       = Color3.fromRGB(66,  102, 170),
	TabActive        = Color3.fromRGB(51,  102, 168),
	TabBar           = Color3.fromRGB(20,  20,  36),
	Separator        = Color3.fromRGB(110, 110, 128),
	Text             = Color3.fromRGB(255, 255, 255),
	TextDisabled     = Color3.fromRGB(128, 128, 128),
	DropdownBg       = Color3.fromRGB(20,  20,  36),
	DropdownItem     = Color3.fromRGB(30,  40,  70),
	DropdownHover    = Color3.fromRGB(66,  113, 174),
	ScrollBar        = Color3.fromRGB(61,  133, 224),
}

local FONT     = Enum.Font.Code
local FSIZE    = 13
local PAD      = 8
local ITEM_H   = 22
local CORNER   = 3
local ANIM     = TweenInfo.new(0.1,  Enum.EasingStyle.Quad)
local ANIM_MED = TweenInfo.new(0.15, Enum.EasingStyle.Quad)

local function tween(obj, props, info)
	TweenService:Create(obj, info or ANIM, props):Play()
end

local function inst(class, props)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	return o
end

local function applyCorner(parent, r)
	inst("UICorner", { Parent = parent, CornerRadius = UDim.new(0, r or CORNER) })
end

local function applyStroke(parent, color, thickness)
	inst("UIStroke", {
		Parent          = parent,
		Color           = color or T.WindowBorder,
		Thickness       = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function mkLabel(parent, text, pos, size, color, fs, xAlign)
	return inst("TextLabel", {
		Parent               = parent,
		Text                 = text,
		Position             = pos  or UDim2.new(0, 0, 0, 0),
		Size                 = size or UDim2.new(1, 0, 0, ITEM_H),
		BackgroundTransparency = 1,
		TextColor3           = color or T.Text,
		Font                 = FONT,
		TextSize             = fs or FSIZE,
		TextXAlignment       = xAlign or Enum.TextXAlignment.Left,
		TextYAlignment       = Enum.TextYAlignment.Center,
		ClipsDescendants     = false,
	})
end

local function makeDraggable(handle, target)
	local dragging, origin, winOrigin
	handle.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		dragging  = true
		origin    = input.Position
		winOrigin = target.Position
	end)
	handle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if not dragging or input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
		local d = input.Position - origin
		tween(target, {
			Position = UDim2.new(winOrigin.X.Scale, winOrigin.X.Offset + d.X, winOrigin.Y.Scale, winOrigin.Y.Offset + d.Y)
		})
	end)
end

--// ─── WINDOW ──────────────────────────────────────────────────────────────────

function ImGui.new(title, width, height)
	local self      = setmetatable({}, ImGui)
	self.Width      = width  or 320
	self.Height     = height or 440
	self._tabs      = {}
	self._activeTab = nil
	self._yOffset   = PAD

	local gui = inst("ScreenGui", {
		Name           = "DearImGui",
		ResetOnSpawn   = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent         = game:GetService("CoreGui"),
	})

	local win = inst("Frame", {
		Parent           = gui,
		Size             = UDim2.new(0, self.Width, 0, self.Height),
		Position         = UDim2.new(0.5, -self.Width / 2, 0.5, -self.Height / 2),
		BackgroundColor3 = T.WindowBg,
		BorderSizePixel  = 0,
		ClipsDescendants = true,
	})
	applyCorner(win, CORNER)
	applyStroke(win, T.WindowBorder, 1)

	local titleBar = inst("Frame", {
		Parent           = win,
		Size             = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = T.TitleBgActive,
		BorderSizePixel  = 0,
		ZIndex           = 10,
	})
	applyCorner(titleBar, CORNER)

	--// square off the bottom of the title bar so it sits flush
	inst("Frame", {
		Parent           = titleBar,
		Size             = UDim2.new(1, 0, 0, CORNER),
		Position         = UDim2.new(0, 0, 1, -CORNER),
		BackgroundColor3 = T.TitleBgActive,
		BorderSizePixel  = 0,
		ZIndex           = 10,
	})

	--// collapse arrow, no button background — just the glyph
	local collapseBtn = inst("TextButton", {
		Parent               = titleBar,
		Size                 = UDim2.new(0, 18, 0, 18),
		Position             = UDim2.new(0, 5, 0.5, -9),
		BackgroundTransparency = 1,
		Text                 = "▼",
		TextColor3           = T.Text,
		Font                 = FONT,
		TextSize             = 10,
		BorderSizePixel      = 0,
		ZIndex               = 12,
		AutoButtonColor      = false,
	})

	mkLabel(titleBar,
		title or "Dear ImGui",
		UDim2.new(0, 26, 0, 0),
		UDim2.new(1, -30, 1, 0),
		T.Text, FSIZE
	).ZIndex = 11

	--// 1px line below title
	inst("Frame", {
		Parent           = win,
		Size             = UDim2.new(1, 0, 0, 1),
		Position         = UDim2.new(0, 0, 0, 26),
		BackgroundColor3 = T.Separator,
		BorderSizePixel  = 0,
		ZIndex           = 5,
	})

	makeDraggable(titleBar, win)

	local content = inst("ScrollingFrame", {
		Name                 = "Content",
		Parent               = win,
		Size                 = UDim2.new(1, 0, 1, -28),
		Position             = UDim2.new(0, 0, 0, 28),
		BackgroundTransparency = 1,
		BorderSizePixel      = 0,
		ScrollBarThickness   = 3,
		ScrollBarImageColor3 = T.ScrollBar,
		CanvasSize           = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize  = Enum.AutomaticSize.Y,
		ScrollingDirection   = Enum.ScrollingDirection.Y,
		ZIndex               = 2,
	})

	local collapsed  = false
	local fullSize   = UDim2.new(0, self.Width, 0, self.Height)
	local shrunkSize = UDim2.new(0, self.Width, 0, 27)

	collapseBtn.MouseButton1Click:Connect(function()
		collapsed = not collapsed
		if collapsed then
			collapseBtn.Text = "▶"
			content.Visible  = false
			tween(win, { Size = shrunkSize }, ANIM_MED)
			tween(titleBar, { BackgroundColor3 = T.TitleBgCollapsed }, ANIM)
		else
			collapseBtn.Text = "▼"
			content.Visible  = true
			tween(win, { Size = fullSize }, ANIM_MED)
			tween(titleBar, { BackgroundColor3 = T.TitleBgActive }, ANIM)
		end
	end)

	win.MouseEnter:Connect(function()
		if not collapsed then tween(titleBar, { BackgroundColor3 = T.TitleBgActive }) end
	end)
	win.MouseLeave:Connect(function()
		if not collapsed then tween(titleBar, { BackgroundColor3 = T.TitleBg }) end
	end)

	self._gui     = gui
	self._win     = win
	self._content = content

	return self
end

function ImGui:_getContent()
	if self._activeTab and self._tabs[self._activeTab] then
		return self._tabs[self._activeTab].frame
	end
	return self._content
end

function ImGui:_y()
	if self._activeTab and self._tabs[self._activeTab] then
		return self._tabs[self._activeTab].y or PAD
	end
	return self._yOffset
end

function ImGui:_push(h)
	if self._activeTab and self._tabs[self._activeTab] then
		self._tabs[self._activeTab].y = (self._tabs[self._activeTab].y or PAD) + h + 4
	else
		self._yOffset = self._yOffset + h + 4
	end
end

--// ─── SEPARATOR ───────────────────────────────────────────────────────────────

function ImGui:Separator()
	local parent = self:_getContent()
	local y      = self:_y()
	inst("Frame", {
		Parent           = parent,
		Size             = UDim2.new(1, -PAD * 2, 0, 1),
		Position         = UDim2.new(0, PAD, 0, y + 5),
		BackgroundColor3 = T.Separator,
		BorderSizePixel  = 0,
	})
	self:_push(11)
end

--// ─── TEXT ────────────────────────────────────────────────────────────────────

function ImGui:Text(text, color)
	local parent = self:_getContent()
	local y      = self:_y()
	mkLabel(parent, text,
		UDim2.new(0, PAD, 0, y),
		UDim2.new(1, -PAD * 2, 0, ITEM_H),
		color or T.Text
	)
	self:_push(ITEM_H)
end

--// ─── BUTTON ──────────────────────────────────────────────────────────────────

function ImGui:Button(text, callback)
	local parent = self:_getContent()
	local y      = self:_y()

	local btn = inst("TextButton", {
		Parent           = parent,
		Size             = UDim2.new(1, -PAD * 2, 0, ITEM_H),
		Position         = UDim2.new(0, PAD, 0, y),
		BackgroundColor3 = T.Button,
		Text             = text,
		TextColor3       = T.Text,
		Font             = FONT,
		TextSize         = FSIZE,
		BorderSizePixel  = 0,
		AutoButtonColor  = false,
	})
	applyCorner(btn)

	btn.MouseEnter:Connect(function()       tween(btn, { BackgroundColor3 = T.ButtonHover }) end)
	btn.MouseLeave:Connect(function()       tween(btn, { BackgroundColor3 = T.Button }) end)
	btn.MouseButton1Down:Connect(function() tween(btn, { BackgroundColor3 = T.ButtonActive }) end)
	btn.MouseButton1Up:Connect(function()
		tween(btn, { BackgroundColor3 = T.ButtonHover })
		if callback then callback() end
	end)

	self:_push(ITEM_H)
	return btn
end

--// ─── CHECKBOX ────────────────────────────────────────────────────────────────

function ImGui:Checkbox(text, default, callback)
	local parent = self:_getContent()
	local y      = self:_y()
	local state  = default or false

	local row = inst("Frame", {
		Parent               = parent,
		Size                 = UDim2.new(1, -PAD * 2, 0, ITEM_H),
		Position             = UDim2.new(0, PAD, 0, y),
		BackgroundTransparency = 1,
	})

	local box = inst("Frame", {
		Parent           = row,
		Size             = UDim2.new(0, 14, 0, 14),
		Position         = UDim2.new(0, 0, 0.5, -7),
		BackgroundColor3 = T.FrameBg,
		BorderSizePixel  = 0,
	})
	applyCorner(box, 2)
	applyStroke(box, T.WindowBorder, 1)

	local fill = inst("Frame", {
		Parent               = box,
		Size                 = UDim2.new(0, 8, 0, 8),
		Position             = UDim2.new(0.5, -4, 0.5, -4),
		BackgroundColor3     = T.CheckMark,
		BorderSizePixel      = 0,
		BackgroundTransparency = state and 0 or 1,
	})
	applyCorner(fill, 2)

	mkLabel(row, text,
		UDim2.new(0, 21, 0, 0),
		UDim2.new(1, -21, 1, 0),
		T.Text
	)

	local hit = inst("TextButton", {
		Parent               = row,
		Size                 = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
		Text                 = "",
		ZIndex               = 5,
	})

	hit.MouseEnter:Connect(function() tween(box, { BackgroundColor3 = T.FrameBgHover }) end)
	hit.MouseLeave:Connect(function() tween(box, { BackgroundColor3 = state and T.FrameBgActive or T.FrameBg }) end)
	hit.MouseButton1Click:Connect(function()
		state = not state
		tween(fill, { BackgroundTransparency = state and 0 or 1 })
		tween(box,  { BackgroundColor3 = state and T.FrameBgActive or T.FrameBg })
		if callback then callback(state) end
	end)

	self:_push(ITEM_H)
	return {
		GetValue = function() return state end,
		SetValue = function(v)
			state = v
			fill.BackgroundTransparency = v and 0 or 1
			box.BackgroundColor3 = v and T.FrameBgActive or T.FrameBg
		end,
	}
end

--// ─── SLIDER ──────────────────────────────────────────────────────────────────

function ImGui:Slider(text, min, max, default, callback)
	local parent = self:_getContent()
	local y      = self:_y()
	local value  = math.clamp(default or min, min, max)
	local totalH = ITEM_H + 10

	local lbl = mkLabel(parent, text .. ":  " .. tostring(math.floor(value)),
		UDim2.new(0, PAD, 0, y),
		UDim2.new(1, -PAD * 2, 0, ITEM_H - 6),
		T.Text
	)

	local track = inst("Frame", {
		Parent           = parent,
		Size             = UDim2.new(1, -PAD * 2, 0, 4),
		Position         = UDim2.new(0, PAD, 0, y + ITEM_H - 2),
		BackgroundColor3 = T.SliderTrack,
		BorderSizePixel  = 0,
	})
	applyCorner(track, 2)
	applyStroke(track, T.WindowBorder, 1)

	local fill = inst("Frame", {
		Parent           = track,
		Size             = UDim2.new((value - min) / (max - min), 0, 1, 0),
		BackgroundColor3 = T.SliderGrab,
		BorderSizePixel  = 0,
	})
	applyCorner(fill, 2)

	local grab = inst("Frame", {
		Parent           = track,
		Size             = UDim2.new(0, 10, 0, 10),
		Position         = UDim2.new((value - min) / (max - min), -5, 0.5, -5),
		BackgroundColor3 = T.SliderGrab,
		BorderSizePixel  = 0,
		ZIndex           = 4,
	})
	applyCorner(grab, 5)

	local dragging = false

	local function applyX(inputX)
		local pct = math.clamp((inputX - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local v   = math.floor(min + pct * (max - min))
		value     = v
		local p   = (v - min) / (max - min)
		fill.Size          = UDim2.new(p, 0, 1, 0)
		grab.Position      = UDim2.new(p, -5, 0.5, -5)
		lbl.Text           = text .. ":  " .. tostring(v)
		grab.BackgroundColor3 = T.SliderGrabActive
		if callback then callback(v) end
	end

	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			applyX(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
			applyX(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 and dragging then
			dragging = false
			tween(grab, { BackgroundColor3 = T.SliderGrab })
		end
	end)

	self:_push(totalH)
	return {
		GetValue = function() return value end,
		SetValue = function(v)
			value = math.clamp(v, min, max)
			local p = (value - min) / (max - min)
			fill.Size     = UDim2.new(p, 0, 1, 0)
			grab.Position = UDim2.new(p, -5, 0.5, -5)
			lbl.Text      = text .. ":  " .. tostring(math.floor(value))
		end,
	}
end

--// ─── DROPDOWN ────────────────────────────────────────────────────────────────

function ImGui:Dropdown(text, options, default, callback)
	local parent   = self:_getContent()
	local y        = self:_y()
	local selected = default or options[1]
	local open     = false

	local wrapper = inst("Frame", {
		Parent               = parent,
		Size                 = UDim2.new(1, -PAD * 2, 0, ITEM_H),
		Position             = UDim2.new(0, PAD, 0, y),
		BackgroundTransparency = 1,
		ClipsDescendants     = false,
		ZIndex               = 20,
	})

	local header = inst("TextButton", {
		Parent           = wrapper,
		Size             = UDim2.new(1, 0, 1, 0),
		BackgroundColor3 = T.FrameBg,
		Text             = "",
		BorderSizePixel  = 0,
		AutoButtonColor  = false,
		ZIndex           = 20,
	})
	applyCorner(header)
	applyStroke(header, T.WindowBorder, 1)

	local headerLbl = mkLabel(header, text .. "  " .. selected,
		UDim2.new(0, PAD, 0, 0),
		UDim2.new(1, -28, 1, 0),
		T.Text
	)
	headerLbl.ZIndex = 21

	local arrow = mkLabel(header, "▾",
		UDim2.new(1, -20, 0, 0),
		UDim2.new(0, 16, 1, 0),
		T.TextDisabled, FSIZE, Enum.TextXAlignment.Center
	)
	arrow.ZIndex = 21

	local panel = inst("Frame", {
		Parent           = wrapper,
		Size             = UDim2.new(1, 0, 0, 0),
		Position         = UDim2.new(0, 0, 1, 1),
		BackgroundColor3 = T.DropdownBg,
		BorderSizePixel  = 0,
		ClipsDescendants = true,
		ZIndex           = 60,
	})
	applyCorner(panel)
	applyStroke(panel, T.WindowBorder, 1)

	local itemH = ITEM_H + 1
	local fullH = #options * itemH + 4

	for i, opt in ipairs(options) do
		local row = inst("TextButton", {
			Parent           = panel,
			Size             = UDim2.new(1, -4, 0, ITEM_H),
			Position         = UDim2.new(0, 2, 0, (i - 1) * itemH + 2),
			BackgroundColor3 = T.DropdownItem,
			Text             = "",
			BorderSizePixel  = 0,
			AutoButtonColor  = false,
			ZIndex           = 61,
		})
		applyCorner(row, 2)
		mkLabel(row, opt, UDim2.new(0, PAD, 0, 0), UDim2.new(1, -PAD, 1, 0), T.Text).ZIndex = 62
		row.MouseEnter:Connect(function() tween(row, { BackgroundColor3 = T.DropdownHover }) end)
		row.MouseLeave:Connect(function() tween(row, { BackgroundColor3 = T.DropdownItem }) end)
		row.MouseButton1Click:Connect(function()
			selected       = opt
			headerLbl.Text = text .. "  " .. opt
			open           = false
			tween(panel, { Size = UDim2.new(1, 0, 0, 0) }, ANIM_MED)
			arrow.Text = "▾"
			if callback then callback(opt) end
		end)
	end

	header.MouseEnter:Connect(function() tween(header, { BackgroundColor3 = T.FrameBgHover }) end)
	header.MouseLeave:Connect(function() tween(header, { BackgroundColor3 = T.FrameBg }) end)
	header.MouseButton1Click:Connect(function()
		open = not open
		if open then
			tween(panel, { Size = UDim2.new(1, 0, 0, fullH) }, ANIM_MED)
			arrow.Text = "▴"
		else
			tween(panel, { Size = UDim2.new(1, 0, 0, 0) }, ANIM_MED)
			arrow.Text = "▾"
		end
	end)

	self:_push(ITEM_H)
	return {
		GetValue = function() return selected end,
	}
end

--// ─── TAB BAR ─────────────────────────────────────────────────────────────────

function ImGui:BeginTabBar(names)
	local barH = 24
	local y    = self._yOffset

	local bar = inst("Frame", {
		Parent           = self._content,
		Size             = UDim2.new(1, 0, 0, barH),
		Position         = UDim2.new(0, 0, 0, y),
		BackgroundColor3 = T.TabBar,
		BorderSizePixel  = 0,
	})

	inst("Frame", {
		Parent           = self._content,
		Size             = UDim2.new(1, 0, 0, 1),
		Position         = UDim2.new(0, 0, 0, y + barH),
		BackgroundColor3 = T.Separator,
		BorderSizePixel  = 0,
	})

	local tabW = math.floor(self.Width / #names)

	for i, name in ipairs(names) do
		local tabFrame = inst("Frame", {
			Parent               = self._content,
			Size                 = UDim2.new(1, 0, 0, 0),
			Position             = UDim2.new(0, 0, 0, y + barH + 2 + PAD),
			BackgroundTransparency = 1,
			Visible              = false,
			ClipsDescendants     = false,
			AutomaticSize        = Enum.AutomaticSize.Y,
		})

		self._tabs[name] = { frame = tabFrame, y = PAD, button = nil, underline = nil }

		local btn = inst("TextButton", {
			Parent           = bar,
			Size             = UDim2.new(0, tabW, 1, 0),
			Position         = UDim2.new(0, (i - 1) * tabW, 0, 0),
			BackgroundColor3 = T.Tab,
			Text             = name,
			TextColor3       = T.TextDisabled,
			Font             = FONT,
			TextSize         = FSIZE,
			BorderSizePixel  = 0,
			AutoButtonColor  = false,
		})

		--// active underline accent bar
		local underline = inst("Frame", {
			Parent               = btn,
			Size                 = UDim2.new(1, 0, 0, 2),
			Position             = UDim2.new(0, 0, 1, -2),
			BackgroundColor3     = T.SliderGrabActive,
			BorderSizePixel      = 0,
			BackgroundTransparency = 1,
		})

		self._tabs[name].button    = btn
		self._tabs[name].underline = underline

		btn.MouseEnter:Connect(function()
			if self._activeTab ~= name then tween(btn, { BackgroundColor3 = T.TabHovered }) end
		end)
		btn.MouseLeave:Connect(function()
			if self._activeTab ~= name then tween(btn, { BackgroundColor3 = T.Tab }) end
		end)
		btn.MouseButton1Click:Connect(function()
			if self._activeTab then
				local prev = self._tabs[self._activeTab]
				prev.frame.Visible     = false
				prev.button.TextColor3 = T.TextDisabled
				tween(prev.button,    { BackgroundColor3 = T.Tab })
				tween(prev.underline, { BackgroundTransparency = 1 })
			end
			self._activeTab  = name
			tabFrame.Visible = true
			btn.TextColor3   = T.Text
			tween(btn,       { BackgroundColor3 = T.TabActive })
			tween(underline, { BackgroundTransparency = 0 })
		end)
	end

	self._yOffset = self._yOffset + barH + 3 + PAD

	if #names > 0 then
		local first = names[1]
		self._activeTab = first
		self._tabs[first].frame.Visible              = true
		self._tabs[first].button.BackgroundColor3    = T.TabActive
		self._tabs[first].button.TextColor3          = T.Text
		self._tabs[first].underline.BackgroundTransparency = 0
	end
end

function ImGui:SetTab(name)
	if not self._tabs[name] then return end
	if self._activeTab then
		local prev = self._tabs[self._activeTab]
		prev.frame.Visible     = false
		prev.button.TextColor3 = T.TextDisabled
		tween(prev.button,    { BackgroundColor3 = T.Tab })
		tween(prev.underline, { BackgroundTransparency = 1 })
	end
	self._activeTab = name
	local t = self._tabs[name]
	t.frame.Visible  = true
	t.button.TextColor3 = T.Text
	tween(t.button,    { BackgroundColor3 = T.TabActive })
	tween(t.underline, { BackgroundTransparency = 0 })
end

return ImGui
