local io     = require "io"
local string = require "string"
local table  = require "table"
local fs     = require "nixio.fs"

local tonumber, pcall, dofile, _G = tonumber, pcall, dofile, _G

module "luci.version"

if pcall(dofile, "/etc/openwrt_release") and _G.DISTRIB_DESCRIPTION then
	distname    = ""
	distversion = _G.DISTRIB_DESCRIPTION
	if _G.DISTRIB_REVISION then
		distrevision = _G.DISTRIB_REVISION
		if not distversion:find(distrevision,1,true) then
			distversion = distversion .. " " .. distrevision
		end
	end
else
	distname    = "OpenWrt"
	distversion = "Development Snapshot"
end

if pcall(dofile, "/etc/microbt_release") then
	if _G.MINER_NAME then
		minername = _G.MINER_NAME
	else
		minername = "unknown"
	end
	if _G.FIRMWARE_VERSION then
		firmwareversion = _G.FIRMWARE_VERSION
	else
		firmwareversion = "unknown"
	end
else
	minername = "unknown"
	firmwareversion = "unknown"
end

cgminerversion = fs.readfile("/etc/cgminer_version") or "unknown"

-- Detect controll board type

controlboardtype = "CB-unknown"

local host_zynq = "Xilinx Zynq Platform"
local host_h3 = "sun8i"

local t = io.popen('cat /proc/cpuinfo')
local a = t:read("*all")
local h = string.match(a, host_zynq)
local is_h3 = string.match(a, host_h3) == host_h3

if h == host_zynq then
   	local result = {}

	t = io.popen('cat /proc/meminfo')
	a = t:read("*all")
   	for l in string.gmatch(a, "([^ ]+)") do
       	table.insert(result, l)
   	end

	if tonumber(result[2]) <= 262144 then
		controlboardtype = "ZYNQ-CB12"
	else
		controlboardtype = "ZYNQ-CB10"		
	end
end

if is_h3 then
    controlboardtype = "H3-CB20"
end

-- Detect hash board type

modelname = "unknown"
hashboardtype = "HB-unknown"

local sensor_tmp421 = "tmp421"
local sensor_tmp423 = "tmp423"
local sensor_lm75 = "lm75"
local gpio_high = "1"
local gpio_low = "0"

local hwmon0_path = "/sys/class/hwmon/hwmon0/name"
local hwmon1_path = "/sys/class/hwmon/hwmon1/name"
local hwmon2_path = "/sys/class/hwmon/hwmon2/name"
local hwmon4_path = "/sys/class/hwmon/hwmon4/name"

local gpio_hotplug0_path = "/sys/class/gpio/gpio961/value"
local gpio_hotplug1_path = "/sys/class/gpio/gpio963/value"
local gpio_hotplug2_path = "/sys/class/gpio/gpio965/value"

local gpio_en0_path = "/sys/class/gpio/gpio934/value"
local gpio_en1_path = "/sys/class/gpio/gpio939/value"
local gpio_en2_path = "/sys/class/gpio/gpio937/value"

if is_h3 then
   hwmon0_path = "/sys/class/hwmon/hwmon1/device/name"
   hwmon1_path = "/sys/class/hwmon/hwmon2/device/name"
   hwmon2_path = "/sys/class/hwmon/hwmon3/device/name"
   hwmon4_path = "/sys/class/hwmon/hwmon5/device/name"

   gpio_hotplug0_path = "/sys/class/gpio/gpio15/value"
   gpio_hotplug1_path = "/sys/class/gpio/gpio7/value"
   gpio_hotplug2_path = "/sys/class/gpio/gpio8/value"

   gpio_en0_path = "/sys/class/gpio/gpio96/value"
   gpio_en1_path = "/sys/class/gpio/gpio97/value"
   gpio_en2_path = "/sys/class/gpio/gpio98/value"
end

local name0 = fs.readfile(hwmon0_path) or ""
local name1 = fs.readfile(hwmon1_path) or ""
local name2 = fs.readfile(hwmon2_path) or ""

local gpio_hotplug0 = fs.readfile(gpio_hotplug0_path) or ""
local gpio_hotplug1 = fs.readfile(gpio_hotplug1_path) or ""
local gpio_hotplug2 = fs.readfile(gpio_hotplug2_path) or ""

local gpio_en0 = fs.readfile(gpio_en0_path) or ""
local gpio_en1 = fs.readfile(gpio_en1_path) or ""
local gpio_en2 = fs.readfile(gpio_en2_path) or ""

name0 = string.match(name0, sensor_tmp421)
name1 = string.match(name1, sensor_tmp421)
name2 = string.match(name2, sensor_tmp421)

gpio_hotplug0 = string.match(gpio_hotplug0, gpio_low)
gpio_hotplug1 = string.match(gpio_hotplug1, gpio_low)
gpio_hotplug2 = string.match(gpio_hotplug2, gpio_low)

gpio_en0 = string.match(gpio_en0, gpio_high)
gpio_en1 = string.match(gpio_en1, gpio_high)
gpio_en2 = string.match(gpio_en2, gpio_high)

local hash_board_type0
local hash_board_type1
local hash_board_type2

if gpio_hotplug0 == gpio_low and gpio_en0 == gpio_high then
    hash_board_type0 = "1"
else
    hash_board_type0 = "0"
end
if gpio_hotplug1 == gpio_low and gpio_en1 == gpio_high then
    hash_board_type1 = "1"
else
    hash_board_type1 = "0"
end
if gpio_hotplug2 == gpio_low and gpio_en2 == gpio_high then
    hash_board_type2 = "1"
else
    hash_board_type2 = "0"
end

if name0 == sensor_tmp421 or name1 == sensor_tmp421 or name2 == sensor_tmp421 then
   if hash_board_type0 == "1" or hash_board_type1 == "1" or hash_board_type2 == "1" then
        hashboardtype = "HB12"
        modelname = "M1"
   else
        hashboardtype = "HB20"
        modelname = "M1s"
   end
else
	name0 = fs.readfile(hwmon0_path) or ""
	name1 = fs.readfile(hwmon2_path) or ""
	name2 = fs.readfile(hwmon4_path) or ""

	name0 = string.match(name0, sensor_tmp423)
	name1 = string.match(name1, sensor_tmp423)
	name2 = string.match(name2, sensor_tmp423)

	if name0 == sensor_tmp423 or name1 == sensor_tmp423 or name2 == sensor_tmp423 then
		hashboardtype = "HB10"
        modelname = "M1"
    else
        name0 = fs.readfile(hwmon0_path) or ""
        name1 = fs.readfile(hwmon1_path) or ""
        name2 = fs.readfile(hwmon2_path) or ""

        name0 = string.match(name0, sensor_lm75)
        name1 = string.match(name1, sensor_lm75)
        name2 = string.match(name2, sensor_lm75)

	    if name0 == sensor_lm75 or name1 == sensor_lm75 or name2 == sensor_lm75 then
           if hash_board_type0 == "1" or hash_board_type1 == "1" or hash_board_type2 == "1" then
              hashboardtype = "ALB10"
              modelname = "M2"
           else
              hashboardtype = "ALB20"
              modelname = "M3"
           end
	    end
	end
end

minermodel = minername .. " " .. modelname
hardwareversion = modelname .. "." .. hashboardtype .. "." .. controlboardtype

luciname    = "LuCI Master"
luciversion = "git-16.336.70424-1fd43b4"
