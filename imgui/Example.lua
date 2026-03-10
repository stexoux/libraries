local ImGui = loadstring(game:HttpGet("https://raw.githubusercontent.com/15158157157/libraries/refs/heads/main/imgui/library.lua"))()

local Window = ImGui:CreateWindow({
    Title = "Window",
    Size = UDim2.fromOffset(300, 400),
})

local Tab = Window:CreateTab({ Name = "Main", Visible = true })

Tab:Button({
    Label = "Click Me",
    Callback = function()
        print("clicked!")
    end
})

Tab:Slider({
    Label = "Speed",
    Value = 50,
    MinValue = 0,
    MaxValue = 100,
    Callback = function(self, val)
        print("Speed:", val)
    end
})

Tab:Checkbox({
    Label = "Enable",
    Value = false,
    Callback = function(self, val)
        print("Toggled:", val)
    end
})

Tab:Combo({
    Label = "Mode",
    Items = { "Walk", "Fly", "Noclip" },
    Selected = "Walk",
    Callback = function(self, val)
        print("Selected:", val)
    end
})

Tab:InputText({
    Label = "Name",
    PlaceHolder = "Enter name...",
    Callback = function(self, text)
        print("Input:", text)
    end
})
