-- =========================================================================
-- AERONAUTICS FLEET OS - DEPLOYMENT SCRIPT
-- =========================================================================
-- Bootstraps the OS onto a new CC:Tweaked computer.
--
-- USAGE:
-- 1. Upload your Aeronautics Fleet OS code to a public GitHub repository.
-- 2. Modify the 'repoBase' URL below to point to the raw files of your repo.
-- 3. On your CC computer, run: wget <RAW_URL_TO_THIS_FILE> deploy.lua
-- 4. Run: deploy
-- =========================================================================

-- IMPORTANT: Change this to your actual raw GitHub URL base!
-- Example: "https://raw.githubusercontent.com/YourUsername/YourRepo/main/"
local repoBase = "https://raw.githubusercontent.com/YourUsername/YourRepoName/main/"

local filesToDownload = {
    "Modules/ctrl_typewriter.lua",
    "Modules/stabilizer.lua",
    "Modules/airbrake_snippet.lua",
    "Utils/ship_telemetry.lua",
    "Drone/main.lua",
    "Drone/config.lua",
    "Drone/auto_tune.lua",
    "VTOL/main.lua",
    "VTOL/config.lua",
}

term.clear()
term.setCursorPos(1,1)
print("=== AERONAUTICS FLEET OS DEPLOYMENT ===")
print("Base URL: " .. repoBase)
print("---------------------------------------")

for _, file in ipairs(filesToDownload) do
    print("Fetching -> " .. file)
    
    -- Ensure directory structure exists
    local pathParts = {}
    for part in string.gmatch(file, "[^/]+") do
        table.insert(pathParts, part)
    end
    
    if #pathParts > 1 then
        local dir = ""
        for i = 1, #pathParts - 1 do
            dir = dir .. pathParts[i] .. "/"
        end
        if not fs.exists(dir) then
            fs.makeDir(dir)
        end
    end

    local url = repoBase .. file
    local response = http.get(url)
    
    if response then
        local content = response.readAll()
        response.close()
        
        local f = fs.open(file, "w")
        if f then
            f.write(content)
            f.close()
            print("  [OK] Saved.")
        else
            print("  [ERROR] Could not write file locally.")
        end
    else
        print("  [ERROR] HTTP GET failed. Check URL or GitHub availability.")
    end
end

print("---------------------------------------")
print("Deployment complete! Have a safe flight.")
