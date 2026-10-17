
local G = getgenv()
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--==================================================
-- 1. LOCAL CUSTOM ACHIEVEMENT
--==================================================

local CustomAchievements

local achievementSuccess, achievementResult = pcall(function()
    return loadstring(game:HttpGet(
        "https://raw.githubusercontent.com/RegularVynixu/DOORS-Custom-Achievements/main/init.luau"
    ))()
end)

if achievementSuccess then
    CustomAchievements = achievementResult
else
    warn("Custom achievement library failed to load:", achievementResult)
end

local function GiveShockerAchievement()
    if not CustomAchievements then
        warn("Custom achievement library is unavailable.")
        return
    end

    local success, err = pcall(function()
        if not CustomAchievements:CheckOwned("ShockerNightmare") then
            CustomAchievements:Grant({
                Identifier = "ShockerNightmare",
                Title = "More And More Experience",
                Desc = "Your Encountering A Different Experience",
                Reason = "Encounter Shocker Nightmare",
                Image = "rbxassetid://14168700362"
            }, {
                CheckOwned = true,
                Remember = true
            })
        end
    end)

    if not success then
        warn("Achievement grant failed:", err)
    end
end

--==================================================
-- 2. GITHUB MODEL LOADER
--==================================================

G.LoadGithubModel = function(url)
    if not writefile or not getcustomasset or not request then
        warn("Required executor file functions are unavailable.")
        return nil
    end

    local rawUrl = url
        :gsub("github%.com", "raw.githubusercontent.com")
        :gsub("/blob/", "/")

    local function generateFileName(input)
        local hash = 0

        for i = 1, #input do
            hash = (hash * 31 + string.byte(input, i)) % 2^32
        end

        return "nightmare_shocker_" .. tostring(hash) .. ".rbxm"
    end

    local fileName = generateFileName(rawUrl)

    -- Attempt to load the cached file.
    if isfile then
        local checkSuccess, exists = pcall(isfile, fileName)

        if checkSuccess and exists then
            local cachedSuccess, cachedModel = pcall(function()
                local objects = game:GetObjects(getcustomasset(fileName))
                return objects and objects[1]
            end)

            if cachedSuccess and cachedModel then
                warn("Loaded cached Nightmare Shocker model.")
                return cachedModel
            end
        end
    end

    -- Download the model.
    local downloadSuccess, response = pcall(function()
        return request({
            Url = rawUrl,
            Method = "GET"
        })
    end)

    if not downloadSuccess or not response then
        warn("Model download request failed.")
        return nil
    end

    if response.StatusCode ~= 200 then
        warn("Model download HTTP status:", response.StatusCode)
        return nil
    end

    local writeSuccess, writeError = pcall(function()
        writefile(fileName, response.Body)
    end)

    if not writeSuccess then
        warn("Could not save model:", writeError)
        return nil
    end

    -- Load the downloaded model.
    local loadSuccess, result = pcall(function()
        local objects = game:GetObjects(getcustomasset(fileName))
        return objects and objects[1]
    end)

    if not loadSuccess or not result then
        warn("Downloaded file could not be loaded as a Roblox model.")
        return nil
    end

    warn("Nightmare Shocker model loaded successfully.")
    return result
end

--==================================================
-- 3. NIGHTMARE SHOCKER
--==================================================

local function SpawnShocker()
    local LP = Players.LocalPlayer
    local Char = LP.Character or LP.CharacterAdded:Wait()
    local Hum = Char:WaitForChild("Humanoid")
    local Root = Char:WaitForChild("HumanoidRootPart")
    local cam = workspace.CurrentCamera

    -- Camera shaker
    local shakerModule = ReplicatedStorage:FindFirstChild("CameraShaker")

    local cameraShaker
    local camShake

    if shakerModule then
        local success, result = pcall(require, shakerModule)

        if success then
            cameraShaker = result

            camShake = cameraShaker.new(
                Enum.RenderPriority.Camera.Value,
                function(cf)
                    local currentCam = workspace.CurrentCamera

                    if currentCam then
                        currentCam.CFrame = currentCam.CFrame * cf
                    end
                end
            )

            camShake:Start()
        else
            warn("CameraShaker failed to initialize:", result)
        end
    else
        warn("CameraShaker module not found.")
    end

    -- Updated GitHub model URL
    local modelUrl =
        "https://github.com/Ilikerobloxdoors/Nightmare-Shocker/blob/main/Nightmare%20Shocker.rbxm"

    local entity = G.LoadGithubModel(modelUrl)

    if not entity then
        warn("Nightmare Shocker model failed to load.")
        return
    end

    -- Verify the returned object is a Model.
    if not entity:IsA("Model") then
        warn("Expected a Model, received:", entity.ClassName)
        entity:Destroy()
        return
    end

    -- Find the named part, or use another BasePart.
    local mainPart = entity:FindFirstChild("OOGA BOOGAAAA", true)

    if not mainPart or not mainPart:IsA("BasePart") then
        mainPart = entity:FindFirstChildWhichIsA("BasePart", true)
    end

    if not mainPart then
        warn("No BasePart found inside Nightmare Shocker.")

        for _, obj in ipairs(entity:GetDescendants()) do
            warn("Model object:", obj:GetFullName(), obj.ClassName)
        end

        entity:Destroy()
        return
    end

    entity.PrimaryPart = mainPart

    -- Anchor every physical part so the model doesn't fall apart.
    for _, obj in ipairs(entity:GetDescendants()) do
        if obj:IsA("BasePart") then
            obj.Anchored = true
        end
    end

    -- Position in front of the player.
    entity.Parent = workspace
    entity:PivotTo(Root.CFrame * CFrame.new(0, 0, -12))

    warn("Nightmare Shocker spawned:", entity:GetFullName())

    local spawnSound = entity:FindFirstChild("PlaySound", true)
    local attackSound = entity:FindFirstChild("HORROR SCREAM 15", true)

    if spawnSound and spawnSound:IsA("Sound") then
        spawnSound.PlayOnRemove = false
        spawnSound:Play()
    end

    --==================================================
    -- 4. LOOK DETECTION
    --==================================================

    local lookingTime = 0
    local hasAttacked = false
    local isDisappearing = false

    local function isPlayerLooking()
        if not entity or not entity.Parent or not mainPart.Parent then
            return false
        end

        cam = workspace.CurrentCamera

        if not cam then
            return false
        end

        local entityPos = mainPart.Position
        local _, onScreen = cam:WorldToViewportPoint(entityPos)

        if not onScreen then
            return false
        end

        local direction = entityPos - cam.CFrame.Position

        if direction.Magnitude == 0 then
            return true
        end

        return direction.Unit:Dot(cam.CFrame.LookVector) > 0.7
    end

    --==================================================
    -- 5. DISAPPEAR AND GRANT ACHIEVEMENT
    --==================================================

    local function disappearAndGrant()
        if isDisappearing or hasAttacked then
            return
        end

        isDisappearing = true

        if entity and entity.Parent then
            entity:Destroy()
        end

        GiveShockerAchievement()
    end

    --==================================================
    -- 6. INITIAL LOOK CHECK
    --==================================================

    task.wait(0.1)

    if not isPlayerLooking() then
        disappearAndGrant()
        return
    end

    --==================================================
    -- 7. LOOK TRACKING AND ATTACK
    --==================================================

    task.spawn(function()
        local lastLookState = isPlayerLooking()
        local timeSinceLastLook = 0

        while entity and entity.Parent and not hasAttacked do
            task.wait(0.05)

            if not entity or not entity.Parent then
                break
            end

            local currentLookState = isPlayerLooking()

            if currentLookState then
                if not lastLookState then
                    lookingTime = 0
                end

                lookingTime = lookingTime + 0.05
                timeSinceLastLook = 0
            else
                timeSinceLastLook = timeSinceLastLook + 0.05

                if lookingTime > 0.1
                    and lookingTime < 1.9
                    and timeSinceLastLook > 0.1 then

                    disappearAndGrant()
                    break
                end

                if timeSinceLastLook > 0.5 then
                    lookingTime = 0
                end
            end

            lastLookState = currentLookState

            --==================================================
            -- 8. ATTACK: 50 DAMAGE
            --==================================================

            if lookingTime >= 1.9 and not hasAttacked then
                hasAttacked = true

                if attackSound and attackSound:IsA("Sound") then
                    attackSound:Play()
                end

                -- Move the entire model rather than only one part.
                local attackTween = TweenService:Create(
                    mainPart,
                    TweenInfo.new(
                        0.5,
                        Enum.EasingStyle.Sine,
                        Enum.EasingDirection.In
                    ),
                    {
                        CFrame = Root.CFrame
                    }
                )

                attackTween:Play()

                task.delay(0.37, function()
                    if Hum and Hum.Health > 0 then
                        -- Increased damage: 50 HP
                        Hum:TakeDamage(50)

                        if camShake and cameraShaker then
                            pcall(function()
                                camShake:Shake(
                                    cameraShaker.Presets.Explosion
                                )
                            end)
                        end

                        -- Set the local death cause when available.
                        local statsFolder =
                            ReplicatedStorage:FindFirstChild("GameStats")

                        if statsFolder then
                            local playerStat =
                                statsFolder:FindFirstChild("Player_" .. Char.Name)

                            local total = playerStat
                                and playerStat:FindFirstChild("Total")

                            local deathCause = total
                                and total:FindFirstChild("DeathCause")

                            if deathCause then
                                deathCause.Value = "Shocker"
                            end
                        end
                    end
                end)

                attackTween.Completed:Wait()
                task.wait(0.75)

                if entity and entity.Parent then
                    entity:Destroy()
                end

                break
            end
        end
    end)
end

--==================================================
-- 9. START
--==================================================

task.spawn(SpawnShocker)
