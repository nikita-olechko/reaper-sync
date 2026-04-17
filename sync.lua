-- REAPER Lua Script: Search drives C-F for reaper-plugins and git pull
local subpath = [[\REAPER\UserPlugins\reaper-plugins]]
local drives = {"C", "D", "E", "F"}
local found_path = nil

-- Loop through drives to find the directory
for _, letter in ipairs(drives) do
    local full_path = letter .. ":" .. subpath
    -- Use reaper's built-in check for directory existence
    if reaper.RecursiveCreateDirectory(full_path, 0) == 0 then 
        -- If it exists (0 means it already exists or was created)
        found_path = full_path
        break
    end
end

if found_path then
    -- Construct the command: switch drive & dir, then git pull
    -- We use [[ ]] for strings to handle backslashes easily
    local cmd = 'cd /d "' .. found_path .. '" && git pull'
    
    -- Execute in the system shell
    local success = os.execute(cmd)
    
    if success then
        reaper.ShowConsoleMsg("Git Pull Successful in: " .. found_path .. "\n")
    else
        reaper.ShowConsoleMsg("Error: Git pull failed. Is Git installed and the folder a repo?\n")
    end
else
    reaper.ShowMessageBox("Could not find the plugins folder on drives C through F.", "Error", 0)
end
