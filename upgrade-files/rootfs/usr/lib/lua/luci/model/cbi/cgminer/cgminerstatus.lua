--[[
LuCI - Lua Configuration Interface

Copyright 2016-2017 CaiQinghua <caiqinghua@gmail.com>
Copyright 2008 Steven Barth <steven@midlink.org>
Copyright 2008 Jo-Philipp Wich <xm@leipzig.freifunk.net>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

$Id$
]]--
btnref = luci.dispatcher.build_url("admin", "status", "cgminerstatus", "restart")
f = SimpleForm("cgminerstatus", translate("CGMiner Status") ..
		    "  <input type=\"button\" class=\"btn btn-danger\"value=\" " .. translate("Restart CGMiner") .. " \" onclick=\"location.href='" .. btnref .. "'\" href=\"#\"/>",
		    translate("Please visit <a href='https://microbt.com/support'> https://microbt.com/support</a> for support."))

f.reset = false
f.submit = false

t = f:section(Table, luci.controller.cgminer.summary(), translate("Summary"))
t:option(DummyValue, "elapsed", translate("Elapsed"))
ghsav = t:option(DummyValue, "mhsav", translate("GHSav"))
function ghsav.cfgvalue(self, section)
	local v = Value.cfgvalue(self, section):gsub(",","")
	return string.format("%.2f", tonumber(v)/1000)
end

t:option(DummyValue, "accepted", translate("Accepted"))
t:option(DummyValue, "rejected", translate("Rejected"))
t:option(DummyValue, "networkblocks", translate("NetworkBlocks"))
t:option(DummyValue, "bestshare", translate("BestShare"))
t:option(DummyValue, "fanspeedin", translate("FanSpeedIn"))
t:option(DummyValue, "fanspeedout", translate("FanSpeedOut"))

t1 = f:section(Table, luci.controller.cgminer.pools(), translate("Pools"))
t1:option(DummyValue, "pool", translate("Pool"))
t1:option(DummyValue, "url", translate("URL"))
t1:option(DummyValue, "stratumactive", translate("Active"))
t1:option(DummyValue, "user", translate("User"))
t1:option(DummyValue, "status", translate("Status"))
t1:option(DummyValue, "stratumdifficulty", translate("Difficulty"))
t1:option(DummyValue, "getworks", translate("GetWorks"))
t1:option(DummyValue, "accepted", translate("Accepted"))
t1:option(DummyValue, "rejected", translate("Rejected"))
t1:option(DummyValue, "stale", translate("Stale"))
t1:option(DummyValue, "lastsharetime", translate("LST"))
t1:option(DummyValue, "lastsharedifficulty", translate("LSD"))

t2 = f:section(Table, luci.controller.cgminer.devs(), translate("Devices"))
t2:option(DummyValue, "name", translate("Device"))
t2:option(DummyValue, "enable", translate("Enabled"))
t2:option(DummyValue, "status", translate("Status"))
ghsav = t2:option(DummyValue, "mhsav", translate("GHSav"))
function ghsav.cfgvalue(self, section)
	local v = Value.cfgvalue(self, section)
	return string.format("%.2f", v/1000)
end

ghs5s = t2:option(DummyValue, "mhs5s", translate("GHS5s"))
function ghs5s.cfgvalue(self, section)
	local v = Value.cfgvalue(self, section)
	return string.format("%.2f", v/1000)
end

ghs1m = t2:option(DummyValue, "mhs1m", translate("GHS1m"))
function ghs1m.cfgvalue(self, section)
	local v = Value.cfgvalue(self, section)
	return string.format("%.2f", v/1000)
end

ghs5m = t2:option(DummyValue, "mhs5m", translate("GHS5m"))
function ghs5m.cfgvalue(self, section)
	local v = Value.cfgvalue(self, section)
	return string.format("%.2f", v/1000)
end

ghs15m = t2:option(DummyValue, "mhs15m", translate("GHS15m"))
function ghs15m.cfgvalue(self, section)
	local v = Value.cfgvalue(self, section)
	return string.format("%.2f", v/1000)
end

t2:option(DummyValue, "lvw", translate("LastValidWork"))

t3 = f:section(Table, luci.controller.cgminer.stats(), translate(""))
t3:option(DummyValue, "id", translate("Device"))
t3:option(DummyValue, "freqs_avg", translate("Frequency(avg)"))
t3:option(DummyValue, "effective_chips", translate("EffectiveChips"))

temp1=t3:option(DummyValue, "temp_1", translate("Temperature1"))
function temp1.cfgvalue(self, section)
	local v = Value.cfgvalue(self, section)
	return string.format("%.2f", v)
end

temp2=t3:option(DummyValue, "temp_2", translate("Temperature2"))
function temp2.cfgvalue(self, section)
	local v = Value.cfgvalue(self, section)
	return string.format("%.2f", v)
end

t4 = f:section(Table, luci.controller.cgminer.events(), translate("Events"))
t4:option(DummyValue, "id", translate("EventCode"))
t4:option(DummyValue, "cause", translate("EventCause"))
t4:option(DummyValue, "action", translate("EventAction"))
t4:option(DummyValue, "times", translate("TotalTimes"))
t4:option(DummyValue, "lasttime", translate("LastTime"))
t4:option(DummyValue, "source", translate("EventSource"))

return f
