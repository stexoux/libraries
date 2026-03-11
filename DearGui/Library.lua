local ImGui = {}

ImGui.__index = ImGui

local TweenService = game:GetService('TweenService')
local UserInputService = game:GetService('UserInputService')
local RunService = game:GetService('RunService')
local THEME = {
    WindowBg = Color3.fromRGB(15, 15, 20),
    TitleBg = Color3.fromRGB(35, 50, 100),
    TitleBgActive = Color3.fromRGB(45, 65, 130),
    TitleBgCollapsed = Color3.fromRGB(30, 40, 80),
    FrameBg = Color3.fromRGB(40, 50, 80),
    FrameBgHover = Color3.fromRGB(55, 68, 105),
    FrameBgActive = Color3.fromRGB(70, 90, 140),
    Button = Color3.fromRGB(60, 80, 150),
    ButtonHover = Color3.fromRGB(75, 100, 175),
    ButtonActive = Color3.fromRGB(95, 125, 210),
    CheckMark = Color3.fromRGB(100, 200, 255),
    SliderGrab = Color3.fromRGB(90, 130, 220),
    SliderGrabActive = Color3.fromRGB(120, 165, 255),
    Tab = Color3.fromRGB(30, 40, 75),
    TabActive = Color3.fromRGB(55, 80, 150),
    TabHover = Color3.fromRGB(45, 65, 120),
    Separator = Color3.fromRGB(70, 85, 130),
    Border = Color3.fromRGB(80, 100, 160),
    Text = Color3.fromRGB(255, 255, 255),
    TextDim = Color3.fromRGB(160, 175, 210),
    Accent = Color3.fromRGB(90, 130, 220),
    Dropdown = Color3.fromRGB(20, 25, 45),
    DropdownItem = Color3.fromRGB(35, 45, 80),
    DropdownHover = Color3.fromRGB(60, 85, 150),
}
local FONT = Enum.Font.Code
local FONT_SIZE = 14
local PAD = 8
local ITEM_H = 24
local CORNER = 4

local function makeTween(obj, props, t)
    TweenService:Create(obj, TweenInfo.new(t or 0.12, Enum.EasingStyle.Quad), props):Play()
end
local function newInstance(class, props)
    local obj = Instance.new(class)

    for k, v in pairs(props)do
        obj[k] = v
    end

    return obj
end
local function label(parent, text, pos, size, color, fontSize, xAlign)
    return newInstance('TextLabel', {
        Parent = parent,
        Text = text,
        Position = pos or UDim2.new(0, 0, 0, 0),
        Size = size or UDim2.new(1, 0, 0, ITEM_H),
        BackgroundTransparency = 1,
        TextColor3 = color or THEME.Text,
        Font = FONT,
        TextSize = fontSize or FONT_SIZE,
        TextXAlignment = xAlign or Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
        ClipsDescendants = false,
    })
end
local function corner(parent, radius)
    newInstance('UICorner', {
        Parent = parent,
        CornerRadius = UDim.new(0, radius or CORNER),
    })
end
local function stroke(parent, color, thickness)
    newInstance('UIStroke', {
        Parent = parent,
        Color = color or THEME.Border,
        Thickness = thickness or 1,
    })
end
local function hoverable(frame, normal, hover)
    frame.MouseEnter:Connect(function()
        makeTween(frame, {BackgroundColor3 = hover})
    end)
    frame.MouseLeave:Connect(function()
        makeTween(frame, {BackgroundColor3 = normal})
    end)
end
local function makeDraggable(handle, target)
    local dragging, dragStart, startPos

    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = target.Position
        end
    end)
    handle.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            local delta = input.Position - dragStart

            target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

function ImGui.new(title, width, height)
    local self = setmetatable({}, ImGui)

    self.Width = width or 300
    self.Height = height or 400
    self._yOffset = 0
    self._tabs = {}
    self._activeTab = nil

    local screenGui = newInstance('ScreenGui', {
        Name = 'ImGuiLib',
        ResetOnSpawn = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent = game:GetService('CoreGui'),
    })
    local window = newInstance('Frame', {
        Name = 'Window',
        Parent = screenGui,
        Size = UDim2.new(0, self.Width, 0, self.Height),
        Position = UDim2.new(0.5, -self.Width / 2, 0.5, -self.Height / 2),
        BackgroundColor3 = THEME.WindowBg,
        BorderSizePixel = 0,
        ClipsDescendants = true,
    })

    corner(window, CORNER)
    stroke(window, THEME.Border, 1)

    local titleBar = newInstance('Frame', {
        Name = 'TitleBar',
        Parent = window,
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundColor3 = THEME.TitleBg,
        BorderSizePixel = 0,
        ZIndex = 10,
    })

    newInstance('UICorner', {
        Parent = titleBar,
        CornerRadius = UDim.new(0, CORNER),
    })

    local bottomCover = newInstance('Frame', {
        Parent = titleBar,
        Size = UDim2.new(1, 0, 0, CORNER),
        Position = UDim2.new(0, 0, 1, -CORNER),
        BackgroundColor3 = THEME.TitleBg,
        BorderSizePixel = 0,
        ZIndex = 10,
    })

    label(titleBar, title or 'ImGui Window', UDim2.new(0, 30, 0, 0), UDim2.new(1, -56, 1, 0), THEME.Text, FONT_SIZE, Enum.TextXAlignment.Left).ZIndex = 11

    local collapseBtn = newInstance('TextButton', {
        Parent = titleBar,
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(0, 4, 0.5, -10),
        BackgroundColor3 = Color3.fromRGB(60, 80, 140),
        Text = '\u{25bc}',
        TextColor3 = THEME.Text,
        Font = FONT,
        TextSize = 11,
        BorderSizePixel = 0,
        ZIndex = 12,
    })

    corner(collapseBtn, 3)

    local closeBtn = newInstance('TextButton', {
        Parent = titleBar,
        Size = UDim2.new(0, 20, 0, 20),
        Position = UDim2.new(1, -24, 0.5, -10),
        BackgroundColor3 = Color3.fromRGB(180, 60, 60),
        Text = '\u{d7}',
        TextColor3 = THEME.Text,
        Font = FONT,
        TextSize = 16,
        BorderSizePixel = 0,
        ZIndex = 12,
    })

    corner(closeBtn, 3)
    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)
    makeDraggable(titleBar, window)

    local collapsed = false
    local expandedSize = UDim2.new(0, self.Width, 0, self.Height)
    local collapsedSize = UDim2.new(0, self.Width, 0, 28)
    local content = newInstance('ScrollingFrame', {
        Name = 'Content',
        Parent = window,
        Size = UDim2.new(1, 0, 1, -28),
        Position = UDim2.new(0, 0, 0, 28),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 4,
        ScrollBarImageColor3 = THEME.Accent,
        CanvasSize = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    })

    collapseBtn.MouseButton1Click:Connect(function()
        collapsed = not collapsed

        if collapsed then
            collapseBtn.Text = '\u{25b6}'
            content.Visible = false

            makeTween(window, {Size = collapsedSize}, 0.15)
            makeTween(titleBar, {
                BackgroundColor3 = THEME.TitleBgCollapsed,
            }, 0.1)
        else
            collapseBtn.Text = '\u{25bc}'
            content.Visible = true

            makeTween(window, {Size = expandedSize}, 0.15)
            makeTween(titleBar, {
                BackgroundColor3 = THEME.TitleBgActive,
            }, 0.1)
        end
    end)

    self._gui = screenGui
    self._window = window
    self._content = content
    self._yOffset = PAD

    return self
end
function ImGui:_nextY()
    local y = self._yOffset

    return y
end
function ImGui:_advance(h)
    self._yOffset = self._yOffset + h + 4
end
function ImGui:_activeContent()
    if self._activeTab and self._tabs[self._activeTab] then
        return self._tabs[self._activeTab].frame
    end

    return self._content
end
function ImGui:Separator()
    local parent = self:_activeContent()
    local y = self:_nextY()

    newInstance('Frame', {
        Parent = parent,
        Size = UDim2.new(1, -PAD * 2, 0, 1),
        Position = UDim2.new(0, PAD, 0, y + 4),
        BackgroundColor3 = THEME.Separator,
        BorderSizePixel = 0,
    })
    self:_advance(9)
end
function ImGui:Text(text, color)
    local parent = self:_activeContent()
    local y = self:_nextY()

    label(parent, text, UDim2.new(0, PAD, 0, y), UDim2.new(1, -PAD * 2, 0, ITEM_H), color or THEME.Text)
    self:_advance(ITEM_H)
end
function ImGui:Button(text, callback)
    local parent = self:_activeContent()
    local y = self:_nextY()
    local btn = newInstance('TextButton', {
        Parent = parent,
        Size = UDim2.new(1, -PAD * 2, 0, ITEM_H),
        Position = UDim2.new(0, PAD, 0, y),
        BackgroundColor3 = THEME.Button,
        Text = text,
        TextColor3 = THEME.Text,
        Font = FONT,
        TextSize = FONT_SIZE,
        BorderSizePixel = 0,
        AutoButtonColor = false,
    })

    corner(btn)
    stroke(btn, THEME.Border, 1)
    btn.MouseEnter:Connect(function()
        makeTween(btn, {
            BackgroundColor3 = THEME.ButtonHover,
        })
    end)
    btn.MouseLeave:Connect(function()
        makeTween(btn, {
            BackgroundColor3 = THEME.Button,
        })
    end)
    btn.MouseButton1Down:Connect(function()
        makeTween(btn, {
            BackgroundColor3 = THEME.ButtonActive,
        })
    end)
    btn.MouseButton1Up:Connect(function()
        makeTween(btn, {
            BackgroundColor3 = THEME.ButtonHover,
        })

        if callback then
            callback()
        end
    end)
    self:_advance(ITEM_H)

    return btn
end
function ImGui:Checkbox(text, default, callback)
    local parent = self:_activeContent()
    local y = self:_nextY()
    local state = default or false
    local row = newInstance('Frame', {
        Parent = parent,
        Size = UDim2.new(1, -PAD * 2, 0, ITEM_H),
        Position = UDim2.new(0, PAD, 0, y),
        BackgroundTransparency = 1,
    })
    local box = newInstance('Frame', {
        Parent = row,
        Size = UDim2.new(0, 16, 0, 16),
        Position = UDim2.new(0, 0, 0.5, -8),
        BackgroundColor3 = THEME.FrameBg,
        BorderSizePixel = 0,
    })

    corner(box, 3)
    stroke(box, THEME.Border, 1)

    local check = newInstance('Frame', {
        Parent = box,
        Size = UDim2.new(0, 10, 0, 10),
        Position = UDim2.new(0.5, -5, 0.5, -5),
        BackgroundColor3 = THEME.CheckMark,
        BorderSizePixel = 0,
        BackgroundTransparency = state and 0 or 1,
    })

    corner(check, 2)
    label(row, text, UDim2.new(0, 24, 0, 0), UDim2.new(1, -24, 1, 0), THEME.Text)

    local hitbox = newInstance('TextButton', {
        Parent = row,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = '',
    })

    hitbox.MouseButton1Click:Connect(function()
        state = not state

        makeTween(check, {
            BackgroundTransparency = state and 0 or 1,
        })
        makeTween(box, {
            BackgroundColor3 = state and THEME.FrameBgActive or THEME.FrameBg,
        })

        if callback then
            callback(state)
        end
    end)
    self:_advance(ITEM_H)

    return {
        GetValue = function()
            return state
        end,
        SetValue = function(v)
            state = v
            check.BackgroundTransparency = v and 0 or 1
            box.BackgroundColor3 = v and THEME.FrameBgActive or THEME.FrameBg
        end,
    }
end
function ImGui:Slider(text, min, max, default, callback)
    local parent = self:_activeContent()
    local y = self:_nextY()
    local value = math.clamp(default or min, min, max)
    local totalH = ITEM_H + 6
    local lbl = label(parent, text .. ': ' .. tostring(math.floor(value)), UDim2.new(0, PAD, 0, y), UDim2.new(1, -PAD * 2, 0, ITEM_H - 8), THEME.Text)
    local track = newInstance('Frame', {
        Parent = parent,
        Size = UDim2.new(1, -PAD * 2, 0, 6),
        Position = UDim2.new(0, PAD, 0, y + ITEM_H - 4),
        BackgroundColor3 = THEME.FrameBg,
        BorderSizePixel = 0,
    })

    corner(track, 3)
    stroke(track, THEME.Border, 1)

    local fill = newInstance('Frame', {
        Parent = track,
        Size = UDim2.new((value - min) / (max - min), 0, 1, 0),
        BackgroundColor3 = THEME.Accent,
        BorderSizePixel = 0,
    })

    corner(fill, 3)

    local grab = newInstance('Frame', {
        Parent = track,
        Size = UDim2.new(0, 12, 0, 12),
        Position = UDim2.new((value - min) / (max - min), -6, 0.5, -6),
        BackgroundColor3 = THEME.SliderGrab,
        BorderSizePixel = 0,
        ZIndex = 5,
    })

    corner(grab, 6)
    stroke(grab, THEME.Border, 1)

    local dragging = false

    local function updateSlider(inputX)
        local absPos = track.AbsolutePosition.X
        local absSize = track.AbsoluteSize.X
        local t = math.clamp((inputX - absPos) / absSize, 0, 1)
        local v = math.floor(min + t * (max - min))

        value = v

        local pct = (v - min) / (max - min)

        fill.Size = UDim2.new(pct, 0, 1, 0)
        grab.Position = UDim2.new(pct, -6, 0.5, -6)
        lbl.Text = text .. ': ' .. tostring(v)
        grab.BackgroundColor3 = THEME.SliderGrabActive

        if callback then
            callback(v)
        end
    end

    track.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true

            updateSlider(input.Position.X)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(input.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false

            makeTween(grab, {
                BackgroundColor3 = THEME.SliderGrab,
            })
        end
    end)
    self:_advance(totalH + 6)

    return {
        GetValue = function()
            return value
        end,
        SetValue = function(v)
            value = math.clamp(v, min, max)

            local pct = (value - min) / (max - min)

            fill.Size = UDim2.new(pct, 0, 1, 0)
            grab.Position = UDim2.new(pct, -6, 0.5, -6)
            lbl.Text = text .. ': ' .. tostring(math.floor(value))
        end,
    }
end
function ImGui:Dropdown(text, options, default, callback)
    local parent = self:_activeContent()
    local y = self:_nextY()
    local selected = default or options[1]
    local open = false
    local wrapper = newInstance('Frame', {
        Parent = parent,
        Size = UDim2.new(1, -PAD * 2, 0, ITEM_H),
        Position = UDim2.new(0, PAD, 0, y),
        BackgroundTransparency = 1,
        ClipsDescendants = false,
        ZIndex = 20,
    })
    local header = newInstance('TextButton', {
        Parent = wrapper,
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = THEME.FrameBg,
        Text = '',
        BorderSizePixel = 0,
        AutoButtonColor = false,
        ZIndex = 20,
    })

    corner(header)
    stroke(header, THEME.Border, 1)

    label(header, text .. ': ' .. selected, UDim2.new(0, PAD, 0, 0), UDim2.new(1, -30, 1, 0), THEME.Text).ZIndex = 21

    local arrow = label(header, '\u{25be}', UDim2.new(1, -22, 0, 0), UDim2.new(0, 18, 1, 0), THEME.TextDim, FONT_SIZE, Enum.TextXAlignment.Center)

    arrow.ZIndex = 21

    local dropFrame = newInstance('Frame', {
        Parent = wrapper,
        Size = UDim2.new(1, 0, 0, 0),
        Position = UDim2.new(0, 0, 1, 2),
        BackgroundColor3 = THEME.Dropdown,
        BorderSizePixel = 0,
        ClipsDescendants = true,
        ZIndex = 50,
    })

    corner(dropFrame)
    stroke(dropFrame, THEME.Border, 1)

    local itemList = newInstance('Frame', {
        Parent = dropFrame,
        Size = UDim2.new(1, 0, 0, #options * (ITEM_H + 2) + 4),
        Position = UDim2.new(0, 0, 0, 2),
        BackgroundTransparency = 1,
        ZIndex = 51,
    })
    local itemHeight = ITEM_H + 2
    local fullH = #options * itemHeight + 4

    for i, opt in ipairs(options)do
        local item = newInstance('TextButton', {
            Parent = itemList,
            Size = UDim2.new(1, -4, 0, ITEM_H),
            Position = UDim2.new(0, 2, 0, (i - 1) * itemHeight + 2),
            BackgroundColor3 = THEME.DropdownItem,
            Text = '',
            BorderSizePixel = 0,
            AutoButtonColor = false,
            ZIndex = 52,
        })

        corner(item, 3)

        label(item, opt, UDim2.new(0, PAD, 0, 0), UDim2.new(1, -PAD, 1, 0), THEME.Text).ZIndex = 53

        item.MouseEnter:Connect(function()
            makeTween(item, {
                BackgroundColor3 = THEME.DropdownHover,
            })
        end)
        item.MouseLeave:Connect(function()
            makeTween(item, {
                BackgroundColor3 = THEME.DropdownItem,
            })
        end)
        item.MouseButton1Click:Connect(function()
            selected = opt

            for _, c in ipairs(header:GetChildren())do
                if c:IsA('TextLabel') then
                    c.Text = text .. ': ' .. opt
                end
            end

            open = false

            makeTween(dropFrame, {
                Size = UDim2.new(1, 0, 0, 0),
            })

            arrow.Text = '\u{25be}'

            if callback then
                callback(opt)
            end
        end)
    end

    header.MouseButton1Click:Connect(function()
        open = not open

        if open then
            makeTween(dropFrame, {
                Size = UDim2.new(1, 0, 0, fullH),
            })

            arrow.Text = '\u{25b4}'
        else
            makeTween(dropFrame, {
                Size = UDim2.new(1, 0, 0, 0),
            })

            arrow.Text = '\u{25be}'
        end
    end)
    hoverable(header, THEME.FrameBg, THEME.FrameBgHover)
    self:_advance(ITEM_H)

    return {
        GetValue = function()
            return selected
        end,
    }
end
function ImGui:BeginTabBar(tabNames)
    local barH = 28
    local y = self:_nextY()
    local bar = newInstance('Frame', {
        Parent = self._content,
        Size = UDim2.new(1, 0, 0, barH),
        Position = UDim2.new(0, 0, 0, y),
        BackgroundColor3 = THEME.TitleBg,
        BorderSizePixel = 0,
    })
    local tabW = math.floor(self.Width / #tabNames)

    for i, name in ipairs(tabNames)do
        local tabFrame = newInstance('Frame', {
            Parent = self._content,
            Size = UDim2.new(1, 0, 1, -(y + barH + PAD)),
            Position = UDim2.new(0, 0, 0, y + barH + PAD),
            BackgroundTransparency = 1,
            Visible = false,
            ClipsDescendants = false,
        })

        self._tabs[name] = {
            frame = tabFrame,
            yOffset = PAD,
            button = nil,
        }

        local btn = newInstance('TextButton', {
            Parent = bar,
            Size = UDim2.new(0, tabW, 1, 0),
            Position = UDim2.new(0, (i - 1) * tabW, 0, 0),
            BackgroundColor3 = THEME.Tab,
            Text = name,
            TextColor3 = THEME.TextDim,
            Font = FONT,
            TextSize = FONT_SIZE,
            BorderSizePixel = 0,
            AutoButtonColor = false,
        })

        self._tabs[name].button = btn

        btn.MouseEnter:Connect(function()
            if self._activeTab ~= name then
                makeTween(btn, {
                    BackgroundColor3 = THEME.TabHover,
                })
            end
        end)
        btn.MouseLeave:Connect(function()
            if self._activeTab ~= name then
                makeTween(btn, {
                    BackgroundColor3 = THEME.Tab,
                })
            end
        end)
        btn.MouseButton1Click:Connect(function()
            if self._activeTab then
                local prev = self._tabs[self._activeTab]

                prev.frame.Visible = false

                makeTween(prev.button, {
                    BackgroundColor3 = THEME.Tab,
                })

                prev.button.TextColor3 = THEME.TextDim
            end

            self._activeTab = name
            self._tabs[name].frame.Visible = true

            makeTween(btn, {
                BackgroundColor3 = THEME.TabActive,
            })

            btn.TextColor3 = THEME.Text
        end)
    end

    self:_advance(barH + PAD)

    if #tabNames > 0 then
        local first = tabNames[1]

        self._activeTab = first
        self._tabs[first].frame.Visible = true
        self._tabs[first].button.BackgroundColor3 = THEME.TabActive
        self._tabs[first].button.TextColor3 = THEME.Text
    end
end
function ImGui:SetTab(name)
    if not self._tabs[name] then
        return
    end
    if self._activeTab then
        local prev = self._tabs[self._activeTab]

        prev.frame.Visible = false

        makeTween(prev.button, {
            BackgroundColor3 = THEME.Tab,
        })

        prev.button.TextColor3 = THEME.TextDim
    end

    self._activeTab = name

    local t = self._tabs[name]

    t.frame.Visible = true

    makeTween(t.button, {
        BackgroundColor3 = THEME.TabActive,
    })

    t.button.TextColor3 = THEME.Text
end

local _origNextY = ImGui._nextY
local _origAdvance = ImGui._advance

function ImGui:_nextY()
    if self._activeTab and self._tabs[self._activeTab] then
        return self._tabs[self._activeTab].yOffset or PAD
    end

    return self._yOffset
end
function ImGui:_advance(h)
    if self._activeTab and self._tabs[self._activeTab] then
        self._tabs[self._activeTab].yOffset = (self._tabs[self._activeTab].yOffset or PAD) + h + 4
    else
        self._yOffset = self._yOffset + h + 4
    end
end

return ImGui
