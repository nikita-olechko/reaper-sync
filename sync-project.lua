-- Runs the batch script from the same directory and waits for it to finish
local source = debug.getinfo(1, "S").source
local scriptDir = source:match("@(.+[\\/])") or ""
local batchPath = scriptDir .. "sync-project.bat"

os.execute(string.format('"%s"', batchPath))
