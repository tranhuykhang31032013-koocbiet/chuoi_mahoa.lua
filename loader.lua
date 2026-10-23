local typeof = typeof or type

local KEY_CONFIG = {

	CoreScriptUrl = "https://raw.githubusercontent.com/tranhuykhang31032013-koocbiet/chuoi_mahoa.lua/refs/heads/main/chuoi_mahoa.lua",

	GetKeyUrl = "https://link4m.com/your-get-key-link",

	RemoteKeyJsonUrl = "https://raw.githubusercontent.com/TEN_GITHUB_CUA_BAN/TEN_REPO/main/server_key.json",

	VerifyTag = 1779572110,
	HandshakeSlot = 8492017,
	EncryptedCoreUrl = "",

	MaxAttempts = 10,

	SaveFolder = "Banana Cat Hub",
	SaveKeyFile = "BananaCat_SavedKey.txt",

	HubTitle = "BANANA CAT HUB",
	HubSubtitle = "Aegis-V24.0 Key System • Bảo Mật Toán Học",
}

local function bxor32(a, b)
	a, b = a % 4294967296, b % 4294967296
	local r, p = 0, 1
	while a > 0 or b > 0 do
		local x, y = a % 2, b % 2
		if x ~= y then
			r = r + p
		end
		a = (a - x) / 2
		b = (b - y) / 2
		p = p * 2
	end
	return r
end

local function deriveKeyMaterial(rawKey)
	local cleanKey = string.gsub(rawKey or "", "^%s*(.-)%s*$", "%1")
	if #cleanKey == 0 then
		return nil, nil
	end
	local h1 = 2166136261
	local h2 = 0x5A3C967F
	for idx = 1, #cleanKey do
		local b = string.byte(cleanKey, idx)
		local x = bxor32(h1, b)
		local lo = x % 65536
		local hi = math.floor(x / 65536)
		h1 = ((lo * 16777619) + (((hi * 16777619) % 65536) * 65536)) % 4294967296
		local sum = (h2 + (b * 4099) + (idx * 65537)) % 4294967296
		h2 = bxor32(sum, math.floor(h1 / 256)) % 4294967296
	end
	local bridgeKey = bxor32(h1, math.floor(h2 / 256)) % 16777216
	bridgeKey = bridgeKey - (bridgeKey % 2)
	if bridgeKey == 0 then
		bridgeKey = 0x7A3C52
	end
	local l2 = h2 % 65536
	local h2Hi = math.floor(h2 / 65536)
	local mul = ((l2 * 1664525) + (((h2Hi * 1664525) % 65536) * 65536) + 1013904223) % 4294967296
	local verifyTag = bxor32(mul, h1) % 4294967296
	return bridgeKey, verifyTag
end

local function decryptCoreUrl(hexStr, bridgeKey, verifyTag)
	if type(hexStr) ~= "string" or #hexStr == 0 or (#hexStr % 2) ~= 0 then
		return ""
	end
	local state = bxor32(bridgeKey, verifyTag % 16777216) % 16777216
	local outChars = {}
	local byteIdx = 0
	for i = 1, #hexStr, 2 do
		byteIdx = byteIdx + 1
		local encByte = tonumber(string.sub(hexStr, i, i + 1), 16) or 0
		state = (state * 214013 + 2531011 + byteIdx * 73) % 16777216
		local mask = bxor32(bxor32(math.floor(state / 256) % 256, state % 256), (byteIdx * 37) % 256) % 256
		local decByte = bxor32(encByte, mask) % 256
		outChars[byteIdx] = string.char(decByte)
	end
	return table.concat(outChars)
end

local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local httpRequest = (syn and syn.request)
	or (http and http.request)
	or http_request
	or (fluxus and fluxus.request)
	or request

local function fetchUrlText(url)
	if type(url) ~= "string" or #url == 0 then
		return nil
	end
	local ok, res = pcall(function()
		if httpRequest then
			local r = httpRequest({ Url = url, Method = "GET" })
			if r and (r.StatusCode == 200 or r.StatusCode == nil) then
				return r.Body
			end
			return nil
		else
			return game:HttpGet(url)
		end
	end)
	if ok and type(res) == "string" and #res > 0 then
		return res
	end
	return nil
end

local function copyToClipboard(text)
	local copyFunc = setclipboard or toclipboard or (Clipboard and Clipboard.set)
	if copyFunc then
		pcall(copyFunc, text)
		return true
	end
	return false
end

local function loadSavedKey()
	local ok, result = pcall(function()
		if isfolder and readfile and isfile then
			local path = KEY_CONFIG.SaveFolder .. "/" .. KEY_CONFIG.SaveKeyFile
			if isfolder(KEY_CONFIG.SaveFolder) and isfile(path) then
				return readfile(path)
			end
		end
		return nil
	end)
	if ok and type(result) == "string" and #result > 0 then
		return string.gsub(result, "^%s*(.-)%s*$", "%1")
	end
	return nil
end

local function saveValidKey(validKey)
	pcall(function()
		if isfolder and makefolder and writefile then
			if not isfolder(KEY_CONFIG.SaveFolder) then
				makefolder(KEY_CONFIG.SaveFolder)
			end
			writefile(KEY_CONFIG.SaveFolder .. "/" .. KEY_CONFIG.SaveKeyFile, validKey)
		end
	end)
end

local function clearSavedKey()
	pcall(function()
		if isfile and delfile then
			local path = KEY_CONFIG.SaveFolder .. "/" .. KEY_CONFIG.SaveKeyFile
			if isfile(path) then
				delfile(path)
			end
		end
	end)
end

local activeVerifyTag = KEY_CONFIG.VerifyTag
local activeHandshakeSlot = KEY_CONFIG.HandshakeSlot
local activeGetKeyUrl = KEY_CONFIG.GetKeyUrl
local activeCoreUrl = KEY_CONFIG.CoreScriptUrl
local activeEncryptedCoreUrl = KEY_CONFIG.EncryptedCoreUrl

local function refreshRemoteKeyConfig()
	if type(KEY_CONFIG.RemoteKeyJsonUrl) == "string"
		and #KEY_CONFIG.RemoteKeyJsonUrl > 0
		and not string.find(KEY_CONFIG.RemoteKeyJsonUrl, "TEN_GITHUB_CUA_BAN", 1, true)
	then
		local rawJson = fetchUrlText(KEY_CONFIG.RemoteKeyJsonUrl)
		if rawJson then
			local decOk, data = pcall(function()
				return HttpService:JSONDecode(rawJson)
			end)
			if decOk and type(data) == "table" then
				if tonumber(data.verify_tag) then
					activeVerifyTag = tonumber(data.verify_tag)
				end
				if tonumber(data.handshake_slot) then
					activeHandshakeSlot = tonumber(data.handshake_slot)
				end
				if type(data.get_key_url) == "string" and #data.get_key_url > 0 then
					activeGetKeyUrl = data.get_key_url
				end
				if type(data.core_url) == "string" and #data.core_url > 0 and not string.find(data.core_url, "TEN_GITHUB_CUA_BAN", 1, true) then
					activeCoreUrl = data.core_url
				end
				if type(data.encrypted_core_url) == "string" and #data.encrypted_core_url > 0 then
					activeEncryptedCoreUrl = data.encrypted_core_url
				end
			end
		end
	end
end
task.spawn(refreshRemoteKeyConfig)

local guiParent = (gethui and gethui()) or CoreGui or Players.LocalPlayer:WaitForChild("PlayerGui")
if guiParent:FindFirstChild("BananaCatKeySystemUI") then
	guiParent.BananaCatKeySystemUI:Destroy()
end

local failedAttempts = 0
local isLockedOut = false
local isChecking = false

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BananaCatKeySystemUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = guiParent

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 420, 0, 265)
MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 14)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(255, 205, 45)
MainStroke.Thickness = 1.6
MainStroke.Transparency = 0.2
MainStroke.Parent = MainFrame

local HeaderFrame = Instance.new("Frame")
HeaderFrame.Size = UDim2.new(1, 0, 0, 54)
HeaderFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 34)
HeaderFrame.BorderSizePixel = 0
HeaderFrame.Parent = MainFrame

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 14)
HeaderCorner.Parent = HeaderFrame

local HeaderBottomCover = Instance.new("Frame")
HeaderBottomCover.Size = UDim2.new(1, 0, 0, 14)
HeaderBottomCover.Position = UDim2.new(0, 0, 1, -14)
HeaderBottomCover.BackgroundColor3 = Color3.fromRGB(25, 25, 34)
HeaderBottomCover.BorderSizePixel = 0
HeaderBottomCover.Parent = HeaderFrame

local AccentLine = Instance.new("Frame")
AccentLine.Size = UDim2.new(1, 0, 0, 2)
AccentLine.Position = UDim2.new(0, 0, 1, 0)
AccentLine.BackgroundColor3 = Color3.fromRGB(255, 205, 45)
AccentLine.BorderSizePixel = 0
AccentLine.Parent = HeaderFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -110, 0, 24)
TitleLabel.Position = UDim2.new(0, 18, 0, 8)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "🍌 " .. KEY_CONFIG.HubTitle
TitleLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 17
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = HeaderFrame

local SubtitleLabel = Instance.new("TextLabel")
SubtitleLabel.Size = UDim2.new(1, -110, 0, 16)
SubtitleLabel.Position = UDim2.new(0, 18, 0, 31)
SubtitleLabel.BackgroundTransparency = 1
SubtitleLabel.Text = KEY_CONFIG.HubSubtitle
SubtitleLabel.TextColor3 = Color3.fromRGB(165, 168, 185)
SubtitleLabel.Font = Enum.Font.Gotham
SubtitleLabel.TextSize = 12
SubtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
SubtitleLabel.Parent = HeaderFrame

local AttemptBadge = Instance.new("TextLabel")
AttemptBadge.Size = UDim2.new(0, 88, 0, 26)
AttemptBadge.Position = UDim2.new(1, -102, 0.5, -13)
AttemptBadge.BackgroundColor3 = Color3.fromRGB(36, 36, 48)
AttemptBadge.Text = "Thử: 10/10"
AttemptBadge.TextColor3 = Color3.fromRGB(255, 215, 60)
AttemptBadge.Font = Enum.Font.GothamSemibold
AttemptBadge.TextSize = 12
AttemptBadge.Parent = HeaderFrame

local BadgeCorner = Instance.new("UICorner")
BadgeCorner.CornerRadius = UDim.new(0, 8)
BadgeCorner.Parent = AttemptBadge

local InputContainer = Instance.new("Frame")
InputContainer.Size = UDim2.new(1, -36, 0, 46)
InputContainer.Position = UDim2.new(0, 18, 0, 74)
InputContainer.BackgroundColor3 = Color3.fromRGB(12, 12, 17)
InputContainer.BorderSizePixel = 0
InputContainer.Parent = MainFrame

local InputCorner = Instance.new("UICorner")
InputCorner.CornerRadius = UDim.new(0, 10)
InputCorner.Parent = InputContainer

local InputStroke = Instance.new("UIStroke")
InputStroke.Color = Color3.fromRGB(60, 62, 80)
InputStroke.Thickness = 1.2
InputStroke.Parent = InputContainer

local KeyInput = Instance.new("TextBox")
KeyInput.Size = UDim2.new(1, -24, 1, 0)
KeyInput.Position = UDim2.new(0, 12, 0, 0)
KeyInput.BackgroundTransparency = 1
KeyInput.PlaceholderText = "Nhập Key kích hoạt tại đây..."
KeyInput.PlaceholderColor3 = Color3.fromRGB(105, 108, 125)
KeyInput.Text = ""
KeyInput.TextColor3 = Color3.fromRGB(245, 245, 250)
KeyInput.Font = Enum.Font.GothamMedium
KeyInput.TextSize = 14
KeyInput.ClearTextOnFocus = false
KeyInput.TextXAlignment = Enum.TextXAlignment.Left
KeyInput.Parent = InputContainer

KeyInput.Focused:Connect(function()
	TweenService:Create(InputStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(255, 205, 45) }):Play()
end)
KeyInput.FocusLost:Connect(function()
	TweenService:Create(InputStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(60, 62, 80) }):Play()
end)

local BarBg = Instance.new("Frame")
BarBg.Size = UDim2.new(1, -36, 0, 5)
BarBg.Position = UDim2.new(0, 18, 0, 128)
BarBg.BackgroundColor3 = Color3.fromRGB(35, 35, 46)
BarBg.BorderSizePixel = 0
BarBg.Parent = MainFrame

local BarBgCorner = Instance.new("UICorner")
BarBgCorner.CornerRadius = UDim.new(1, 0)
BarBgCorner.Parent = BarBg

local BarFill = Instance.new("Frame")
BarFill.Size = UDim2.new(1, 0, 1, 0)
BarFill.BackgroundColor3 = Color3.fromRGB(75, 215, 115)
BarFill.BorderSizePixel = 0
BarFill.Parent = BarBg

local BarFillCorner = Instance.new("UICorner")
BarFillCorner.CornerRadius = UDim.new(1, 0)
BarFillCorner.Parent = BarFill

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, -36, 0, 36)
StatusLabel.Position = UDim2.new(0, 18, 0, 140)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Bấm [Get Key] để lấy link vượt Key, sau đó dán Key vào ô trên và bấm [Check Key]."
StatusLabel.TextColor3 = Color3.fromRGB(185, 188, 205)
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextSize = 12
StatusLabel.TextWrapped = true
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = MainFrame

local CheckButton = Instance.new("TextButton")
CheckButton.Size = UDim2.new(0.5, -24, 0, 44)
CheckButton.Position = UDim2.new(0, 18, 0, 192)
CheckButton.BackgroundColor3 = Color3.fromRGB(255, 200, 40)
CheckButton.Text = "✓ CHECK KEY"
CheckButton.TextColor3 = Color3.fromRGB(20, 20, 26)
CheckButton.Font = Enum.Font.GothamBold
CheckButton.TextSize = 14
CheckButton.AutoButtonColor = true
CheckButton.Parent = MainFrame

local CheckCorner = Instance.new("UICorner")
CheckCorner.CornerRadius = UDim.new(0, 10)
CheckCorner.Parent = CheckButton

local GetKeyButton = Instance.new("TextButton")
GetKeyButton.Size = UDim2.new(0.5, -24, 0, 44)
GetKeyButton.Position = UDim2.new(0.5, 6, 0, 192)
GetKeyButton.BackgroundColor3 = Color3.fromRGB(40, 42, 56)
GetKeyButton.Text = "🔗 GET KEY"
GetKeyButton.TextColor3 = Color3.fromRGB(255, 215, 60)
GetKeyButton.Font = Enum.Font.GothamBold
GetKeyButton.TextSize = 14
GetKeyButton.AutoButtonColor = true
GetKeyButton.Parent = MainFrame

local GetKeyCorner = Instance.new("UICorner")
GetKeyCorner.CornerRadius = UDim.new(0, 10)
GetKeyCorner.Parent = GetKeyButton

local GetKeyStroke = Instance.new("UIStroke")
GetKeyStroke.Color = Color3.fromRGB(255, 205, 45)
GetKeyStroke.Thickness = 1.2
GetKeyStroke.Transparency = 0.4
GetKeyStroke.Parent = GetKeyButton

do
	local dragging, dragInput, dragStart, startPos
	HeaderFrame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = MainFrame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	HeaderFrame.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end)
end

local function shakeInputFrame()
	local origPos = UDim2.new(0, 18, 0, 74)
	for _, offset in ipairs({ -8, 8, -6, 6, -3, 3, 0 }) do
		InputContainer.Position = UDim2.new(0, 18 + offset, 0, 74)
		task.wait(0.03)
	end
	InputContainer.Position = origPos
end

local function selfDestructUI()
	isLockedOut = true
	KeyInput.TextEditable = false
	CheckButton.Active = false
	GetKeyButton.Active = false
	StatusLabel.TextColor3 = Color3.fromRGB(255, 75, 75)
	StatusLabel.Text = "⛔ Bạn đã nhập sai quá 10 lần! Giao diện đang tự hủy..."
	AttemptBadge.Text = "Thử: 0/10"
	AttemptBadge.TextColor3 = Color3.fromRGB(255, 75, 75)

	task.wait(1.3)
	local closeTween = TweenService:Create(MainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
		Size = UDim2.new(0, 0, 0, 0),
		BackgroundTransparency = 1,
	})
	closeTween:Play()
	closeTween.Completed:Wait()
	ScreenGui:Destroy()
end

GetKeyButton.MouseButton1Click:Connect(function()
	if isLockedOut then
		return
	end
	if copyToClipboard(activeGetKeyUrl) then
		StatusLabel.TextColor3 = Color3.fromRGB(95, 225, 135)
		StatusLabel.Text = "✅ Đã copy link Get Key vào Clipboard! Hãy dán ra trình duyệt để lấy Key."
	else
		KeyInput.Text = activeGetKeyUrl
		StatusLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
		StatusLabel.Text = "🔗 Link Get Key đã hiện trong ô nhập! Hãy copy và mở trên trình duyệt."
	end
end)

local function performKeyCheck(inputKey)
	if isLockedOut or isChecking then
		return
	end
	local cleanKey = string.gsub(inputKey or "", "^%s*(.-)%s*$", "%1")
	if #cleanKey == 0 then
		StatusLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
		StatusLabel.Text = "❌ Vui lòng nhập Key trước khi bấm Check!"
		task.spawn(shakeInputFrame)
		return
	end

	isChecking = true
	CheckButton.Text = "⏳ ĐANG KIỂM TRA..."
	StatusLabel.TextColor3 = Color3.fromRGB(255, 215, 60)
	StatusLabel.Text = "Đang kiểm tra mã băm Toán Học của Key..."

	refreshRemoteKeyConfig()
	local derivedBridgeKey, derivedVerifyTag = deriveKeyMaterial(cleanKey)

	if derivedBridgeKey and derivedVerifyTag == activeVerifyTag then
		saveValidKey(cleanKey)
		StatusLabel.TextColor3 = Color3.fromRGB(85, 235, 125)
		StatusLabel.Text = "🎉 Key chính xác! Đang tải và mở khóa máy ảo Aegis-V24.0..."
		CheckButton.Text = "✓ THÀNH CÔNG"

		local targetUrl = activeCoreUrl
		if type(activeEncryptedCoreUrl) == "string" and #activeEncryptedCoreUrl > 0 then
			targetUrl = decryptCoreUrl(activeEncryptedCoreUrl, derivedBridgeKey, derivedVerifyTag)
		end

		local scriptBody = fetchUrlText(targetUrl)

		if not scriptBody or #scriptBody < 100 then
			isChecking = false
			CheckButton.Text = "✓ CHECK KEY"
			StatusLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
			StatusLabel.Text = "⚠️ Đúng Key nhưng chưa tải được chuoi_mahoa.lua! Hãy điền đúng CoreScriptUrl."
			return
		end

		task.wait(0.3)
		local closeTween = TweenService:Create(MainFrame, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Size = UDim2.new(0, 0, 0, 0),
		})
		closeTween:Play()
		closeTween.Completed:Wait()
		ScreenGui:Destroy()

		_G[activeHandshakeSlot] = derivedBridgeKey
		if getfenv then
			pcall(function()
				getfenv()[activeHandshakeSlot] = derivedBridgeKey
			end)
		end

		local fn, compileErr = loadstring(scriptBody)
		if fn then
			task.spawn(fn)
		else
			_G[activeHandshakeSlot] = nil
			warn("[Banana Cat Hub] Lỗi nạp chuoi_mahoa.lua: " .. tostring(compileErr))
		end
	else
		clearSavedKey()
		failedAttempts = failedAttempts + 1
		local remaining = math.max(0, KEY_CONFIG.MaxAttempts - failedAttempts)

		AttemptBadge.Text = "Thử: " .. tostring(remaining) .. "/" .. tostring(KEY_CONFIG.MaxAttempts)
		local ratio = remaining / KEY_CONFIG.MaxAttempts
		TweenService:Create(BarFill, TweenInfo.new(0.25), {
			Size = UDim2.new(ratio, 0, 1, 0),
			BackgroundColor3 = ratio > 0.5 and Color3.fromRGB(75, 215, 115)
				or (ratio > 0.2 and Color3.fromRGB(255, 175, 45) or Color3.fromRGB(255, 75, 75)),
		}):Play()

		StatusLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
		StatusLabel.Text = "❌ Key không chính xác! Không thể tải và giải mã script. (Còn " .. tostring(remaining) .. " lần thử)"
		CheckButton.Text = "✓ CHECK KEY"

		task.spawn(shakeInputFrame)

		if failedAttempts >= KEY_CONFIG.MaxAttempts then
			isChecking = false
			selfDestructUI()
			return
		end
	end

	isChecking = false
end

CheckButton.MouseButton1Click:Connect(function()
	performKeyCheck(KeyInput.Text)
end)

local savedKey = loadSavedKey()
if savedKey then
	KeyInput.Text = savedKey
	task.defer(function()
		performKeyCheck(savedKey)
	end)
end
