-- ===================================================================
-- toolbox.lua - helper functions for conky.conf
--
-- Design rules:
--   * No external process in the per-second path (sysfs/procfs only).
--   * Static values are cached for the lifetime of the Conky process.
--     display_watcher.sh restarts Conky on a display change, which
--     refreshes every cache.
--   * Failed lookups are retried at most every RETRY_SECONDS, so a
--     missing tool or a busy system can never cause a spawn storm.
--   * Functions called from conky.text carry the conky_ prefix.
-- ===================================================================

local RETRY_SECONDS = 30

-- ===================================================================
-- Helpers
-- ===================================================================
local function read_line(path)
    local f = io.open(path, "r")
    if not f then return nil end
    local line = f:read("*l")
    f:close()
    return line
end

local function read_or_na(path)
    local value = read_line(path)
    if value and value ~= "" then return value end
    return "N/A"
end

-- Runs a shell command and returns its full output (or nil).
-- Only used from cached, retry-limited code paths.
local function run_cmd(cmd)
    local h = io.popen(cmd)
    if not h then return nil end
    local out = h:read("*a")
    h:close()
    return out
end

local function first_line(str)
    if not str then return nil end
    return str:match("^[^\r\n]+")
end

-- Parse CPU list ranges (e.g. "0-15,28-31") into a set
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
-- Display scale (one implementation, used for window sizing AND label)
-- Priority: X11 Xft.dpi via xrdb; if that says 96 DPI (or is missing)
-- ask KScreen as well (covers Wayland sessions).
-- ===================================================================
local scale_value = nil
local scale_failed_at = nil

local function detect_scale()
    if scale_value then return scale_value end
    if scale_failed_at and os.time() - scale_failed_at < RETRY_SECONDS then
        return nil
    end

    local value = nil

    local xrdb_out = run_cmd("xrdb -query 2>/dev/null | grep -i 'Xft.dpi'") or ""
    local dpi = tonumber(xrdb_out:match("(%d+)%s*$"))
    if dpi and dpi > 0 then
        value = dpi / 96.0
    end

    if not value or value == 1.0 then
        local kscreen_out = run_cmd(
            "timeout 1s kscreen-doctor -j 2>/dev/null | " ..
            "jq -r '.outputs[] | select(.enabled == true) | select(.scale != null) | .scale' 2>/dev/null | " ..
            "head -n1") or ""
        local kscreen_scale = tonumber(kscreen_out)
        if kscreen_scale and kscreen_scale > 0 then
            value = kscreen_scale
        end
    end

    if value then
        scale_value = value
        scale_failed_at = nil
    else
        scale_failed_at = os.time()
    end
    return value
end

-- Called from conky.conf at parse time (global, no conky_ prefix)
function get_scale(size_factor)
    return (detect_scale() or 1.0) * (size_factor or 0.8)
end

function conky_get_scale_factor()
    local s = detect_scale()
    if not s then return "N/A" end
    return string.format("%d%%", math.floor(s * 100 + 0.5))
end

-- ===================================================================
-- Display info (resolution & refresh rate) - cached
-- ===================================================================
local display_info = nil
local display_failed_at = nil

local KSCREEN_DISPLAY_CMD = [==[timeout 1s kscreen-doctor -j 2>/dev/null | jq -r '.outputs[] | select(.enabled == true) as $out | $out.modes[] | select(.id == $out.currentModeId) | "\(.size.width)x\(.size.height)@\( ((.refreshRate - (.refreshRate | round)) | if . < 0 then -. else . end) as $diff | if $diff < 0.01 then (.refreshRate | round) else ((.refreshRate * 100 | round) / 100) end)Hz"' 2>/dev/null | head -n1]==]

local XRANDR_DISPLAY_CMD = [==[xrandr --current 2>/dev/null | awk '/\*/ {print $1 "@" int($2) "Hz"; exit}']==]

function conky_get_display_info()
    if display_info then return display_info end
    if display_failed_at and os.time() - display_failed_at < RETRY_SECONDS then
        return "N/A"
    end

    local res = first_line(run_cmd(KSCREEN_DISPLAY_CMD))
    if not res or res == "null" then
        res = first_line(run_cmd(XRANDR_DISPLAY_CMD))
    end

    if res and res ~= "" and res ~= "null" then
        display_info = res
        return display_info
    end

    display_failed_at = os.time()
    return "N/A"
end

-- ===================================================================
-- CPU model name (static -> cached)
-- ===================================================================
local cpu_name_cache = nil

function conky_get_cpu_name()
    if cpu_name_cache then return cpu_name_cache end

    local model_name = nil
    local f = io.open("/proc/cpuinfo", "r")
    if f then
        for line in f:lines() do
            model_name = line:match("^model name%s*:%s*(.+)")
            if model_name then break end
        end
        f:close()
    end

    if model_name then
        -- Strip redundant branding for a clean layout
        model_name = model_name:gsub("%(R%)", "")
        model_name = model_name:gsub("%(TM%)", "")
        model_name = model_name:gsub("%d+th Gen ", "")
        model_name = model_name:gsub("Processor", "")
        model_name = model_name:gsub("CPU", "")
        model_name = model_name:gsub("%s+", " ")
        model_name = model_name:match("^%s*(.-)%s*$")
    end

    cpu_name_cache = (model_name and model_name ~= "") and model_name or "N/A"
    return cpu_name_cache
end

-- ===================================================================
-- CPU core & thread count (Intel hybrid P/E support) - cached
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

    -- PMU & sysfs candidate paths for P-core and E-core CPU lists
    local p_str = read_line("/sys/bus/event_source/devices/cpu_core/cpus")
               or read_line("/sys/devices/cpu_core/cpus")
               or read_line("/sys/devices/system/cpu/types/core/cpus")

    local e_str = read_line("/sys/bus/event_source/devices/cpu_atom/cpus")
               or read_line("/sys/devices/cpu_atom/cpus")
               or read_line("/sys/devices/system/cpu/types/atom/cpus")

    if p_str or e_str then
        local function count_physical(cpu_set)
            local map = {}
            for cpu_id in pairs(cpu_set) do
                local base = "/sys/devices/system/cpu/cpu" .. cpu_id .. "/topology/"
                local cid = read_line(base .. "core_id")
                local pid = read_line(base .. "physical_package_id") or "0"
                if cid then map[pid .. ":" .. cid] = true end
            end
            local n = 0
            for _ in pairs(map) do n = n + 1 end
            return n
        end

        local p_count = count_physical(parse_cpus_range(p_str))
        local e_count = count_physical(parse_cpus_range(e_str))

        if p_count > 0 or e_count > 0 then
            cached_cpu_cores_info = string.format("%d Cores (%dP + %dE) / %d Threads", phys_cores, p_count, e_count, threads)
            return cached_cpu_cores_info
        end
    end

    cached_cpu_cores_info = string.format("%d Cores / %d Threads", phys_cores, threads)
    return cached_cpu_cores_info
end

-- ===================================================================
-- CPU scaling driver, governor and EPP (all live, one tiny sysfs read each).
-- The driver is NOT cached: it can change at runtime, e.g. intel_pstate
-- switching between active and passive mode changes the reported name.
-- ===================================================================
local CPUFREQ_DIR = "/sys/devices/system/cpu/cpu0/cpufreq/"

function conky_get_cpu_driver()
    return read_or_na(CPUFREQ_DIR .. "scaling_driver")
end

function conky_get_cpu_governor()
    return read_or_na(CPUFREQ_DIR .. "scaling_governor")
end

function conky_get_cpu_epp()
    return read_or_na(CPUFREQ_DIR .. "energy_performance_preference")
end

-- ===================================================================
-- CPU temperature (pure sysfs). The hwmon file is located ONCE.
-- Prefers labelled package sensors, falls back to temp1_input.
-- ===================================================================
local CPU_HWMON_NAMES = { coretemp = true, k10temp = true, zenpower = true, cpu_thermal = true }
local TEMP_LABEL_RANK = { ["Package id 0"] = 1, ["Tdie"] = 2, ["Tctl"] = 3, ["CPU Package"] = 4 }

local hwmon_temp_file = nil
local hwmon_failed_at = nil

local function find_cpu_temp_file()
    local best_file, best_rank = nil, 99
    for i = 0, 63 do
        local dir = "/sys/class/hwmon/hwmon" .. i
        local name = read_line(dir .. "/name")
        if name and CPU_HWMON_NAMES[name] then
            if not best_file then
                best_file, best_rank = dir .. "/temp1_input", 50
            end
            for j = 1, 10 do
                local label = read_line(dir .. "/temp" .. j .. "_label")
                local rank = label and TEMP_LABEL_RANK[label]
                if rank and rank < best_rank then
                    best_file, best_rank = dir .. "/temp" .. j .. "_input", rank
                end
            end
        end
    end
    return best_file
end

function conky_get_cpu_temp()
    if not hwmon_temp_file then
        if hwmon_failed_at and os.time() - hwmon_failed_at < RETRY_SECONDS then
            return "N/A"
        end
        hwmon_temp_file = find_cpu_temp_file()
        if not hwmon_temp_file then
            hwmon_failed_at = os.time()
            return "N/A"
        end
    end

    local temp = tonumber(read_line(hwmon_temp_file))
    if not temp then
        -- Sensor vanished or unreadable: forget it and retry later
        hwmon_temp_file = nil
        hwmon_failed_at = os.time()
        return "N/A"
    end
    return string.format("%d°C", math.floor((temp / 1000) + 0.5))
end

-- ===================================================================
-- CPU max frequency across all cores
-- The list of readable scaling_cur_freq files is built ONCE.
-- ===================================================================
local freq_paths = nil

local function build_freq_paths()
    local cpus = parse_cpus_range(read_line("/sys/devices/system/cpu/present"))
    if next(cpus) == nil then
        for i = 0, 127 do cpus[i] = true end
    end

    local ids = {}
    for id in pairs(cpus) do ids[#ids + 1] = id end
    table.sort(ids)

    local paths = {}
    for _, id in ipairs(ids) do
        local p = string.format("/sys/devices/system/cpu/cpu%d/cpufreq/scaling_cur_freq", id)
        local f = io.open(p, "r")
        if f then
            f:close()
            paths[#paths + 1] = p
        end
    end
    return paths
end

function conky_get_cpu_freq_max()
    if not freq_paths then freq_paths = build_freq_paths() end

    local max_khz = 0
    for _, p in ipairs(freq_paths) do
        local val = tonumber(read_line(p))   -- an offline CPU simply yields nil
        if val and val > max_khz then max_khz = val end
    end

    if max_khz > 0 then
        return string.format("%.2f GHz", max_khz / 1000000)
    end
    return "N/A"
end

-- ===================================================================
-- CPU package power (intel-rapl)
-- Note: recent kernels make energy_uj root-only; this returns "N/A"
-- when the file is not readable for the Conky user.
-- ===================================================================
local RAPL_DIR = "/sys/class/powercap/intel-rapl/intel-rapl:0/"
local last_energy, last_time = nil, nil
local rapl_max_range = nil

function conky_get_cpu_power()
    local energy = tonumber(read_line(RAPL_DIR .. "energy_uj"))
    if not energy then return "N/A" end

    -- /proc/uptime has a resolution of 0.01 s
    local uptime = read_line("/proc/uptime")
    local now = (uptime and tonumber(uptime:match("^(%S+)"))) or os.time()

    local result = "N/A"
    if last_energy and last_time then
        local de = energy - last_energy
        local dt = now - last_time

        -- The counter wraps around at max_energy_range_uj
        if de < 0 then
            rapl_max_range = rapl_max_range or tonumber(read_line(RAPL_DIR .. "max_energy_range_uj"))
            if rapl_max_range then de = de + rapl_max_range end
        end

        if dt > 0 and de >= 0 then
            result = string.format("%.2f W", (de / dt) / 1000000)
        end
    end

    last_energy, last_time = energy, now
    return result
end

-- ===================================================================
-- Network: ALL active physical interfaces, lowest route metric first.
--
-- "Active" = not virtual (lo, bridges, docker, veth, virbr, vnet, tap,
-- tun, wg, tailscale) and either operstate "up" or owning an IPv4 default
-- route. Interfaces with a default route come first, sorted by metric
-- (lowest = highest priority); interfaces without one follow in kernel
-- order. conky.text shows up to MAX_NET_IFACES "slots"; each slot asks
-- for its interface by number via net_label/net_down/net_up/..._percent.
-- The list (and each link speed) is refreshed every 10 s.
-- IPv6-only default routes are not considered.
-- ===================================================================
local MAX_NET_IFACES = 4
local DEFAULT_LINK_MBIT = 1000
local NET_REFRESH_SECONDS = 10

local VIRTUAL_IFACE_PATTERNS = {
    "^lo$", "^br%-", "^docker", "^veth", "^virbr", "^vnet",
    "^tap", "^tun", "^wg", "^tailscale",
}

local function is_virtual_iface(name)
    for _, pattern in ipairs(VIRTUAL_IFACE_PATTERNS) do
        if name:match(pattern) then return true end
    end
    return false
end

-- iface -> lowest metric of its IPv4 default routes
local function read_default_route_metrics()
    local metrics = {}
    local f = io.open("/proc/net/route", "r")
    if not f then return metrics end

    local header = true
    for line in f:lines() do
        if header then
            header = false
        else
            local iface, dest, flags, metric =
                line:match("^(%S+)%s+(%x+)%s+%x+%s+(%x+)%s+%d+%s+%d+%s+(%d+)")
            if iface and dest == "00000000"
               and tonumber(flags, 16) % 2 == 1          -- RTF_UP
               and not is_virtual_iface(iface) then
                metric = tonumber(metric)
                if not metrics[iface] or metric < metrics[iface] then
                    metrics[iface] = metric
                end
            end
        end
    end
    f:close()
    return metrics
end

local function discover_interfaces()
    local metrics = read_default_route_metrics()
    local found = {}

    local f = io.open("/proc/net/dev", "r")
    if f then
        local order = 0
        for line in f:lines() do
            local iface = line:match("^%s*([%w%-%._]+):")
            if iface and not is_virtual_iface(iface) then
                local is_up = read_line("/sys/class/net/" .. iface .. "/operstate") == "up"
                if is_up or metrics[iface] then
                    order = order + 1
                    -- Wi-Fi (and some virtual NICs) report no usable speed
                    local mbit = tonumber(read_line("/sys/class/net/" .. iface .. "/speed") or "")
                    local known = (mbit ~= nil and mbit > 0)
                    found[#found + 1] = {
                        name = iface,
                        metric = metrics[iface],
                        order = order,
                        mbit = known and mbit or DEFAULT_LINK_MBIT,
                        speed_known = known,
                    }
                end
            end
        end
        f:close()
    end

    table.sort(found, function(a, b)
        if a.metric and b.metric then
            if a.metric ~= b.metric then return a.metric < b.metric end
            return a.order < b.order
        end
        if a.metric then return true end
        if b.metric then return false end
        return a.order < b.order
    end)

    while #found > MAX_NET_IFACES do table.remove(found) end
    return found
end

local net_ifaces = {}
local net_checked_at = nil

local function get_net_interfaces()
    local now = os.time()
    local ttl = (#net_ifaces == 0) and 2 or NET_REFRESH_SECONDS
    if net_checked_at and now - net_checked_at < ttl then
        return net_ifaces
    end
    net_ifaces = discover_interfaces()
    net_checked_at = now
    return net_ifaces
end

-- `arg` is the slot number passed from conky.text, e.g. ${lua net_label 2}
local function slot_nic(arg)
    local index = tonumber(arg)
    if not index then return nil end
    return get_net_interfaces()[index]
end

local function format_link_speed(mbit, known)
    local text
    if mbit >= 1000 then
        -- 1000 -> "1 Gbit/s", 2500 -> "2.5 Gbit/s", 10000 -> "10 Gbit/s"
        local gbit = string.format("%.1f", mbit / 1000):gsub("%.0$", "")
        text = gbit .. " Gbit/s"
    else
        text = string.format("%d Mbit/s", math.floor(mbit))   -- e.g. "100 Mbit/s"
    end
    -- A trailing "*" marks an assumed speed (the kernel did not report one)
    return known and text or (text .. "*")
end

-- Label for a slot; empty string = slot unused (conky.text hides it).
-- Slot 1 is always visible so the widget never shows nothing at all.
function conky_net_label(arg)
    local nic = slot_nic(arg)
    if not nic then
        if tonumber(arg) == 1 then return "no active interface" end
        return ""
    end
    local label = nic.name .. " (" .. format_link_speed(nic.mbit, nic.speed_known)
    if nic.metric then label = label .. ", metric " .. nic.metric end
    return label .. ")"
end

function conky_net_down(arg)
    local nic = slot_nic(arg)
    if not nic then return "N/A" end
    return conky_parse('${downspeed ' .. nic.name .. '}') .. '/s'
end

function conky_net_up(arg)
    local nic = slot_nic(arg)
    if not nic then return "N/A" end
    return conky_parse('${upspeed ' .. nic.name .. '}') .. '/s'
end

-- ${downspeedf}/${upspeedf} report KiB/s; the bar maximum is the link speed
local function speed_percent(arg, conky_var)
    local nic = slot_nic(arg)
    if not nic then return 0 end
    local speed = tonumber(conky_parse('${' .. conky_var .. ' ' .. nic.name .. '}')) or 0
    local max_kib = nic.mbit * 1000000 / 8 / 1024
    return math.min((speed / max_kib) * 100, 100)
end

function conky_down_percent(arg) return speed_percent(arg, "downspeedf") end
function conky_up_percent(arg)   return speed_percent(arg, "upspeedf")   end

-- ===================================================================
-- TOP MEMORY value, right-justified to a fixed width.
-- ${top_mem mem_res N} changes length with the value ("6.06MiB", "512MiB",
-- "1.23GiB"). Because name and value sit in ONE right-aligned segment, a
-- longer value pushes the process name to the left. Padding the value to
-- a constant width keeps all five names in the same column.
-- ===================================================================
function conky_top_mem_value(arg)
    local value = conky_parse('${top_mem mem_res ' .. tostring(arg) .. '}')
    value = value:match("^%s*(.-)%s*$") or ""
    return string.format("%7s", value)
end

-- ===================================================================
-- Startup hook: launch the display watcher (it has its own pidfile
-- guard, so repeated calls are harmless)
-- ===================================================================
function conky_start_watcher()
    os.execute("nohup ~/.config/conky/display_watcher.sh >/dev/null 2>&1 &")
    return ""
end
