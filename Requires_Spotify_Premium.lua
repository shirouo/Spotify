
repeat wait() until game:IsLoaded();
if getgenv()["SpotifyUI"] then if game["CoreGui"]:FindFirstChild("Spotify"):Destroy() then game["CoreGui"]["Spotify"]:Destroy() end; warn("[SPOTIFY]: Spotify UI already loaded!") end
getgenv()["Token"] = _G["SpotifyConfig"]["Token"];
 
if not isfolder("RSpotify") then makefolder("RSpotify") end
 
-- Services
local Services = {
	["P"] = game:GetService("Players"), ["HTTP"] = game:GetService("HttpService"), ["TS"] = game:GetService("TweenService"), ["CG"] = game:GetService("CoreGui"), ["UIS"] = game:GetService("UserInputService");
};
 
-- Variables
local Client, Device, HttpRequest, ProtectUI
do
	Client = Services["P"]["LocalPlayer"]
	Device = nil
	HttpRequest = (syn and syn.request) or (request)
	ProtectUI = (syn and syn.protect_gui) or (gethui)
	customAsset = getsynasset or getcustomasset
end;
 
-- Values
local CurrentTab = "Home"
local FolderPath = "RSpotify/"
 
-- Booleans
local ValidToken = false
local Minimized, DraggingSlider = false, false
local Timebar = false
local IsShuffle, IsRepeat, IsPaused = false, false, false
 
-- Tables
local char_to_hex = function(c)
    return string.format("%%%02X", string.byte(c))
end
 
local urlencode = function(url)
    if (url == nil) then
        return
    end
 
    url = url:gsub("\n", "\r\n")
    url = url:gsub("([^%w _%%%-%.~])", char_to_hex)
    url = url:gsub(" ", "+")
    return url
end
 
local CurrentData, SpotifyHosts, UserPlaylists, SongNameToID = {}, {
	["api"] = "https://api.spotify.com/v1/", ["account"] = "https://accounts.spotify.com/api/";
}, {}, {}; local apiRequests = {
	["nowplaying"] = function(returnResults)
		local Data
			Data = HttpRequest({
				Url = SpotifyHosts["api"] .. "me/player/currently-playing",
				Method = "GET",
				Headers = {["Content-Type"] = "application/json", ["Authorization"] = "Bearer " .. _G["SpotifyConfig"]["Token"]};
			}); wait(0.15);
			pcall(function()
				Data = Services["HTTP"]:JSONDecode(Data["Body"]);
			end); wait(0.5)
            if Data["item"]["artists"] and #Data["item"]["artists"] >= 1 then
                local artists = "";
                for i = 1, #Data["item"]["artists"] do
                    if i ~= #Data["item"]["artists"] then
                        artists = artists .. Data["item"]["artists"][i]["name"] .. ", "
                    else artists = artists .. Data["item"]["artists"][i]["name"]
                    end
                end;
                if #Data["item"]["album"]["images"] >= 1 then
                    if not returnResults then
                        CurrentData = {["Artist"] = artists, ["Song"] = Data["item"]["name"], ["URL"] = Data["item"]["album"]["images"][1]["url"]};
                    else
                        return {["Artist"] = artists, ["Song"] = Data["item"]["name"], ["URL"] = Data["item"]["album"]["images"][1]["url"]};
                    end 
                end
			end  
	end,
	["getDevice"] = function()
		local Data = HttpRequest({
			Url = SpotifyHosts["api"] .. "me/player/devices",
			Method = "GET",
			Headers = {["Content-Type"] = "application/json", ["Authorization"] = "Bearer " .. _G["SpotifyConfig"]["Token"]};
		}); wait(0.15);
		if Data then
            pcall(function()
                Data = Services["HTTP"]:JSONDecode(Data["Body"]);
            end); return Data["devices"][1]["id"]
		end
	end,
	["timePos"] = function()
		local Data = HttpRequest({
			Url = SpotifyHosts["api"] .. "me/player",
			Method = "GET",
			Headers = {["Content-Type"] = "application/json", ["Authorization"] = "Bearer " .. _G["SpotifyConfig"]["Token"]};
		});
		if Data then
			pcall(function()
				Data = Services["HTTP"]:JSONDecode(Data["Body"]);
			end)
			if Data then
                if Data["progress_ms"] then
                    return {["Current"] = Data["progress_ms"], ["Length"] = Data["item"]["duration_ms"]}; 
                end
			end
		end
	end,
	["pause"] = function(device)
		local Data = HttpRequest({
			Url = SpotifyHosts["api"] .. "me/player/pause",
			Method = "PUT",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. _G["SpotifyConfig"]["Token"],
			},
		});
	end,
	["resume"] = function(device)
		local Data = HttpRequest({
			Url = SpotifyHosts["api"] .. "me/player/play",
			Method = "PUT",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. _G["SpotifyConfig"]["Token"],
			},
			Body = { ["device_id"] = Device }
		});
	end,
	["skip"] = function()
		local Data = HttpRequest({
			Url = SpotifyHosts["api"] .. "me/player/next",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. _G["SpotifyConfig"]["Token"],
			},
		});
	end,
	["previous"] = function()
		local Data = HttpRequest({
			Url = SpotifyHosts["api"] .. "me/player/previous",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. _G["SpotifyConfig"]["Token"],
			},
		});
	end,
	["playlists"] = function()
		local Data = HttpRequest({
			Url = SpotifyHosts["api"] .. "me/playlists",
			Method = "GET",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. _G["SpotifyConfig"]["Token"],
			},
		}); if Data then
            pcall(function()
                Data = Services["HTTP"]:JSONDecode(Data["Body"])
            end); return Data["items"]
        end
	end,
    ["getLikedSongs"] = function(Offset)
        local Data = HttpRequest({
            Url = SpotifyHosts["api"] .. "me/tracks?market=ES&limit=50&offset=" .. Offset,
			Method = "GET",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. _G["SpotifyConfig"]["Token"],
			},
        }); 
        if Data then
            pcall(function()
                Data = Services["HTTP"]:JSONDecode(Data["Body"]);
            end); return Data["items"]
        end
    end,
    ["queueSong"] = function(URI)
        local Data = HttpRequest({
            Url = SpotifyHosts["api"] .. "me/player/queue?uri=" .. URI,
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. _G["SpotifyConfig"]["Token"],
			},
        }); 
    end,
    ["playPlaylist"] = function(uri)
        local Data = HttpRequest({
            Url = SpotifyHosts["api"] .. "me/player/play",
			Method = "POST",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. _G["SpotifyConfig"]["Token"],
			},
            Body = {
                ["context_uri"] = uri,
                ["offset"] = {
                    ["position"] = 0
                }
            }
        });
    end,
    ["getPlaylistTracks"] = function(id)
        local Data = HttpRequest({
            Url = SpotifyHosts["api"] .. "playlists/" .. id .. "/tracks",
			Method = "GET",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. _G["SpotifyConfig"]["Token"],
			},
        });
        if Data then
            pcall(function()
                Data = Services["HTTP"]:JSONDecode(Data["Body"])
            end); return Data
        end
    end,
    ["toggleShuffle"] = function(status)
        local Data = HttpRequest({
            Url = SpotifyHosts["api"] .. "me/player/shuffle?state=" .. tostring(status),
			Method = "PUT",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. _G["SpotifyConfig"]["Token"],
			},
        });
    end,
    ["toggleRepeat"] = function(status)
        local statusToResponse = {["true"] = "track", ["false"] = "off"}
        local Data = HttpRequest({
            Url = SpotifyHosts["api"] .. "me/player/repeat?state=" .. statusToResponse[tostring(status)],
			Method = "PUT",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. _G["SpotifyConfig"]["Token"],
			},
        });
    end,
    ["setVol"] = function(num)
        local Data = HttpRequest({
            Url = SpotifyHosts["api"] .. "me/player/volume?volume_percent=" .. num,
			Method = "PUT",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. _G["SpotifyConfig"]["Token"],
			},
        });
    end,
    ["getProfile"] = function()
        local typeToPremStatus = {["open"] = false, ["free"] = false, ["premium"] = true}
        local Data = HttpRequest({
            Url = SpotifyHosts["api"] .. "me",
            Method = "GET",
            Headers = {
                ["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. _G["SpotifyConfig"]["Token"],
            };
        }); if Data then
            pcall(function()
                Data = Services["HTTP"]:JSONDecode(Data["Body"]);
            end); wait(0.15);
            local Return = {["Display"] = Data["display_name"], ["premium"] = typeToPremStatus[Data.product:lower()], ["Avatar"] = nil}
            if #Data["images"] >= 1 then
                Return["Avatar"] = Data["images"][1]["url"]
            end; return Return
        end
    end,
    ["search"] = function(songName)
        local Data = HttpRequest({
            Url = SpotifyHosts["api"] .. "search?q=" .. urlencode(songName) .. "&type=track&limit=50",
			Method = "GET",
			Headers = {
				["Content-Type"] = "application/json",
				["Authorization"] = "Bearer " .. _G["SpotifyConfig"]["Token"],
			},
        }); if Data then
            pcall(function()
                Data = Services["HTTP"]:JSONDecode(Data["Body"]);
            end);
            if Data["tracks"] then
                if Data["tracks"]["items"] then
                    return Data["tracks"]["items"];
                end
            end
        end
    end,
    --["lastPlayed"]
};
 
-- System Functions
local New = function(Class, Properties)
	local Obj, Properties = Instance.new(Class), Properties or {}
    if Obj:IsA("GuiObject") then Obj["AnchorPoint"] = Vector2.new(0.5, 0.5); Obj["BorderSizePixel"] = 0 end;
	for I, V in pairs(Properties) do if rawequal(I, "Parent") then continue end; Obj[I] = V end
	if Properties["Parent"] then Obj["Parent"] = Properties["Parent"] end; return Obj;
end
 
 
local Tween = function(I, T, S, D, G)
	coroutine.wrap(function()
		return Services["TS"]:Create(I, TweenInfo.new(T, Enum["EasingStyle"][S], Enum["EasingDirection"][D]), G):Play();
	end)()
end
 
local drag = function(obj, latency)
	obj = obj; latency = latency or 0.06
 
	local Toggled, Input, Start, startPos = nil, nil, nil, nil
 
	local function update(input)
		local D = input["Position"] - Start;
		local Position = UDim2.new(startPos["X"]["Scale"], startPos["X"]["Offset"] + D["X"], startPos["Y"]["Scale"], startPos["Y"]["Offset"] + D["Y"]);
		Tween(obj, latency, "Quint", "Out", {Position = Position});
	end
 
	obj["InputBegan"]:Connect(function(input)
		if input["UserInputType"] == Enum["UserInputType"]["MouseButton1"] then
			Toggled = true; Start = input["Position"]; startPos = obj["Position"];
			input["Changed"]:Connect(function()
				if input["UserInputState"] == Enum["UserInputState"]["End"] then
					Toggled = false
				end
			end)
		end
	end)
 
	obj["InputChanged"]:Connect(function(input)
		if input["UserInputType"] == Enum["UserInputType"]["MouseMovement"] then
			Input = input;
		end
	end)
 
	game["UserInputService"]["InputChanged"]:Connect(function(input)
		if input == Input and Toggled then
			update(input)
		end
	end);
end
 
local function SetIcon(url, fileName)
    fileName = fileName:gsub("%p", "");
    local Image
    if isfile(FolderPath .. fileName .. ".png") then
        Image = customAsset(FolderPath .. fileName .. ".png") 
    else writefile(FolderPath .. fileName .. ".png", game:HttpGet(url));
        Image = customAsset(FolderPath.. fileName .. ".png")
    end; return Image
end
 
local checkToken = function()
	local Data = HttpRequest({
		Url = SpotifyHosts["api"] .. "me/",
		Method = "GET",
		Headers = {["Content-Type"] = "application/json", ["Authorization"] = "Bearer " .. _G["SpotifyConfig"]["Token"]};
	}); wait(0.05);
	if Data then
        pcall(function()
            Data = Services["HTTP"]:JSONDecode(Data["Body"])
        end)
		if Data["display_name"] then
            ValidToken = true; return true
        end
	end; return false
end
 
local function UpdatePageSize(Layout, Container)
	local Correction = Layout["AbsoluteContentSize"];
	Container["CanvasSize"] = UDim2.new(0, 0, 0, Correction["Y"] + (#Container:GetChildren() + 15))
end
 
-- UI [ This is going to really fucking suck ]
local Spotify = Instance.new("ScreenGui");
Spotify["Name"] = "Spotify"; Spotify["ResetOnSpawn"] = false; Spotify["IgnoreGuiInset"] = true;
ProtectUI(Spotify); Spotify["Parent"] = Services["CG"]; Spotify["ZIndexBehavior"] = "Global";
 
-- Notification Holder
local NotificationHolder = New("Frame", {["Parent"] = Spotify, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.92, 0, 0.576, 0), ["Size"] = UDim2.new(0.15, 0, 0.83, 0)});
local NotificationList = New("UIListLayout", {["Parent"] = NotificationHolder, ["Padding"] = UDim.new(0, 20), ["HorizontalAlignment"] = "Center", ["VerticalAlignment"] = "Bottom"});
 
local Notify = function(Message, Type, Time)
    coroutine.wrap(function()
        local TypeToColor = { ["error"] = Color3.fromRGB(212, 21, 21), ['normal'] = Color3.new(1, 1, 1) };
        local Notif = New("Frame", {["Parent"] = NotificationHolder, ["BackgroundColor3"] = Color3.fromRGB(25, 25, 25), ["Size"] = UDim2.new(0, 0, 0.093, 0)});
        New("UICorner", {["Parent"] = Notif, ["CornerRadius"] = UDim.new(1, 0)});
        local SpotifyIcon = New("ImageLabel", {["Parent"] = Notif, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.128, 0, 0.5, 0), ["Size"] = UDim2.new(0, 50, 0, 50),
        ["Image"] = SetIcon("https://projectpulso.org/wp-content/uploads/2020/09/spotify-download-logo-30-2.png", "SpotifyIcon")})
        New("UICorner", {["Parent"] = SpotifyIcon, ["CornerRadius"] = UDim.new(1, 0)});
        local MsgText = New("TextLabel", {["Parent"] = Notif, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.57, 0, 0.626, 0), ["Size"] = UDim2.new(0.643, 0, 0.529, 0),
        ["Font"] = "Gotham", ["TextColor3"] = TypeToColor[Type:lower()] or Color3.new(1, 1, 1), ["TextScaled"] = true, ["TextXAlignment"] = "Left", ["Text"] = Message});
        New("UITextSizeConstraint", {["Parent"] = MsgText, ["MaxTextSize"] = 14});
        local Title = New("TextLabel", {['Parent'] = Notif, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.4, 0, 0.217, 0), ["Size"] = UDim2.new(0.3, 0, 0.29, 0),
        ["Font"] = "GothamMedium", ["Text"] = "Spotify", ["TextColor3"] = Color3.fromRGB(29, 185, 84), ["TextScaled"] = true, ["TextXAlignment"] = "Left"});
        New("UITextSizeConstraint", {["Parent"] = Title, ["MaxTextSize"] = 16});
        Tween(Notif, 0.5, "Quint", "Out", {Size = UDim2.new(0.951, 0, 0.093, 0)}); wait(Time + 0.5);
        Tween(Notif, 0.5, "Quint", "In", {Size = UDim2.new(0, 0, 0.093, 0)}); wait(0.51); Notif:Destroy();
    end)()
end
 
-- Check Token
if not checkToken() then
    Notify("Invalid Token, please update it!", "error", 3)
else
    Notify("Valid Token!\nChecking Premium..", "normal", 3);
    if (not apiRequests["getProfile"]()["premium"]) or (apiRequests["getProfile"]()["premium"] == nil) then
        Notify("Not a Spotify Premium user!\nLoading V1..", "error", 3)
        loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/thehorrorevent/Spotify/main/SpotifyV1.lua", true))()
    else
        Notify("You're a Spotify Premium user!", "normal", 3)
        Device = apiRequests["getDevice"](); apiRequests["nowplaying"](); apiRequests["playlists"](); getgenv()["SpotifyUI"] = true;
 
        local HolderHideFrame = New("Frame", {["Parent"] = Spotify, ["BackgroundTransparency"] = 1, ["Size"] = UDim2.new(0.365, 0, 0.484, 0), ["Position"] = UDim2.new(0.5, 0, 0.5, 0), ["ClipsDescendants"] = true});
        local MainFrame = New("Frame", {["Parent"] = HolderHideFrame, ["BackgroundColor3"] = Color3.fromRGB(9, 9, 9), 
            ["Size"] = UDim2.new(1, 0, 1, 0); ["Position"] = UDim2.new(0.5, 0, 0.5, 0); ["ZIndex"] = 1;
        }); drag(HolderHideFrame, 0.025)
 
        -- Button Holder
        local ButtonHolder = New("Frame", {["Parent"] = MainFrame, ["BackgroundTransparency"] = 1, ["Size"] = UDim2.new(0.26, 0, 0.092, 0), ["Position"] = UDim2.new(0.5, 0, 0.9, 0)});
        New("UIListLayout", {["Parent"] = ButtonHolder, ["Padding"] = UDim.new(0, 37), ["FillDirection"] = "Horizontal", ["HorizontalAlignment"] = "Center", ["VerticalAlignment"] = "Center", ["SortOrder"] = "LayoutOrder"});
        local PausePlayButton = New("ImageButton", {["Parent"] = ButtonHolder,["AutoButtonColor"] = false; ["BackgroundTransparency"] = 1; ["LayoutOrder"] = 2; ["Size"] = UDim2.new(0, 30, 0, 30), ["ZIndex"] = 3, ["Image"] = "rbxassetid://3926307971", ["ImageColor3"] = Color3.new(0, 0, 0),
        ["ImageRectOffset"] = Vector2.new(804, 124), ["ImageRectSize"] = Vector2.new(36, 36)});
        local PlayButtonBackground = New("Frame", {["Parent"] = PausePlayButton, ["BackgroundTransparency"] = 0, ["BackgroundColor3"] = Color3.new(1, 1, 1), ["Position"] = UDim2.new(0.5, 0, 0.5, 0), ["Size"] = UDim2.new(1, 0, 1, 0), ["ZIndex"] = 2});
        New("UICorner", {["Parent"] = PlayButtonBackground, ["CornerRadius"] = UDim.new(1, 0)});
        local Previous = New("ImageButton", {["Parent"] = ButtonHolder, ["BackgroundTransparency"] = 1; ["AutoButtonColor"] = false, ["Size"] = UDim2.new(0, 30, 0, 30), ["ZIndex"] = 2; ["LayoutOrder"] = 1,
        ["Image"] = "rbxassetid://3926307971", ["ImageRectOffset"] = Vector2.new(364, 364), ["ImageRectSize"] = Vector2.new(36, 36)}); 
        local Skip = New("ImageButton", {["Parent"] = ButtonHolder, ["BackgroundTransparency"] = 1; ["AutoButtonColor"] = false, ["Size"] = UDim2.new(0, 30, 0, 30), ["ZIndex"] = 2; ["LayoutOrder"] = 3,
        ["Image"] = "rbxassetid://3926307971", ["ImageRectOffset"] = Vector2.new(724, 324), ["ImageRectSize"] = Vector2.new(36, 36)}); 
        local Shuffle = New("ImageButton", {["Parent"] = ButtonHolder, ["BackgroundTransparency"] = 1, ["AutoButtonColor"] = false, ["LayoutOrder"] = 0, ["Size"] = UDim2.new(0, 20, 0, 20), ["Image"] = "rbxassetid://3926307971", 
        ["ImageRectOffset"] = Vector2.new(164, 44), ["ImageRectSize"] = Vector2.new(36, 36)});
        local Repeat = New("ImageButton", {["Parent"] = ButtonHolder, ["BackgroundTransparency"] = 1, ["AutoButtonColor"] = false, ["LayoutOrder"] = 4, ["Size"] = UDim2.new(0, 20, 0, 20), ["Image"] = "rbxassetid://3926307971", 
        ["ImageRectOffset"] = Vector2.new(564, 444), ["ImageRectSize"] = Vector2.new(36, 36)});
 
        -- Timebar
        local Timebar = New("Frame", {["Parent"] = MainFrame, ["BackgroundColor3"] = Color3.fromRGB(52, 52, 52), ["Position"] = UDim2.new(0.5, 0, 0.968, 0), ["Size"] = UDim2.new(0.405, 0, 0, 4), ["ZIndex"] = 1});
        New("UICorner", {["Parent"] = Timebar, ["CornerRadius"] = UDim.new(1, 0)});
        New("UIListLayout", {["Parent"] = Timebar, ["VerticalAlignment"] = "Center"});
        local Bar = New("Frame", {["Parent"] = Timebar, ["Size"] = UDim2.new(0, 0, 1, 0)});
        New("UICorner", {["Parent"] = Bar, ["CornerRadius"] = UDim.new(1, 0)});
 
        -- Volume Slider
        local VolumeSliderHolder = New("Frame", {['Parent'] = MainFrame, ["BackgroundColor3"] = Color3.fromRGB(52, 52, 52), ["Position"] = UDim2.new(0.906, 0, 0.939, 0), ["Size"] = UDim2.new(0.119, 0, 0.011, 0)});
        New("UICorner", {["Parent"] = VolumeSliderHolder, ["CornerRadius"] = UDim.new(1, 0)});
        New("UIListLayout", {["Parent"] = VolumeSliderHolder, ["VerticalAlignment"] = "Center"});
        local VolumeSlider = New("Frame", {["Parent"] = VolumeSliderHolder, ["Size"] = UDim2.new(0.1, 0, 1, 0)});
        New("UICorner", {["Parent"] = VolumeSlider, ["CornerRadius"] = UDim.new(1, 0)});
        local VolumerSliderButton = New("TextButton", {["Parent"] = VolumeSlider, ["BackgroundTransparency"] = 1, ["ZIndex"] = 3, ["Text"] = "", ["Size"] = UDim2.new(1, 0, 1, 0), ["Position"] = UDim2.new(0.5, 0, 0.5, 0)});
        local Mouse = Client:GetMouse(); local Value
        local updateSlider = function()
            Tween(VolumeSlider, 0.008, "Quint", "Out", {Size = UDim2.new(0, math.clamp(Mouse["X"] - VolumeSlider["AbsolutePosition"]["X"], 0, VolumeSliderHolder["AbsoluteSize"]["X"]), 1, 0)});
            Value = math.floor((((100 - 0) / VolumeSliderHolder["AbsoluteSize"]["X"]) * VolumeSlider["AbsoluteSize"]["X"]) + 0) or 0.00
 
            moveConnection = Mouse["Move"]:Connect(function()
                Value = math.floor((((100 - 0) / VolumeSliderHolder["AbsoluteSize"]["X"]) * VolumeSlider["AbsoluteSize"]["X"]) + 0) or 0.00
                Tween(VolumeSlider, 0.008, "Quint", "Out", {Size = UDim2.new(0, math.clamp(Mouse["X"] - VolumeSlider["AbsolutePosition"]["X"], 0, VolumeSliderHolder["AbsoluteSize"]["X"]), 1, 0)});
                if not Services["UIS"]["WindowFocused"] then moveConnection:Disconnect() end;
            end);
            releaseConnection = Services["UIS"]["InputEnded"]:Connect(function(input, gameProcessedEvent)
                if input["UserInputType"] == Enum["UserInputType"]["MouseButton1"] then
                    Value = math.floor((((100 - 0) / VolumeSliderHolder["AbsoluteSize"]["X"]) * VolumeSlider["AbsoluteSize"]["X"]) + 0) or 0.00
                    Tween(VolumeSlider, 0.008, "Quint", "Out", {Size = UDim2.new(0, math.clamp(Mouse["X"] - VolumeSlider["AbsolutePosition"]["X"], 0, VolumeSliderHolder["AbsoluteSize"]["X"]), 1, 0)});
                    moveConnection:Disconnect(); releaseConnection:Disconnect(); apiRequests["setVol"](Value);
                end
            end)
        end
 
        VolumerSliderButton["MouseButton1Down"]:Connect(function()
            updateSlider()
        end);
 
        -- Top Panel
        local TopPanel = New("Frame", {["Parent"] = MainFrame, ["BackgroundColor3"] = Color3.fromRGB(5, 5, 5), ["Position"] = UDim2.new(0.578, 0, 0.07, 0), ["Size"] = UDim2.new(0.844, 0, 0.14, 0)});
        local AvatarFrame = New("Frame", {["Parent"] = TopPanel, ["BackgroundColor3"] = Color3.fromRGB(10, 10, 10), ["Position"] = UDim2.new(0.875, 0, 0.5, 0), ["Size"] = UDim2.new(0.22, 0, 0.448, 0)});
        New("UICorner", {["Parent"] = AvatarFrame, ["CornerRadius"] = UDim.new(1, 0)});
        local Minimize = New("ImageButton", {["Parent"] = AvatarFrame, ["BackgroundTransparency"] = 1, ["AutoButtonColor"] = false, ["Position"] = UDim2.new(0.856, 0, 0.5, 0), ["Size"] = UDim2.new(0, 24, 0, 24),
        ["Image"] = "rbxassetid://3926307971", ["ImageRectOffset"] = Vector2.new(324, 524), ["ImageRectSize"] = Vector2.new(36, 36)});
        local AvatarImage = apiRequests["getProfile"]()["Avatar"];
        if AvatarImage ~= nil then AvatarImage = SetIcon(apiRequests["getProfile"]()["Avatar"], "SpotifyProfile") else 
            AvatarImage = Services["P"]:GetUserThumbnailAsync(Client["UserId"], "HeadShot", Enum.ThumbnailSize.Size48x48) end
        local Avatar = New("ImageLabel", {["Parent"] = AvatarFrame, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.091, 0, 0.472, 0), ["Size"] = UDim2.new(0.24, 0, 1, 0),
        ["Image"] = AvatarImage});
        New("UICorner", {["Parent"] = Avatar, ["CornerRadius"] = UDim.new(1, 0)});
        local Username = New("TextLabel", {["Parent"] = AvatarFrame, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.541, 0, 0.5, 0), ["Size"] = UDim2.new(0.6, 0, 0.66, 0),
        ["Font"] = "GothamMedium", ["TextColor3"] = Color3.new(1, 1, 1), ["TextSize"] = 11, ["TextScaled"] = true, ["Text"] = apiRequests["getProfile"]()["Display"]});
        New("UITextSizeConstraint", {["Parent"] = Username, ["MaxTextSize"] = 11});
 
        -- Side Panel
        local SidePanel = New("Frame", {["Parent"] = MainFrame, ["BackgroundColor3"] = Color3.fromRGB(5, 5, 5), ["Position"] = UDim2.new(0.08, 0, 0.4, 0),
        ["Size"] = UDim2.new(0.158, 0, 0.8, 0), ["ZIndex"] = 2});
        local SidePanelContainer = New("Frame", {["Parent"] = SidePanel, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.5, 0, 0.328, 0),
        ["Size"] = UDim2.new(0.9, 0, 0.313, 0), ["ZIndex"] = 3})
        New("UIListLayout", {["Parent"] = SidePanelContainer, ["FillDirection"] = "Vertical", ["HorizontalAlignment"] = "Left",
        ["SortOrder"] = "LayoutOrder", ["VerticalAlignment"] = "Top"});
        New("ImageLabel", {["Parent"] = SidePanel, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.491, 0, 0.087, 0), ["Size"] = UDim2.new(0.43, 0, 0.12, 0), ["ZIndex"] = 3,
        ["Image"] = SetIcon("https://projectpulso.org/wp-content/uploads/2020/09/spotify-download-logo-30-2.png", "SpotifyWatermark")})
 
        -- Page Holder
        local PageHolder = New("Frame", {["Parent"] = MainFrame, ["BackgroundColor3"] = Color3.fromRGB(10, 10, 10), ["Position"] = UDim2.new(0.579, 0, 0.469, 0), ["Size"] = UDim2.new(0.842, 0, 0.66, 0)});
        local PageHolderList = New("UIPageLayout", {["Parent"] = PageHolder, ["EasingStyle"] = "Cubic", ["TweenTime"] = 0.25, ["ScrollWheelInputEnabled"] = false, ["Circular"] = true, ["FillDirection"] = "Horizontal",
        ["VerticalAlignment"] = "Center", ["SortOrder"] = "LayoutOrder"});
        local HomePage = New("Frame", {["Name"] = "Home", ["Parent"] = PageHolder, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.045, 0, 0.112, 0), ["Size"] = UDim2.new(1, 0, 1, 0), ["LayoutOrder"] = 0});
        local HomePageMessage = New("TextLabel", {["Parent"] = HomePage, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.13, 0, 0.061, 0), ["Size"] = UDim2.new(0.339, 0, 0.125, 0),
        ["Font"] = "GothamBlack", ["Text"] = "Welcome back", ["TextColor3"] = Color3.new(1, 1, 1), ["TextScaled"] = true, ["TextSize"] = 18});
        New('UITextSizeConstraint', {["Parent"] = HomePageMessage, ["MaxTextSize"] = 18});
        local HomePageMainContainer = New("ScrollingFrame", {["Parent"] = HomePage, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.5, 0, 0.549, 0), ["Size"] = UDim2.new(0.96, 0, 0.852, 0),
        ["CanvasSize"] = UDim2.new(0, 0, 2.2, 0), ["ScrollBarThickness"] = 0});
        New("UIListLayout", {["Parent"] = HomePageMainContainer, ["Padding"] = UDim.new(0, 30), ["HorizontalAlignment"] = "Center"});
        local RecentPlaylists = New("ScrollingFrame", {["Parent"] = HomePageMainContainer, ["BackgroundColor3"] = Color3.fromRGB(12, 12, 12), ["Size"] = UDim2.new(0.98, 0, 0.18, 0), ["ScrollBarThickness"] = 0});
        local RecentPlaylistsLayout = New("UIGridLayout", {["Parent"] = RecentPlaylists, ["CellPadding"] = UDim2.new(0, 45, 0, 15), ["CellSize"] = UDim2.new(0, 250, 0, 50), ["HorizontalAlignment"] = "Center"});
        New("UIPadding", {["Parent"] = RecentPlaylists, ["PaddingBottom"] = UDim.new(0, 5), ["PaddingLeft"] = UDim.new(0, 5), ["PaddingRight"] = UDim.new(0, 5), ["PaddingTop"] = UDim.new(0, 5)});
        local SuggestedPlaylists = New("Frame", {["BackgroundColor3"] = Color3.fromRGB(12, 12, 12), ["Size"] = UDim2.new(0.98, 0, 0.8, 0)});
        New("UIGridLayout", {["Parent"] = SuggestedPlaylists, ["CellPadding"] = UDim2.new(0, 10, 0, 15), ["CellSize"] = UDim2.new(0, 175, 0, 200), ["HorizontalAlignment"] = "Center"});
        New("UIPadding", {["Parent"] = SuggestedPlaylists, ["PaddingBottom"] = UDim.new(0, 5), ["PaddingLeft"] = UDim.new(0, 5), ["PaddingRight"] = UDim.new(0, 5), ["PaddingTop"] = UDim.new(0, 5)});
 
        RecentPlaylists["ChildAdded"]:Connect(function()
            UpdatePageSize(RecentPlaylistsLayout, RecentPlaylists);
        end)
 
        RecentPlaylists["ChildRemoved"]:Connect(function()
            UpdatePageSize(RecentPlaylistsLayout, RecentPlaylists);
        end);
 
        -- Search
        local SearchPage = New("Frame", {["Name"] = "Search", ["Parent"] = PageHolder, ["BackgroundTransparency"] = 1, ["LayoutOrder"] = 1, ["Size"] = UDim2.new(1, 0, 1, 0)});
        local TopResultHolder = New("Frame", {["Name"] = "TopResultHolder", ["Parent"] = SearchPage, ["BackgroundColor3"] = Color3.fromRGB(13, 13, 13), ["Position"] = UDim2.new(0.226, 0, 0.582, 0), ["Size"] = UDim2.new(0.422, 0, 0.591, 0)});
        New("UICorner", {["Parent"] = TopResultHolder, ["CornerRadius"] = UDim.new(0, 5)});
        local PlayButtonHolder = New("Frame", {["Parent"] = TopResultHolder, ["BackgroundTransparency"] = 1, ["BackgroundColor3"] = Color3.fromRGB(29, 185, 84), ["Position"] = UDim2.new(0.875, 0, 0.85, 0), ["Size"] = UDim2.new(0, 40, 0, 40)});
        New("UICorner", {["Parent"] = PlayButtonHolder, ["CornerRadius"] = UDim.new(1, 0)});
        local PlayButton = New("ImageButton", {["Parent"] = PlayButtonHolder, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.5, 0, 0.5, 0), ["Size"] = UDim2.new(0, 30, 0, 30), ["ZIndex"] = 3, 
        ["Image"] = "rbxassetid://3926307971", ["ImageColor3"] = Color3.new(0, 0, 0), ["ImageRectOffset"] = Vector2.new(764, 244), ["ImageRectSize"] = Vector2.new(36, 36), ["ImageTransparency"] = 1});
        local TopResultSongIcon = New("ImageLabel", {["Parent"] = TopResultHolder, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.22, 0, 0.34, 0), ["Size"] = UDim2.new(0, 75, 0, 75), ["Image"] = "", ["ImageTransparency"] = 0});
        local TopResultSongName = New("TextLabel", {["Parent"] = TopResultHolder, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.47, 0, 0.692, 0), ["Size"] = UDim2.new(0.802, 0, 0.135, 0),
        ["Font"] = "GothamBlack", ["Text"] = "", ["TextTransparency"] = 0, ["TextColor3"] = Color3.new(1, 1, 1), ["TextScaled"] = true, ["TextXAlignment"] = "Left"});
        New("UITextSizeConstraint", {["Parent"] = TopResultSongName, ["MaxTextSize"] = 20});
        local TopResultSongArtist = New("TextLabel", {["Parent"] = TopResultHolder, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.309, 0, 0.811, 0), ["Size"] = UDim2.new(0.48, 0, 0.103, 0),
        ["Font"] = "Gotham", ["Text"] = "", ["TextTransparency"] = 0, ["TextColor3"] = Color3.fromRGB(145, 145, 145), ["TextScaled"] = true, ["TextXAlignment"] = "Left", ["TextYAlignment"] = "Bottom"});
        New("UITextSizeConstraint", {["Parent"] = TopResultSongArtist, ["MaxTextSize"] = 13});
        local TopResultHoverButton = New("TextButton", {["Parent"] = TopResultHolder, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.5, 0, 0.5, 0), ["Size"] =  UDim2.new(1, 0, 1, 0), ["Text"] = ""})
        local TopResultText = New("TextLabel", {["Parent"] = SearchPage, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.135, 0, 0.203, 0), ["Size"] = UDim2.new(0.224, 0, 0.114, 0), ["Font"] = "GothamBold",
        ["Text"] = "Top result", ["TextColor3"] = Color3.new(1, 1, 1), ["TextSize"] = 18, ["TextScaled"] = true, ["TextXAlignment"] = "Left", ["TextYAlignment"] = "Bottom"});
        New("UITextSizeConstraint", {["Parent"] = TopResultText, ["MaxTextSize"] = 18});
        
        local SearchBoxHolder = New("Frame", {["Parent"] = SearchPage, ["Name"] = "SearchBoxHolder", ["Position"] = UDim2.new(0.205, 0, 0.08, 0), ["Size"] = UDim2.new(0.38, 0, 0.1, 0)});
        New("UICorner", {["Parent"] = SearchBoxHolder, ["CornerRadius"] = UDim.new(1, 0)});
        New("ImageLabel", {["Parent"] = SearchBoxHolder, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.07, 0, 0.5, 0), ["Size"] = UDim2.new(0, 20, 0, 20), ["Image"] = "rbxassetid://3926305904",
        ["ImageColor3"] = Color3.new(0, 0, 0), ["ImageRectOffset"] = Vector2.new(964, 324), ["ImageRectSize"] = Vector2.new(36, 36)});
        local SearchBox = New("TextBox", {["Parent"] = SearchBoxHolder, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.564, 0, 0.5, 0), ["Size"] = UDim2.new(0.871, 0, 1, 0),
        ["Font"] = "Gotham", ["PlaceholderColor3"] = Color3.fromRGB(130, 130, 130), ["PlaceholderText"] = "Search for a song..", ["TextScaled"] = true, ["Text"] = "", ["TextXAlignment"] = "Left"});
        New("UITextSizeConstraint", {["Parent"] = SearchBox, ["MaxTextSize"] = 13}); New("UICorner", {["Parent"] = SearchBox, ["CornerRadius"] = UDim.new(1, 0)});
        New("ImageLabel", {['Parent'] = SearchBoxHolder, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.07, 0, 0.5, 0), ["Size"] = UDim2.new(0, 20, 0, 20), ["Image"] = "rbxassetid://3926305904", 
        ["ImageColor3"] = Color3.new(0, 0, 0), ["ImageRectOffset"] = Vector2.new(964, 324), ["ImageRectSize"] = Vector2.new(36, 36)});
 
        local RelatedResultsHolder = New("Frame", {['Parent'] = SearchPage, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.71, 0, 0.582, 0), ["Size"] = UDim2.new(0.431, 0, 0.591, 0)});
        New("UIListLayout", {["Parent"] = RelatedResultsHolder, ["Padding"] = UDim.new(0, 15)});
        New("UIPadding", {["Parent"] = RelatedResultsHolder, ["PaddingBottom"] = UDim.new(0, 5), ["PaddingTop"] = UDim.new(0, 5)});
 
        local function createRelatedResult(Name, Artist, Url, Length)
            local Frame = New("Frame", {["Name"] = Name, ["Parent"] = RelatedResultsHolder, ["BackgroundColor3"] = Color3.fromRGB(10, 10, 10), ["Size"] = UDim2.new(0.95, 0, 0.25, 0)});
            New("UICorner", {["Parent"] = Frame, ["CornerRadius"] = UDim.new(0, 5)});
            local SongIcon = New("ImageLabel", {["Parent"] = Frame, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.1, 0, 0.5, 0), ["Size"] = UDim2.new(0, 30, 0, 30), ["Image"] = SetIcon(Url, Name)});
            local SongLength = New("TextLabel", {["Parent"] = Frame, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.918, 0, 0.5, 0), ["Size"] = UDim2.new(0.16, 0, 0.454, 0), ["Font"] = "Gotham",
            ["Text"] = Length, ["TextColor3"] = Color3.fromRGB(170, 170, 170), ["TextSize"] = 13, ["TextScaled"] = true, ["TextXAlignment"] = "Left"});
            New("UITextSizeConstraint", {["Parent"] = SongLength, ["MaxTextSize"] = 13});
            local SongArtist = New("TextLabel", {["Parent"] = Frame, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.462, 0, 0.709, 0), ["Size"] = UDim2.new(0.53, 0, 0.287, 0), ["Font"] = "Gotham",
            ["Text"] = Artist, ["TextColor3"] = Color3.fromRGB(170, 170, 170), ["TextSize"] = 11, ["TextScaled"] = true, ["TextXAlignment"] = "Left"});
            New("UITextSizeConstraint", {["Parent"] = SongArtist, ["MaxTextSize"] = 11});
            local SongName = New("TextLabel", {["Parent"] = Frame, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.462, 0, 0.35, 0), ["Size"] = UDim2.new(0.53, 0, 0.287, 0), ["Font"] = "GothamBold",
            ["Text"] = Name, ["TextColor3"] = Color3.fromRGB(255, 255, 255), ["TextSize"] = 14, ["TextScaled"] = true, ["TextXAlignment"] = "Left"});
            New("UITextSizeConstraint", {["Parent"] = SongName, ["MaxTextSize"] = 14});
            local Button = New("TextButton", {["Parent"] = Frame, ["BackgroundTransparency"] = 1, ["Size"] = UDim2.new(1, 0, 1, 0), ["Position"] = UDim2.new(0.5, 0, 0.5, 0), ["Text"] = "", ["AutoButtonColor"] = false});
        end;
        local RelatedSongText = New("TextLabel", {["Parent"] = SearchPage, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.606, 0, 0.203, 0), ["Size"] = UDim2.new(0.225, 0, 0.114, 0),
        ["Font"] = "GothamBold", ["Text"] = "Songs", ["TextColor3"] = Color3.new(1, 1, 1), ["TextSize"] = 18, ["TextXAlignment"] = "Left"});
        New("UITextSizeConstraint", {["Parent"] = RelatedSongText, ["MaxTextSize"] = 18});
 
        -- Library
        local LibraryPage = New("Frame", {["Name"] = "Library", ["Parent"] = PageHolder, ["BackgroundTransparency"] = 1, ["LayoutOrder"] = 2, ["Size"] = UDim2.new(1, 0, 1, 0)})
        local LibraryPageContainer = New("ScrollingFrame", {["Parent"] = LibraryPage, ["BackgroundColor3"] = Color3.fromRGB(12, 12, 12), ["Position"] = UDim2.new(0.5, 0, 0.63, 0),
        ["Size"] = UDim2.new(0.967, 0, 0.676, 0), ["CanvasSize"] = UDim2.new(0, 0, 0, 15), ["ScrollBarThickness"] = 1, ["ScrollBarImageColor3"] = Color3.new(1, 1, 1)});
        local LibraryContainerList = New("UIListLayout", {["Parent"] = LibraryPageContainer, ["Padding"] = UDim.new(0, 5), ["VerticalAlignment"] = "Center", ["SortOrder"] = "LayoutOrder"});
        New("UIPadding", {["Parent"] = LibraryPageContainer, ["PaddingLeft"] = UDim.new(0, 3), ["PaddingTop"] = UDim.new(0, 0)});
 
        LibraryPageContainer["ChildAdded"]:Connect(function()
            UpdatePageSize(LibraryContainerList, LibraryPageContainer);
        end)
 
        LibraryPageContainer["ChildRemoved"]:Connect(function()
            UpdatePageSize(LibraryContainerList, LibraryPageContainer);
        end);
 
        local TipsHolder = New("Frame", {['Parent'] = LibraryPage, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.5, 0, 0.237, 0), ["Size"] = UDim2.new(0.937, 0, 0.095, 0)});
        New("ImageLabel", {["Parent"] = TipsHolder, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.96, 0, 0.5, 0), ["Size"] = UDim2.new(0, 15, 0, 15),
        ["Image"] = "rbxassetid://3926305904", ["ImageRectOffset"] = Vector2.new(704, 4), ["ImageRectSize"] = Vector2.new(36, 36)});
        local TipsPosition = New("TextLabel", {["Parent"] = TipsHolder, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.055, 0, 0.5, 0), ["Size"] = UDim2.new(0.076, 0, 0.977, 0), 
        ["Text"] = "#", ["TextColor3"] = Color3.fromRGB(212, 212, 212), ["TextSize"] = 10, ["TextScaled"] = true, ["TextXAlignment"] = "Left"});
        local TipsPositionSize = New("UITextSizeConstraint", {["Parent"] = TipsPosition, ["MaxTextSize"] = 10});
        local TipsTitle = New("TextLabel", {["Parent"] = TipsHolder, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.3, 0, 0.5, 0), ["Size"] = UDim2.new(0.281, 0, 0.977, 0), 
        ["Text"] = "Title", ["TextColor3"] = Color3.fromRGB(212, 212, 212), ["TextSize"] = 10, ["TextScaled"] = true, ["TextXAlignment"] = "Left"});
        local TipsTitleSize = New("UITextSizeConstraint", {["Parent"] = TipsTitle, ["MaxTextSize"] = 8});
        local TipsAlbum = New("TextLabel", {["Parent"] = TipsHolder, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.62, 0, 0.5, 0), ["Size"] = UDim2.new(0.259, 0, 0.977, 0), 
        ["Text"] = "Album", ["TextColor3"] = Color3.fromRGB(212, 212, 212), ["TextSize"] = 10, ["TextScaled"] = true, ["TextXAlignment"] = "Left"});
        local TipsAlbumSize = New("UITextSizeConstraint", {["Parent"] = TipsAlbum, ["MaxTextSize"] = 8});
 
        local LibraryPageTitle = New("TextLabel", {["Parent"] = LibraryPage, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.142, 0, 0.073, 0), ["Size"] = UDim2.new(0.25, 0, 0.15, 0),
        ["Font"] = "GothamBold", ["Text"] = "My Library", ["TextColor3"] = Color3.new(1, 1, 1), ["TextSize"] = 14, ["TextScaled"] = true, ["TextXAlignment"] = "Left"})
 
        local function createSongList(Name, Index, Artist, Album, TimeLength, IconUrl)
            local Frame = New("Frame", {["Name"] = Name, ["Parent"] = LibraryPageContainer, ["BackgroundColor3"] = Color3.fromRGB(15, 15, 15), ["Size"] = UDim2.new(0.99, 0, 0.2, 0), ["LayoutOrder"] = Index});
            local Corner = New("UICorner", {["Parent"] = Frame, ["CornerRadius"] = UDim.new(0, 8)});
            local Icon = New("ImageLabel", {["Parent"] = Frame, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.103, 0, 0.5, 0), ["Size"] = UDim2.new(0, 31, 0, 31),
            ["Image"] = SetIcon(IconUrl, Name)});
            local SongName = New("TextLabel", {["Parent"] = Frame, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.251, 0, 0.303, 0), ["Size"] = UDim2.new(0.207, 0, 0.382, 0), 
            ["Font"] = "GothamMedium", ["TextColor3"] = Color3.new(1, 1, 1), ["TextScaled"] = true, ["TextSize"] = 10, ["TextXAlignment"] = "Left", ["Text"] = Name});
            local SongNameSize = New("UITextSizeConstraint", {["Parent"] = SongName, ["MaxTextSize"] = 10});
 
            local SongIndex = New("TextLabel", {["Name"] = "Index", ["Parent"] = Frame, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.04, 0, 0.5, 0), ["Size"] = UDim2.new(0, 30, 0, 30), 
            ["TextColor3"] = Color3.fromRGB(170, 170, 170), ["TextSize"] = 10, ["TextScaled"] = true, ["Text"] = Index});
            local SongIndexSize = New("UITextSizeConstraint", {["Parent"] = SongIndex, ["MaxTextSize"] = 7});
 
            local SongPlayImage = New("ImageLabel", {["Name"] = "PlayIcon", ["Parent"] = Frame, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.04, 0, 0.5, 0), ["Size"] = UDim2.new(0, 20, 0, 20),
            ["ImageRectOffset"] = Vector2.new(764, 244), ["Image"] = "rbxassetid://3926307971", ["ImageRectSize"] = Vector2.new(36, 36), ["ImageTransparency"] = 1, ["ImageColor3"] = Color3.fromRGB(170, 170, 170)})
 
            local SongArtist = New("TextLabel", {["Parent"] = Frame, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.224, 0, 0.685, 0), ["Size"] = UDim2.new(0.153, 0, 0.382, 0),
            ["Font"] = "Gotham", ["TextColor3"] = Color3.fromRGB(170, 170, 170), ["TextSize"] = 10, ["TextScaled"] = true, ["Text"] = Artist, ["TextXAlignment"] = "Left"});
            local SongArtistSize = New("UITextSizeConstraint", {["Parent"] = SongArtist, ["MaxTextSize"] = 10});
 
            local SongAlbum = New("TextLabel", {["Parent"] = Frame, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.515, 0, 0.5, 0), ["Size"] = UDim2.new(0.219, 0, 0.56, 0),
            ["Font"] = "Gotham", ["TextColor3"] = Color3.fromRGB(170, 170, 170), ["TextSize"] = 12, ["TextScaled"] = true, ["Text"] = Album});
            local SongAlbumSize = New("UITextSizeConstraint", {["Parent"] = SongAlbum, ["MaxTextSize"] = 12});
 
            local SongLength = New("TextLabel", {["Parent"] = Frame, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.892, 0, 0.5, 0), ["Size"] = UDim2.new(0.153, 0, 0.382, 0),
            ["Font"] = "Gotham", ["TextColor3"] = Color3.fromRGB(170, 170, 170), ["TextSize"] = 10, ["TextScaled"] = true, ["Text"] = TimeLength, ["TextXAlignment"] = "Right"});
            local SongLengthSize = New("UITextSizeConstraint", {["Parent"] = SongLength, ["MaxTextSize"] = 10});
 
            local HoverButton = New("TextButton", {["Parent"] = Frame, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.5, 0, 0.5, 0), ["Size"] = UDim2.new(1, 0, 1, 0), ["Text"] = ""})
            local Ratio = New("UISizeConstraint", {["Parent"] = Frame, ["MaxSize"] = Vector2.new(600, 40)});
        end
 
        -- Detailings
        local SongThumbnail = New("ImageLabel", {["Parent"] = MainFrame, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.048, 0, 0.907, 0), ["Size"] = UDim2.new(0.065, 0, 0.09, 0),
        ["Image"] = SetIcon(CurrentData["URL"], CurrentData["Song"])});
        local SongName = New("TextLabel", {["Parent"] = MainFrame, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.191, 0, 0.893, 0), ["Size"] = UDim2.new(0.188, 0, 0.032, 0),
        ["Font"] = "GothamMedium", ["TextColor3"] = Color3.new(1, 1, 1), ["TextScaled"] = true, ["TextXAlignment"] = "Left", ["Text"] = CurrentData["Song"]});
        local SongNameSize = New("UITextSizeConstraint", {["Parent"] = SongName, ["MaxTextSize"] = 14});
        local SongArtist = New("TextLabel", {["Parent"] = MainFrame, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.191, 0, 0.924, 0), ["Size"] = UDim2.new(0.188, 0, 0.032, 0),
        ["Font"] = "Gotham", ["TextColor3"] = Color3.fromRGB(206, 206, 206), ["TextSize"] = 11, ["TextScaled"] = true, ["TextXAlignment"] = "Left", ["Text"] = CurrentData["Artist"]});
        local SongArtistSize = New("UITextSizeConstraint", {["Parent"] = SongArtist, ["MaxTextSize"] = 11});
        New("ImageLabel", {["Parent"] = MainFrame, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.825, 0, 0.937, 0), ["Size"] = UDim2.new(0, 17, 0, 17), 
        ["Image"] = "rbxassetid://3926307971", ["ImageColor3"] = Color3.fromRGB(170, 170, 170), ["ImageRectOffset"] = Vector2.new(684, 324), ["ImageRectSize"] = Vector2.new(36, 36)});
 
        -- UI Functions
        local createRecentPlaylist = function(Name, Url)
            local Frame = New("Frame", {["Name"] = Name, ["Parent"] = RecentPlaylists, ["BackgroundColor3"] = Color3.fromRGB(15, 15, 15)});
            New("UICorner", {["Parent"] = Frame, ["CornerRadius"] = UDim.new(0, 5)});
            local PlayButton = New("ImageButton", {["Parent"] = Frame, ["BackgroundColor3"] = Color3.fromRGB(29, 185, 84), ["Position"] = UDim2.new(0.905, 0, 0.5, 0), ["Size"] = UDim2.new(0, 20, 0, 20),
            ["Image"] = "rbxassetid://3926307971", ["ImageColor3"] = Color3.new(0, 0, 0), ["ImageRectOffset"] = Vector2.new(764, 244), ["ImageRectSize"] = Vector2.new(36, 36)});
            New("UICorner", {["Parent"] = PlayButton, ["CornerRadius"] = UDim.new(1, 0)});
            New("ImageLabel", {["Parent"] = Frame, ["BackgroundTransparency"] = 1, ["Size"] = UDim2.new(0.152, 0, 0.76, 0), ["Position"] = UDim2.new(0.125, 0, 0.5, 0),
            ["Image"] = SetIcon(Url, Name)});
            local Txt = New("TextLabel", {["Parent"] = Frame, ["BackgroundTransparency"] = 1, ["Size"] = UDim2.new(0.5, 0, 0.351, 0), ["Position"] = UDim2.new(0.5, 0, 0.5, 0),
            ["Text"] = Name, ["Font"] = "GothamMedium", ["TextScaled"] = true, ["TextColor3"] = Color3.new(1, 1, 1), ["TextSize"] = 15})
            New("UITextSizeConstraint", {["Parent"] = Txt, ["MaxTextSize"] = 15});
        end
 
        -- System Functions
        local LikedSongsPool = {};
 
        local function updateLikedPool()
            table.clear(LikedSongsPool);
            for i,v in next, apiRequests["getLikedSongs"](0) do
                table.insert(LikedSongsPool, v);
            end;
            for i,v in next, apiRequests["getLikedSongs"](51) do
                table.insert(LikedSongsPool, v);
            end; 
        end; 
 
        local function createLiked()
            for i,v in next, LikedSongsPool do
                local Artists = "";
                for a = 1, #v["track"]["artists"] do
                    if a ~= #v['track']['artists'] then
                        Artists = Artists .. v['track']['artists'][a]["name"] .. ", "
                    else
                        Artists = Artists .. v['track']['artists'][a]["name"]
                    end
                end
                    local Name = v['track']["name"]
                    local TimeLength = string.format("%2.f:%002.f", (v['track']["duration_ms"] / 1000) / 60, (v['track']["duration_ms"] / 1000) * 0.1);
                    local Album = v['track']["album"]["name"];
                    local Url
                    if #v["track"]["album"]["images"] >= 1 then
                        Url = v['track']['album']['images'][1]["url"] 
                    end
                table.insert(SongNameToID, {N = Name, ID = v["track"]["uri"]})
                createSongList(Name, i, Artists, Album, TimeLength, Url);
            end 
        end;
 
        local function refreshLiked()
            updateLikedPool();
            for i,v in next, LibraryPageContainer:GetChildren() do
                if v:IsA("Frame") then v:Destroy() end;
            end; createLiked()
        end
 
        local checkSong = function()
            pcall(function()
                if apiRequests["nowplaying"](true)["Song"] ~= CurrentData["Song"] then
                    apiRequests["nowplaying"](false); SongThumbnail["Image"] = SetIcon(CurrentData["URL"], CurrentData["Song"])
                    SongName["Text"] = CurrentData["Song"]; SongArtist["Text"] = CurrentData["Artist"]
                end
            end)
        end;
 
        local resetTimebar = function()
            Timebar = false; Bar["Size"] = UDim2.new(0, 0, 1, 0);
            coroutine.wrap(function()
                Timebar = true
                repeat
                    pcall(function()
                        local Info = apiRequests["timePos"]();
                        Bar:TweenSize(UDim2.new(math.clamp(Info["Current"] / Info["Length"], 0, 1), 0, 1, 0), "Out", "Quint", 0.00001)		
                        wait(0);
                    end)
                until not Timebar
            end)()
        end
 
        PausePlayButton["MouseButton1Click"]:Connect(function()
            if not IsPaused then
                IsPaused = true; apiRequests["pause"](); PausePlayButton["ImageRectOffset"] = Vector2.new(764, 244)
            else
                IsPaused = false; apiRequests["resume"](); PausePlayButton["ImageRectOffset"] = Vector2.new(804, 124)
            end
        end)
 
        Skip["MouseButton1Click"]:Connect(function()
            apiRequests["skip"]();
        end)
 
        Previous['MouseButton1Click']:Connect(function()
            apiRequests["previous"](); 
        end)
 
        Shuffle["MouseButton1Click"]:Connect(function()
            if not IsShuffle then apiRequests["toggleShuffle"](true); IsShuffle = true; Tween(Shuffle, 0.5, "Quint", "Out", {ImageColor3 = Color3.fromRGB(29, 185, 84)});
            else apiRequests["toggleShuffle"](false); IsShuffle = false Tween(Shuffle, 0.5, "Quint", "Out", {ImageColor3 = Color3.fromRGB(170, 170, 170)}); end;
        end)
 
        Repeat["MouseButton1Click"]:Connect(function()
            if not IsRepeat then 
                apiRequests["toggleRepeat"](true); IsRepeat = true;
                Tween(Repeat, 0.5, "Quint", "Out", {ImageColor3 = Color3.fromRGB(29, 185, 84)});
            else apiRequests["toggleRepeat"](false); IsRepeat = false 
                Tween(Repeat, 0.5, "Quint", "Out", {ImageColor3 = Color3.fromRGB(170, 170, 170)});
            end;
        end)
 
        Minimize["MouseButton1Click"]:Connect(function()
            if not Minimized then
                Minimized = true; Tween(MainFrame, 1, "Quint", "Out", {Position = UDim2.new(0.5, 0, 1.36, 0)});
                Minimize["ImageRectOffset"] = Vector2.new(164, 484);
            else
                Minimized = false; Tween(MainFrame, 1, "Quint", "Out", {Position = UDim2.new(0.5, 0, 0.5, 0)});
                Minimize["ImageRectOffset"] = Vector2.new(324, 524);
            end
        end)
 
        -- UI System Functions / Callbacks
        TopResultHoverButton["MouseEnter"]:Connect(function()
            if TopResultSongIcon["Image"] ~= nil or TopResultSongIcon["Image"] ~= "" then
                Tween(PlayButtonHolder, 0.5, "Quint", "Out", {BackgroundTransparency = 0}); Tween(PlayButton, 0.5, "Quint", "Out", {ImageTransparency = 0});
            end
        end)
        TopResultHoverButton["MouseLeave"]:Connect(function()
            if TopResultSongIcon["Image"] ~= nil or TopResultSongIcon["Image"] ~= "" then
                Tween(PlayButtonHolder, 0.5, "Quint", "Out", {BackgroundTransparency = 1}); Tween(PlayButton, 0.5, "Quint", "Out", {ImageTransparency = 1});
            end
        end)
 
        local SearchSongUri = nil;
        SearchBox["FocusLost"]:Connect(function(enter)
            if SearchBox["Text"] ~= "" then
                for i,v in next, RelatedResultsHolder:GetChildren() do if v:IsA("Frame") then v:Destroy() end end
                local PotentialSong = apiRequests["search"](SearchBox["Text"]);
                TopResultSongName["Text"] = PotentialSong[1]["name"]; TopResultSongArtist["Text"] = PotentialSong[1]["artists"][1]["name"];
                TopResultSongIcon["Image"] = SetIcon(PotentialSong[1]['album']["images"][1]["url"], PotentialSong[1]["name"])
                SearchSongUri = PotentialSong[1]["uri"]
                for i = 2, #PotentialSong do
                    if i == 5 then break end
                    local TimeLength = string.format("%2.f:%002.f", (PotentialSong[i]["duration_ms"] / 1000) / 60, (PotentialSong[i]["duration_ms"] / 1000) * 0.1);
                    createRelatedResult(PotentialSong[i]["name"], PotentialSong[i]["artists"][1]["name"], PotentialSong[i]["album"]["images"][1]["url"], TimeLength);
                    table.insert(SongNameToID, {N = PotentialSong[i]["name"], ID = PotentialSong[i]["uri"]})
                end
            end
        end)
 
        PlayButton["MouseButton1Click"]:Connect(function()
            if SearchSongUri ~= nil then
                apiRequests["queueSong"](SearchSongUri); apiRequests["skip"]()
            end
        end)
 
        for i,v in next, apiRequests["playlists"]() do
            if #v["images"] >= 1 then
                createRecentPlaylist(v["name"], v["images"][3]["url"]);
                table.insert(UserPlaylists, {["Name"] = v["name"], ["Uri"] = v["uri"]}); 
            end
        end
 
        for i,v in next, RecentPlaylists:GetChildren() do
            if v:IsA("Frame") then
                v:FindFirstChildOfClass("ImageButton")["MouseButton1Click"]:Connect(function()
                    for _,a in next, UserPlaylists do
                        if v["Name"] == a["Name"] then
                            local id = string.gsub(a["Uri"], "spotify:playlist:", "");
                            local tracks = apiRequests["getPlaylistTracks"](id);
                            for e,d in next, tracks['items'] do
                                apiRequests["queueSong"](d["track"]["uri"]); 
                            end; apiRequests["skip"]()
                        end
                    end;
                end)
            end
        end
 
        RelatedResultsHolder["ChildAdded"]:Connect(function(child)
            if child:IsA("Frame") then
                repeat wait() until child:FindFirstChildWhichIsA("TextButton", true)
                child:FindFirstChildWhichIsA("TextButton", true)["MouseEnter"]:Connect(function()
                    Tween(child, 0.5, "Quint", "Out", {BackgroundColor3 = Color3.fromRGB(15, 15, 15)})
                end)
                child:FindFirstChildWhichIsA("TextButton", true)["MouseLeave"]:Connect(function()
                    Tween(child, 0.5, "Quint", "Out", {BackgroundColor3 = Color3.fromRGB(10, 10, 10)})
                end)
                child:FindFirstChildWhichIsA("TextButton", true)["MouseButton1Click"]:Connect(function()
                    for _,a in next, SongNameToID do
                        if tostring(child) == a["N"] then
                            apiRequests["queueSong"](a["ID"]); wait(0.1);
                            apiRequests["skip"]();
                        end
                    end
                end)
            end
        end)
 
        for i,v in next, LibraryPageContainer:GetChildren() do
            if v:IsA("Frame") and v:FindFirstChildWhichIsA("TextButton", true) then
                v:FindFirstChildWhichIsA("TextButton", true)["MouseEnter"]:Connect(function(x, y)
                    v:FindFirstChild("PlayIcon")["ImageTransparency"] = 0; v:FindFirstChild("Index", true)["TextTransparency"] = 1
                    v["BackgroundColor3"] = Color3.fromRGB(20, 20, 20)
                end)
                v:FindFirstChildWhichIsA("TextButton", true)["MouseLeave"]:Connect(function(x, y)
                    v:FindFirstChild("PlayIcon")["ImageTransparency"] = 1; v:FindFirstChild("Index", true)["TextTransparency"] = 0
                    v["BackgroundColor3"] = Color3.fromRGB(15, 15, 15)
                end)
                v:FindFirstChildWhichIsA("TextButton", true)["MouseButton1Click"]:Connect(function()
                    for _,a in next, SongNameToID do
                        if tostring(v) == a["N"] then
                            apiRequests["queueSong"](a["ID"]); wait(0.1);
                            apiRequests["skip"]();
                        end
                    end
                end)
            end
        end
 
        LibraryPageContainer["ChildAdded"]:Connect(function(child)
            if child:IsA("Frame") then
                repeat wait() until child:FindFirstChildOfClass("TextButton");
                child:FindFirstChildWhichIsA("TextButton", true)["MouseEnter"]:Connect(function(x, y)
                    child:FindFirstChild("PlayIcon")["ImageTransparency"] = 0; child:FindFirstChild("Index", true)["TextTransparency"] = 1
                    child["BackgroundColor3"] = Color3.fromRGB(20, 20, 20)
                end)
                child:FindFirstChildWhichIsA("TextButton", true)["MouseLeave"]:Connect(function(x, y)
                    child:FindFirstChild("PlayIcon")["ImageTransparency"] = 1; child:FindFirstChild("Index", true)["TextTransparency"] = 0
                    child["BackgroundColor3"] = Color3.fromRGB(15, 15, 15)
                end)
                child:FindFirstChildWhichIsA("TextButton", true)["MouseButton1Click"]:Connect(function()
                    for _,a in next, SongNameToID do
                        if tostring(child) == a["N"] then
                            apiRequests["queueSong"](a["ID"]); wait(0.1);
                            apiRequests["skip"](); SongThumbnail["Image"] = SetIcon(CurrentData["URL"], CurrentData["Song"])
                        end
                    end
                end)
            end
        end)
 
        -- Post-UI Functions
        local newTab = function(Name, Order)
            local NameToImage = { ["home"] = Vector2.new(964, 204), ["search"] = Vector2.new(964, 324), ["library"] = Vector2.new(764, 484) }
 
            local TabSelection = New("Frame", {["Parent"] = SidePanelContainer, ["Name"] = Name, ["BackgroundTransparency"] = 1, ["Size"] = UDim2.new(1, 0, 0.26, 0), ["ZIndex"] = 4, ["LayoutOrder"] = Order or 0});
            local TabButton = New("TextButton", {["Parent"] = TabSelection, ["BackgroundTransparency"] = 1, ["Size"] = UDim2.new(1, 0, 1, 0), ["Position"] = UDim2.new(0.5, 0, 0.5, 0),
            ["Text"] = "", ["ZIndex"] = 2});
            local TabIcon = New("ImageLabel", {["Parent"] = TabSelection, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.1, 0, 0.5, 0), ["Size"] = UDim2.new(0, 24, 0, 24),
            ["Image"] = "rbxassetid://3926305904", ["ImageRectOffset"] = NameToImage[Name:lower()], ["ImageRectSize"] = Vector2.new(36, 36), ["ImageColor3"] = Color3.fromRGB(177, 177, 177), ["ZIndex"] = 3})
            local TabText = New("TextLabel", {["Parent"] = TabSelection, ["BackgroundTransparency"] = 1, ["Position"] = UDim2.new(0.665, 0, 0.5, 0), ["Size"] = UDim2.new(0.76, 0, 1, 0),
            ["Font"] = "GothamMedium", ["Text"] = Name, ["TextColor3"] = Color3.fromRGB(177, 177, 177), ["TextScaled"] = true, ["ZIndex"] = 3});
            local TabTextSize = New("UITextSizeConstraint", {["Parent"] = TabText, ["MaxTextSize"] = 14});
        end; newTab("Home"); newTab("Search", 1); newTab("Library", 2);
 
        local function disableOthers(Exempt)
            for i,v in next, SidePanelContainer:GetChildren() do
                if v:IsA("Frame") then
                    if tostring(v) ~= Exempt then
                        Tween(v:FindFirstChild("TextLabel", true), 0.5, "Quint", "Out", {TextColor3 = Color3.fromRGB(177, 177, 177)});
                        Tween(v:FindFirstChild("ImageLabel", true), 0.5, "Quint", "Out", {ImageColor3 = Color3.fromRGB(177, 177, 177)});
                    end
                end
            end
        end
 
        -- Change Panels / Tab Selections
        for i,v in next, SidePanelContainer:GetChildren() do
            if v:IsA("Frame") then
                if v["Name"] == CurrentTab then
                    v:FindFirstChild("TextLabel", true)["TextColor3"] = Color3.new(1, 1, 1);
                    v:FindFirstChild("ImageLabel", true)["ImageColor3"] = Color3.new(1, 1, 1)
                end
 
                v:FindFirstChild("TextButton", true)["MouseButton1Click"]:Connect(function()
                    if tostring(v) ~= CurrentTab then
                        CurrentTab = tostring(v); disableOthers(tostring(v));
                        Tween(v:FindFirstChild("TextLabel", true), 0.5, "Quint", "Out", {TextColor3 = Color3.fromRGB(255, 255, 255)});
                        Tween(v:FindFirstChild("ImageLabel", true), 0.5, "Quint", "Out", {ImageColor3 = Color3.fromRGB(255, 255, 255)});
                        PageHolderList:JumpTo(PageHolder[tostring(v)])
                    end
                end)
            end
        end
 
        -- Finalize
        resetTimebar(); updateLikedPool(); createLiked();
        coroutine.wrap(function()
            repeat checkSong(SongThumbnail); wait(1) until not Spotify; resetTimebar()
        end)()
        coroutine.wrap(function()
            while wait(120) do
                refreshLiked()
            end
        end)(); Notify("R-Spotify has loaded\nMade by horror#7132", "normal", 3)
    end
end

