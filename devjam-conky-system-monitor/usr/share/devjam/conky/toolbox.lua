-- ===================================================================
-- Global Variables for CPU Power Measurement
-- ===================================================================
local last_energy = nil
local last_time = nil

-- ===================================================================
-- Global Variables & State for Resolution Watcher & Caching
-- ===================================================================
local watcher_started = false
local cached_display_info = nil
local cached_scale_factor = nil

-- ===================================================================
-- Function: Display Scale Factor (5-second interval for KDE settings)
-- ===================================================================
local cached_scale = nil
local scale_last_check = 0

function get_scale(size_factor)
    size_factor = size_factor or 0.8
    local now = os.time()

    -- Only check screen scale if at least 5 seconds have passed
    if not cached_scale or (now - scale_last_check >= 5) then
        local base_scale = 1.0

        -- 1. Check Xft.dpi via xrdb first
        local handle = io.popen("xrdb -query 2>/dev/null | grep -i 'Xft.dpi'")
        if handle then
            local output = handle:read("*a")
            handle:close()
            if output then
                local dpi_str = output:match("(%d+)%s*$")
                local dpi = tonumber(dpi_str)
                if dpi and dpi > 0 then
                    base_scale = dpi / 96.0
                end
            end
        end

        -- 2. Fallback: KScreen via jq
        if base_scale == 1.0 then
            local kwin_handle = io.popen("timeout 1s kscreen-doctor -j 2>/dev/null | jq -r '.outputs[] | select(.enabled == true) | select(.scale != null) | .scale' 2>/dev/null | head -n1")
            if kwin_handle then
                local kwin_scale_str = kwin_handle:read("*a")
                kwin_handle:close()
                local kwin_scale = tonumber(kwin_scale_str)
                if kwin_scale and kwin_scale > 0 then
                    base_scale = kwin_scale
                end
            end
        end

        cached_scale = base_scale
        scale_last_check = now
    end

    return cached_scale * size_factor
end

-- ===================================================================
-- Function: Get CPU Model / Brand Name
-- ===================================================================
function conky_get_cpu_name()
    local f = io.open("/proc/cpuinfo", "r")
    if not f then return "N/A" end

    local model_name = nil
    for line in f:lines() do
        model_name = line:match("^model name%s*:%s*(.+)")
        if model_name then break end
    end
    f:close()

    if model_name then
        -- Clean up model name for a clean Conky layout (strips redundant branding)
        model_name = model_name:gsub("%(R%)", "")
                              :gsub("%(TM%)", "")
                              :gsub("12th Gen ", "")
                              :gsub("13th Gen ", "")
                              :gsub("14th Gen ", "")
                              :gsub("Processor", "")
                              :gsub("CPU", "")
                              :gsub("%s+", " ")
                              :match("^%s*(.-)%s*$")
        return model_name
    end

    return "N/A"
end

-- ===================================================================
-- Helper Function: Safe single-line file reader
-- ===================================================================
local function read_sysfs_line(filepath)
    local f = io.open(filepath, "r")
    if f then
        local content = f:read("*l")
        f:close()
        return content
    end
    return nil
end

-- ===================================================================
-- Helper: Parse CPU list ranges (e.g. "0-15,28-31") into a table
-- ===================================================================
local function parse_cpus_range(str)
    if not str or str == "" then return {} end
    local cpus = {}
    for part in str:gmatch("[^,]+") do
        local start_id, end_id = part:match("(%d+)%-(%d+)")
        if start_id and end_id then
            for i = tonumber(start_id), tonumber(end_id) do
                cpus[i] = true
            end
        else
            local single_id = part:match("(%d+)")
            if single_id then
                cpus[tonumber(single_id)] = true
            end
        end
    end
    return cpus
end

-- ===================================================================
-- Function: CPU Core & Thread Count (Intel Hybrid P/E Support)
-- ===================================================================
local cached_cpu_cores_info = nil

function conky_get_cpu_cores()
    if cached_cpu_cores_info then
        return cached_cpu_cores_info
    end

    local threads = 0
    local core_map = {}
    local f = io.open("/proc/cpuinfo", "r")
    
    if f then
        local phys_id = "0"
        for line in f:lines() do
            if line:match("^processor") then
                threads = threads + 1
            elseif line:match("^physical id") then
                phys_id = line:match(":%s*(%d+)") or "0"
            elseif line:match("^core id") then
                local cid = line:match(":%s*(%d+)")
                if cid then
                    core_map[phys_id .. ":" .. cid] = true
                end
            end
        end
        f:close()
    end

    local phys_cores = 0
    for _ in pairs(core_map) do
        phys_cores = phys_cores + 1
    end
    if phys_cores == 0 then phys_cores = threads end

    -- Check PMU & sysfs candidate paths for P-core and E-core CPU lists
    local p_str = read_sysfs_line("/sys/bus/event_source/devices/cpu_core/cpus") 
               or read_sysfs_line("/sys/devices/cpu_core/cpus")
               or read_sysfs_line("/sys/devices/system/cpu/types/core/cpus")

    local e_str = read_sysfs_line("/sys/bus/event_source/devices/cpu_atom/cpus") 
               or read_sysfs_line("/sys/devices/cpu_atom/cpus")
               or read_sysfs_line("/sys/devices/system/cpu/types/atom/cpus")

    if p_str or e_str then
        local p_cpus = parse_cpus_range(p_str)
        local e_cpus = parse_cpus_range(e_str)

        local p_phys_map = {}
        local e_phys_map = {}

        for cpu_id in pairs(p_cpus) do
            local cid = read_sysfs_line("/sys/devices/system/cpu/cpu" .. cpu_id .. "/topology/core_id")
            local pid = read_sysfs_line("/sys/devices/system/cpu/cpu" .. cpu_id .. "/topology/physical_package_id") or "0"
            if cid then p_phys_map[pid .. ":" .. cid] = true end
        end

        for cpu_id in pairs(e_cpus) do
            local cid = read_sysfs_line("/sys/devices/system/cpu/cpu" .. cpu_id .. "/topology/core_id")
            local pid = read_sysfs_line("/sys/devices/system/cpu/cpu" .. cpu_id .. "/topology/physical_package_id") or "0"
            if cid then e_phys_map[pid .. ":" .. cid] = true end
        end

        local p_count = 0
        for _ in pairs(p_phys_map) do p_count = p_count + 1 end
        local e_count = 0
        for _ in pairs(e_phys_map) do e_count = e_count + 1 end

        if p_count > 0 or e_count > 0 then
            cached_cpu_cores_info = string.format("%d Cores (%dP + %dE) / %d Threads", phys_cores, p_count, e_count, threads)
            return cached_cpu_cores_info
        end
    end

    cached_cpu_cores_info = string.format("%d Cores / %d Threads", phys_cores, threads)
    return cached_cpu_cores_info
end

-- ===================================================================
-- Function: CPU Scaling Driver (e.g. intel_pstate, amd-pstate)
-- ===================================================================
function conky_get_cpu_driver()
    local f = io.open("/sys/devices/system/cpu/cpu0/cpufreq/scaling_driver", "r")
    if not f then return "N/A" end
    
    local driver = f:read("*l")
    f:close()
    
    if driver and driver ~= "" then
        return driver
    end
    
    return "N/A"
end

-- ===================================================================
-- Optimized Function: Universal CPU Temperature (Pure Lua Sysfs)
-- ===================================================================
local cached_hwmon_file = nil

function conky_get_cpu_temp()
    -- Find the hardware monitor temp file ONCE to prevent spawning processes every second
    if not cached_hwmon_file then
        for i = 0, 10 do
            local hwmon_path = "/sys/class/hwmon/hwmon" .. i
            local f = io.open(hwmon_path .. "/name", "r")
            if f then
                local name = f:read("*l")
                f:close()
                if name == "coretemp" or name == "k10temp" or name == "zenpower" or name == "cpu_thermal" then
                    -- Default to temp1_input, which is standard for most CPUs
                    cached_hwmon_file = hwmon_path .. "/temp1_input"
                    break
                end
            end
        end
    end

    -- Directly read the file (Instantaneous, 0 CPU overhead)
    if cached_hwmon_file then
        local f = io.open(cached_hwmon_file, "r")
        if f then
            local temp_str = f:read("*a")
            f:close()
            local temp = tonumber(temp_str)
            if temp then
                return string.format("%d°C", math.floor((temp / 1000) + 0.5))
            end
        end
    end
    
    return "N/A"
end

-- ===================================================================
-- Function: CPU Max Frequency Across All Cores
-- ===================================================================
function conky_get_cpu_freq_max()
    local max_khz = 0
    local core = 0

    -- Iterate through all cores in /sys/devices/system/cpu/cpuX/cpufreq/scaling_cur_freq
    while true do
        local f = io.open(string.format("/sys/devices/system/cpu/cpu%d/cpufreq/scaling_cur_freq", core), "r")
        if not f then break end -- Stop when no further core is found

        local val = tonumber(f:read("*l"))
        f:close()

        if val and val > max_khz then
            max_khz = val
        end
        core = core + 1
    end

    if max_khz > 0 then
        return string.format("%.2f GHz", max_khz / 1000000)
    end

    return "N/A"
end

-- ===================================================================
-- Function: CPU Scaling Governor
-- ===================================================================
function conky_get_cpu_governor()
    local f = io.open("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor", "r")
    if not f then return "N/A" end
    
    local gov = f:read("*l")
    f:close()
    
    if gov and gov ~= "" then
        return gov
    end
    
    return "N/A"
end

-- ===================================================================
-- Function: CPU Energy Performance Preference (EPP)
-- ===================================================================
function conky_get_cpu_epp()
    local f = io.open("/sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference", "r")
    if not f then return "N/A" end
    
    local epp = f:read("*l")
    f:close()
    
    if epp and epp ~= "" then
        return epp
    end
    
    return "N/A"
end

-- ===================================================================
-- Function: CPU Power Draw (intel-rapl)
-- ===================================================================
function conky_get_cpu_power()
    local file = io.open("/sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj", "r")
    if not file then return "N/A" end
    
    local energy_str = file:read("*all")
    file:close()
    
    local energy = tonumber(energy_str)
    
    -- Read exact system uptime in seconds with microsecond precision
    local now = nil
    local uptime_file = io.open("/proc/uptime", "r")
    if uptime_file then
        local uptime_str = uptime_file:read("*all")
        uptime_file:close()
        now = tonumber(uptime_str:match("^(%S+)"))
    else
        now = os.time()
    end
    
    if last_energy and last_time and energy and now then
        local de = energy - last_energy
        local dt = now - last_time
        
        if dt > 0 and de >= 0 then
            local watts = (de / dt) / 1000000
            last_energy = energy
            last_time = now
            return string.format("%.2f W", watts)
        end
    end
    
    last_energy = energy
    last_time = now
    return "N/A"
end

-- ===================================================================
-- Optimized Helper: Auto-detect Active Network Interface (10s Cache)
-- ===================================================================
local cached_net_iface = nil
local last_net_check = 0

local function get_active_interface()
    local now = os.time()
    
    -- Only re-evaluate network interfaces every 10 seconds to allow smooth transitions
    if cached_net_iface and (now - last_net_check < 10) then
        return cached_net_iface
    end

    local best_iface = ""
    local f = io.open("/proc/net/dev", "r")
    if f then
        for line in f:lines() do
            local iface = line:match("^%s*([%w%-]+):")
            -- Exclude loopback, virtual bridges, and docker interfaces
            if iface and iface ~= "lo" and not iface:match("^br%-") and not iface:match("^docker") and not iface:match("^veth") then
                -- Check if the interface is actually physically 'up'
                local state_f = io.open("/sys/class/net/" .. iface .. "/operstate", "r")
                if state_f then
                    local state = state_f:read("*l")
                    state_f:close()
                    if state == "up" then
                        best_iface = iface
                        break
                    end
                end
            end
        end
        f:close()
    end

    cached_net_iface = best_iface
    last_net_check = now
    return cached_net_iface
end

-- ===================================================================
-- Functions: Network Speed & Percentages (1 Gbit / 125 MB/s)
-- ===================================================================
function conky_get_downspeed()
    local iface = get_active_interface()
    local speed = conky_parse('${downspeed ' .. iface .. '}')
    return speed .. '/s'
end

function conky_get_upspeed()
    local iface = get_active_interface()
    local speed = conky_parse('${upspeed ' .. iface .. '}')
    return speed .. '/s'
end

function conky_down_percent(iface)
    if not iface or iface == "" then
        iface = get_active_interface()
    end
    local speed = tonumber(conky_parse('${downspeedf ' .. iface .. '}')) or 0
    local pct = (speed / 125000) * 100
    return math.min(pct, 100)
end

function conky_up_percent(iface)
    if not iface or iface == "" then
        iface = get_active_interface()
    end
    local speed = tonumber(conky_parse('${upspeedf ' .. iface .. '}')) or 0
    local pct = (speed / 125000) * 100
    return math.min(pct, 100)
end

-- ===================================================================
-- Function: Display Info (Resolution & Refresh Rate) - Cached
-- ===================================================================
function conky_get_display_info()
    if cached_display_info then
        return cached_display_info
    end

    -- 1. KScreen
    local cmd = [[timeout 1s kscreen-doctor -j 2>/dev/null | jq -r '.outputs[] | select(.enabled == true) as $out | $out.modes[] | select(.id == $out.currentModeId) | "\(.size.width)x\(.size.height)@\( ((.refreshRate - (.refreshRate | round)) | if . < 0 then -. else . end) as $diff | if $diff < 0.01 then (.refreshRate | round) else ((.refreshRate * 100 | round) / 100) end)Hz"' 2>/dev/null | head -n1]]

    local h = io.popen(cmd)
    if h then
        local res = h:read("*l")
        h:close()
        if res and res ~= "" and res ~= "null" then
            cached_display_info = res
            return cached_display_info
        end
    end

    -- 2. Fallback: xrandr
    local h_xrandr = io.popen([[xrandr --current 2>/dev/null | awk '/\*/ {print $1 "@" int($2) "Hz"; exit}']])
    if h_xrandr then
        local res_xrandr = h_xrandr:read("*l")
        h_xrandr:close()
        if res_xrandr and res_xrandr ~= "" then
            cached_display_info = res_xrandr
            return cached_display_info
        end
    end

    return "N/A"
end

-- ===================================================================
-- Function: Get Scaling Factor (e.g. 100%, 125%, 150%) - Cached
-- ===================================================================
function conky_get_scale_factor()
    -- If scaling factor was calculated previously, return cached value
    if cached_scale_factor then
        return cached_scale_factor
    end

    -- 1. Read X11 Xft.dpi via xrdb (144 DPI = 150%, 120 DPI = 125%, 96 DPI = 100%)
    local cmd_dpi = [[xrdb -query 2>/dev/null | grep -i 'Xft.dpi' | grep -o '[0-9]*']]
    local h = io.popen(cmd_dpi)
    if h then
        local dpi = h:read("*l")
        h:close()
        if dpi and tonumber(dpi) and tonumber(dpi) > 0 then
            local calculated_scale = math.floor((tonumber(dpi) / 96) * 100 + 0.5)
            cached_scale_factor = string.format("%d%%", calculated_scale)
            return cached_scale_factor
        end
    end

    -- 2. Fallback: KScreen scale factor
    local cmd_kscreen = [[timeout 1s kscreen-doctor -j 2>/dev/null | jq -r '.outputs[] | select(.enabled == true) | select(.scale != null) | "\((.scale * 100 | round))%"' 2>/dev/null | head -n1]]
    h = io.popen(cmd_kscreen)
    if h then
        local scale = h:read("*l")
        h:close()
        if scale and scale ~= "" and scale ~= "null%" then
            cached_scale_factor = scale
            return cached_scale_factor
        end
    end

    cached_scale_factor = "100%"
    return cached_scale_factor
end

-- ===================================================================
-- Resolution & Refresh Rate Watcher Starter
-- ===================================================================
function start_resolution_watcher()
    if watcher_started then return end
    watcher_started = true
    
    os.execute("nohup ~/.config/conky/display_watcher.sh >/dev/null 2>&1 &")
end

start_resolution_watcher()
