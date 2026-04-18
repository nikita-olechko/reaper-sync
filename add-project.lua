-- add-project.lua
-- REAPER script to add a new project
-- Creates project folder, initializes git repository, and updates project mappings

local script_path = debug.getinfo(1,'S').source:match[[^@?(.*[\/])[^\/]-$]]
local mapping_file = script_path .. "project-mappings.txt"
local reaper_path = reaper.GetResourcePath()
local projects_root = reaper_path .. "/Projects"

-- Function to trim whitespace
function trim(s)
    return s:match("^%s*(.-)%s*$")
end

-- Function to validate project name
function validate_project_name(name)
    if not name or name == "" then
        return false, "Project name cannot be empty"
    end
    
    if name:match("[^%w_%-]") then
        return false, "Project name can only contain letters, numbers, underscores, and hyphens"
    end
    
    return true, nil
end

-- Function to check if folder exists
function folder_exists(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return true
    end
    
    -- Try to create and immediately remove a file to test if directory exists
    local test_file = path .. "/test_write_access"
    local file = io.open(test_file, "w")
    if file then
        file:close()
        os.remove(test_file)
        return true
    end
    
    return false
end

-- Function to execute system command and get result
function execute_command(cmd)
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    local success = handle:close()
    return success, result
end

-- Function to create directory
function create_directory(path)
    local cmd = 'mkdir "' .. path .. '"'
    return execute_command(cmd)
end

-- Function to append to file
function append_to_file(filename, text)
    local file = io.open(filename, "a")
    if not file then
        return false, "Cannot open file: " .. filename
    end
    
    file:write(text .. "\n")
    file:close()
    return true, nil
end

-- Main function
function main()
    -- Ensure projects directory exists
    if not folder_exists(projects_root) then
        reaper.ShowMessageBox("Projects directory not found. Creating: " .. projects_root, "Info", 0)
        local success, err = create_directory(projects_root)
        if not success then
            reaper.ShowMessageBox("Failed to create projects directory:\n" .. projects_root .. "\n\nError: " .. (err or "Unknown error"), "Error", 0)
            return
        end
    end
    
    -- Prompt for project name
    local retval, project_name = reaper.GetUserInputs("Add New Project", 1, "Project name:", "")
    
    if not retval then
        return -- User cancelled
    end
    
    project_name = trim(project_name)
    
    -- Validate project name
    local valid, error_msg = validate_project_name(project_name)
    if not valid then
        reaper.ShowMessageBox("Invalid project name: " .. error_msg, "Error", 0)
        return
    end
    
    local full_project_name = "reaper-projects-" .. project_name
    local project_path = projects_root .. "/" .. full_project_name
    
    -- Check if project already exists
    if folder_exists(project_path) then
        reaper.ShowMessageBox("Project already exists:\n" .. full_project_name .. "\n\nPath: " .. project_path, "Error", 0)
        return
    end
    
    -- Create project folder
    local success, err = create_directory(project_path)
    if not success then
        reaper.ShowMessageBox("Failed to create project folder:\n" .. project_path .. "\n\nError: " .. (err or "Unknown error"), "Error", 0)
        return
    end
    
    -- Initialize git repository
    reaper.ShowMessageBox("Creating project: " .. full_project_name .. "\nLocation: " .. project_path, "Creating Project", 0)
    
    local git_success = false
    if folder_exists(project_path) then
        local git_init_cmd = 'git init "' .. project_path .. '"'
        local init_success, init_err = execute_command(git_init_cmd)
        
        if init_success then
            -- Set up main branch from the start
            local checkout_cmd = 'git -C "' .. project_path .. '" checkout -b main'
            execute_command(checkout_cmd)
            git_success = true
            
            -- Create initial README.md and commit
            local readme_path = project_path .. "/README.md"
            local readme_content = "# " .. full_project_name .. "\n\nREAPER project: " .. project_name .. "\nCreated: " .. os.date("%Y-%m-%d %H:%M:%S")
            
            local readme_file = io.open(readme_path, "w")
            if readme_file then
                readme_file:write(readme_content)
                readme_file:close()
                
                -- Initial commit
                execute_command('git -C "' .. project_path .. '" add .')
                local commit_success, commit_err = execute_command('git -C "' .. project_path .. '" commit -m "Initial commit for ' .. project_name .. '"')
                if not commit_success then
                    reaper.ShowMessageBox("Warning: Failed to make initial commit.\n\nError: " .. (commit_err or "Unknown error"), "Warning", 0)
                    git_success = false
                end
            else
                git_success = false
            end
        else
            reaper.ShowMessageBox("Warning: Failed to initialize git repository.\nFolder created but git initialization failed.\n\nError: " .. (init_err or "Unknown error"), "Warning", 0)
            git_success = false
        end
    end
    
    -- Check if GitHub CLI is available
    local gh_success, gh_result = execute_command("gh --version")
    
    if not gh_success then
        reaper.ShowMessageBox("GitHub CLI not found.\n\nGitHub CLI is required for this script.\nPlease install GitHub CLI from:\nhttps://cli.github.com/\n\nThen try again.", "Error", 0)
        return
    end
    -- Check if GitHub repository already exists
    local repo_check_cmd = 'gh repo view "' .. full_project_name .. '"'
    local repo_exists, repo_check_result = execute_command(repo_check_cmd)
    if repo_exists then
            reaper.ShowMessageBox("GitHub repository already exists: " .. full_project_name .. "\n\nUsing existing repository.", "Repository Exists", 0)
            
            -- Get repository URL for existing repo
            local url_cmd = 'gh repo view "' .. full_project_name .. '" --json url -q .url'
            local url_success, url_result = execute_command(url_cmd)
            
            if url_success and url_result then
                repo_url = trim(url_result)
                
                -- Add remote origin and push to existing repository
                if git_success then
                    -- Set up remote connection
                    local add_remote_cmd = 'git -C "' .. project_path .. '" remote add origin "' .. repo_url .. '.git"'
                    execute_command(add_remote_cmd)
                    
                    -- Fetch to understand remote state
                    local fetch_cmd = 'git -C "' .. project_path .. '" fetch origin'
                    execute_command(fetch_cmd)
                    
                    -- Set up tracking and push
                    local track_cmd = 'git -C "' .. project_path .. '" branch --set-upstream-to=origin/main main'
                    execute_command(track_cmd)
                    
                    local push_success, push_result = execute_command('git -C "' .. project_path .. '" push origin main')
                    
                    if push_success then
                        reaper.ShowMessageBox("Connected and pushed to existing GitHub repository!\n\nRepository: " .. repo_url, "Success", 0)
                    else
                        -- Try force push as fallback
                        local force_push_success, force_result = execute_command('git -C "' .. project_path .. '" push --force-with-lease origin main')
                        if force_push_success then
                            reaper.ShowMessageBox("Force pushed to existing GitHub repository!\n\nRepository: " .. repo_url, "Success", 0)
                        else
                            reaper.ShowMessageBox("Connected to existing repository but failed to push initial commit.\n\nRepository: " .. repo_url, "Warning", 0)
                        end
                    end
                else
                    reaper.ShowMessageBox("Connected to existing repository!\n\nRepository: " .. repo_url .. "\n\nNote: Git initialization failed earlier, so no initial commit was pushed.", "Partial Success", 0)
                end
            else
                reaper.ShowMessageBox("Repository exists but failed to get repository URL.\n\nPlease check your GitHub account and try again.", "Error", 0)
                return
            end
        else
            reaper.ShowMessageBox("GitHub CLI found. Creating new remote repository...\n\nRepository: " .. full_project_name, "Creating GitHub Repository", 0)
            
            -- Create GitHub repository
            local create_cmd = 'gh repo create "' .. full_project_name .. '" --private --description "REAPER project: ' .. project_name .. '" --confirm'
            local create_success, create_result = execute_command(create_cmd)
            
            if create_success then
                -- Get repository URL
        local url_cmd = 'gh repo view "' .. full_project_name .. '" --json url -q .url'
        local url_success, url_result = execute_command(url_cmd)
        
        if not url_success or not url_result then
            reaper.ShowMessageBox("GitHub repository was created, but failed to get repository URL.\n\nPlease check your GitHub account.", "Error", 0)
            return
        end
        
        local repo_url = trim(url_result)
                    -- Add remote origin and push if git was successful
                    if git_success then
                        -- Set up remote connection
                        local add_remote_cmd = 'git -C "' .. project_path .. '" remote add origin "' .. repo_url .. '.git"'
                        execute_command(add_remote_cmd)
                        
                        -- Push with upstream tracking
                        local push_success, push_result = execute_command('git -C "' .. project_path .. '" push -u origin main')
                        
                        if push_success then
                            reaper.ShowMessageBox("GitHub repository created and initial commit pushed!\n\nRepository: " .. repo_url, "Success", 0)
                        else
                            reaper.ShowMessageBox("GitHub repository created but failed to push initial commit.\n\nRepository: " .. repo_url, "Warning", 0)
                        end
                    else
                        reaper.ShowMessageBox("GitHub repository created!\n\nRepository: " .. repo_url .. "\n\nNote: Git initialization failed earlier, so no initial commit was pushed.", "Partial Success", 0)
                    end
                else
                    reaper.ShowMessageBox("GitHub repository may have been created, but failed to get repository URL.\n\nPlease check your GitHub account and try again.", "Error", 0)
                    return
                end
            else
                reaper.ShowMessageBox("Failed to create GitHub repository.\n\nThis may happen if:\n- Repository already exists\n- Authentication failed\n- Network issues\n\nError: " .. (create_result or "Unknown error"), "Error", 0)
                return
            end
        end
    end
    
    -- Add to project mappings
    local mapping_entry = full_project_name .. ": " .. repo_url
    local append_success, append_err = append_to_file(mapping_file, mapping_entry)
    
    if not append_success then
        reaper.ShowMessageBox("Project created but failed to add to mappings file:\n" .. mapping_file .. "\n\nError: " .. (append_err or "Unknown error") .. "\n\nPlease add manually:\n" .. mapping_entry, "Warning", 0)
    else
        local success_msg = "Project created successfully!\n\nProject: " .. full_project_name .. "\nLocation: " .. project_path .. "\nRepository: " .. repo_url .. "\n\nAdded to project mappings.\n\nYou can now use this project with your sync scripts!"
        reaper.ShowMessageBox(success_msg, "Success", 0)
    end
end

-- Run the script
main()