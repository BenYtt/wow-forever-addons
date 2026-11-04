local _, ns = ...

-- Bounded guild and group peer statistics for the Forever addons. ns.PeerStats.New(config) returns one instance per
-- addon: it sends that addon's own snapshot rows, stores validated rows from peers, and ranks a board. Nothing here
-- knows a metric, a label or a screen; the consumer names its metrics in `config` and draws its own UI.
--
-- config = {
--   addon    = "agf",                      -- wire addon id, 1-16 of [%w_-]
--   enabled  = function() return bool end, -- the saved setting; missing or false means off
--   db       = function() return table end, -- peer table owned by the caller; no table means off
--   snapshot = function() return { { metric=, subject=, value=, eventUnix= }, ... } end,
--   metrics  = { name = { subject = "all" | "numeric" | "qualified", first = bool } },
-- }
-- Subject modes also include "numeric_or_all" and "numeric_pair" (encounter_difficulty).
-- PeerStats.Listen(owner, config) observes config.addon's rows without taking over that addon's sender. Its
-- registration is private to owner, and it never sends a snapshot, even if one was supplied.
--
-- Saved layout: db[sender][metric][subject] = { value = n, eventUnix = n }.
-- Wire v1 on prefix WFAStats: "1|addon|metric|subject|value|unix", GUILD and the group channel only, and received
-- rows are never re-sent. A foreign addon's rows are ignored, so no suite-wide metric list exists.
--
-- Every vendored copy shares one manager, the global ForeverPeerStats, which owns the send queue, the transport rate,
-- the channel epochs and the game events. The first loaded copy creates it, later copies adopt it, and a copy with a
-- newer MANAGER_VERSION takes it over together with the registered instances.

local PREFIX = "WFAStats"
local WIRE_VERSION = "1"
local MANAGER_VERSION = 3

local MAX_PAYLOAD = 128
local MAX_METRIC = 32
local MAX_SUBJECT = 24
local MAX_ADDON = 16
local MAX_NAME = 64
local MAX_VALUE = 1e9
local FUTURE_SECONDS = 300
local MAX_METRICS = 64
local MAX_PEERS = 100
local MAX_SUBJECTS = 256
local MAX_ROWS = 1024
local MAX_QUEUE = 512
local MAX_SNAPSHOT = 2048
local MAX_SCAN_KEYS = 2000
local MAX_SCAN_SUBJECTS = 4096
local MAX_RATE_SENDERS = 200
local STALE_PEER_SECONDS = 30 * 86400
-- Per sender, per instance: room for a whole Field Guide snapshot, then ten rows a second.
local RECEIVE_BURST = 300
local RECEIVE_PER_SECOND = 10
-- Shared transport: a short burst, then two messages a second.
local SEND_BURST = 10
local SEND_PER_SECOND = 2
local MAX_RETRIES = 5
local MAX_BACKOFF = 30
local MEMBERSHIP_DELAY = 1

local SUBJECT_MODES = { all = true, numeric = true, qualified = true, numeric_or_all = true, numeric_pair = true }
local ALLOWED_CHANNELS = { GUILD = true, PARTY = true, RAID = true, INSTANCE_CHAT = true }
local EVENTS = { "CHAT_MSG_ADDON", "GROUP_ROSTER_UPDATE", "PLAYER_GUILD_UPDATE", "PLAYER_ENTERING_WORLD" }
local MEMBERSHIP_EVENTS = { GROUP_ROSTER_UPDATE = true, PLAYER_GUILD_UPDATE = true, PLAYER_ENTERING_WORLD = true }
local CHANNEL_ORDER = { "GUILD", "PARTY", "RAID", "INSTANCE_CHAT" }

---@param value any
---@param low number
---@param high number
---@return number|nil
local function IntIn(value, low, high)
	if type(value) ~= "number" or value ~= value or value < low or value > high or value ~= math.floor(value) then
		return nil
	end
	return value
end

---@param text any
---@return integer|nil
local function ParseInt(text, low, high)
	if type(text) ~= "string" or #text > 10 or not text:find("^%d+$") then
		return nil
	end
	return IntIn(tonumber(text), low, high)
end

local function Now()
	return GetServerTime and GetServerTime() or 0
end

local function Compact(text)
	return (text:gsub("[%s%-]", ""))
end

local function LocalRealm()
	local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName())
	if type(realm) == "string" and realm ~= "" then
		return Compact(realm):lower()
	end
end

local function OwnName()
	local name = UnitName and UnitName("player")
	if type(name) == "string" and name ~= "" then
		return name
	end
end

local function Readable(name, realm)
	local canAccess = rawget(_G, "canaccessvalue")
	if canAccess and (not canAccess(name) or not canAccess(realm)) then
		return nil
	end
	return name, realm
end

-- The saved key and the lowercase identity for a sender. Spaces and hyphens leave the realm, and the local realm
-- leaves the name, so "Name", "Name-MyRealm" and "name-My Realm" are one player.
---@param sender any
---@return string|nil key
---@return string|nil identity
local function Identity(sender)
	if type(sender) ~= "string" or sender == "" or #sender > MAX_NAME or sender:find("[%c|]") then
		return nil
	end
	local name, realm = sender:match("^([^%-]+)%-(.+)$")
	name = Compact(name or sender)
	realm = realm and Compact(realm)
	if name == "" then
		return nil
	end
	if realm == "" or (realm and realm:lower() == LocalRealm()) then
		realm = nil
	end
	local key = realm and (name .. "-" .. realm) or name
	return key, key:lower()
end

---@param mode string
---@param subject any
local function ValidSubject(mode, subject)
	if type(subject) ~= "string" or subject == "" or #subject > MAX_SUBJECT then
		return false
	end
	if mode == "all" then
		return subject == "all"
	elseif mode == "numeric" then
		return subject:find("^%d+$") ~= nil and (subject == "0" or subject:sub(1, 1) ~= "0")
	elseif mode == "numeric_or_all" then
		return subject == "all" or ValidSubject("numeric", subject)
	elseif mode == "numeric_pair" then
		local first, second = subject:match("^([1-9]%d*)_(%d+)$")
		return first ~= nil and (second == "0" or second:sub(1, 1) ~= "0")
	elseif mode == "qualified" then
		return subject:find("^[%a_][%w_]*:[%w_%.%-]+$") ~= nil
	end
	return false
end

-- A first metric keeps the earliest event; any other keeps the highest cumulative value.
local function Better(first, old, value, unix)
	if not old then
		return true
	end
	if first then
		return unix < old.eventUnix or (unix == old.eventUnix and value > old.value)
	end
	return value > old.value or (value == old.value and unix > old.eventUnix)
end

local function SortedStringKeys(source, limit)
	local keys = {}
	for key in pairs(source) do
		if type(key) == "string" then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys)
	for index = #keys, limit + 1, -1 do
		keys[index] = nil
	end
	return keys
end

local function SendResultCodes()
	local codes = Enum and Enum.SendAddonMessageResult
	return (codes and codes.Success) or 0,
		{ [(codes and codes.AddonMessageThrottle) or 3] = true, [(codes and codes.ChannelThrottle) or 8] = true }
end

--------------------------------------------------------------------------------------------------------------------
-- Manager

local function CreateManager()
	local m = { version = MANAGER_VERSION, order = {}, instances = {}, epoch = {} }
	local queue, queueIndex = {}, {}
	local timerPending, timerToken, syncPending = false, 0, false
	local available, groupSize, roster = {}, 0, ""
	local tokens, tokenTime, blockedUntil = SEND_BURST, nil, 0
	local Pump

	local function Remove(position)
		local entry = table.remove(queue, position)
		queueIndex[entry.qk] = nil
	end

	function m.Schedule(delay)
		if timerPending or m.retired or not (C_Timer and C_Timer.After) then
			return
		end
		timerPending, timerToken = true, timerToken + 1
		local token = timerToken
		C_Timer.After(delay, function()
			if token == timerToken and not m.retired then
				Pump()
			end
		end)
	end

	-- The channels this client can send on now, in a fixed order, and the same as a set. An epoch rises each time a
	-- channel appears or its membership changes, so a row already sent there reaches the new audience.
	---@return string[] list
	---@return table<string, boolean> set
	function m.Channels()
		local now = {}
		if IsInGuild and IsInGuild() then
			now.GUILD = true
		end
		local instanceCategory = rawget(_G, "LE_PARTY_CATEGORY_INSTANCE")
		local category = rawget(_G, "LE_PARTY_CATEGORY_HOME")
		if instanceCategory and IsInGroup and IsInGroup(instanceCategory) then
			now.INSTANCE_CHAT = true
			category = instanceCategory
		elseif IsInRaid and IsInRaid() then
			now.RAID = true
		elseif IsInGroup and IsInGroup() then
			now.PARTY = true
		end
		local size = _G.GetNumGroupMembers and tonumber(_G.GetNumGroupMembers(category)) or 0
		local members = {}
		local raid = IsInRaid and IsInRaid(category)
		for index = 1, math.min(size, 40) do
			local unit = raid and ("raid" .. index) or (index == size and "player" or "party" .. index)
			local name, realm = Readable(UnitName(unit))
			members[#members + 1] = name and (name .. "-" .. (realm or "")) or unit
		end
		table.sort(members)
		local signature = table.concat(members, "|")
		local list = {}
		for _, channel in ipairs(CHANNEL_ORDER) do
			if now[channel] then
				list[#list + 1] = channel
				local changed = channel ~= "GUILD" and (size ~= groupSize or signature ~= roster)
				if not available[channel] or changed then
					m.epoch[channel] = (m.epoch[channel] or 0) + 1
				end
			end
		end
		available, groupSize, roster = now, size, signature
		return list, now
	end

	-- Queue one payload, coalescing on the (addon, channel, row) key. False when the queue is full; the row is not
	-- recorded as sent, so the next Sync offers it again.
	function m.Enqueue(inst, channel, key, payload, value, unix)
		local qk = inst.addon .. "|" .. channel .. "|" .. key
		local entry = queueIndex[qk]
		if not entry then
			if #queue >= MAX_QUEUE then
				return false
			end
			entry = { qk = qk, inst = inst, channel = channel, key = key }
			queue[#queue + 1] = entry
			queueIndex[qk] = entry
		end
		entry.payload, entry.value, entry.unix = payload, value, unix
		entry.gen, entry.epoch, entry.retries = inst.gen, m.epoch[channel] or 0, 0
		m.Schedule(0)
		return true
	end

	-- Drop every queued entry of one instance.
	function m.Purge(inst)
		local kept = {}
		for _, entry in ipairs(queue) do
			if entry.inst == inst then
				queueIndex[entry.qk] = nil
			else
				kept[#kept + 1] = entry
			end
		end
		for index = #queue, 1, -1 do
			queue[index] = nil
		end
		for index, entry in ipairs(kept) do
			queue[index] = entry
		end
	end

	function m.QueueSize()
		return #queue
	end

	function m.Register(inst)
		local key = inst.key or inst.addon
		local old = m.instances[key]
		if old == inst then
			return
		end
		if old then
			old:Retire()
		else
			m.order[#m.order + 1] = key
		end
		m.instances[key] = inst
	end

	function m.SyncAll()
		for _, addon in ipairs({ unpack(m.order) }) do
			local inst = m.instances[addon]
			if inst then
				pcall(inst.Sync, inst)
			end
		end
	end

	function Pump()
		timerPending = false
		if m.retired then
			return
		end
		local now = GetTime()
		tokens = math.min(SEND_BURST, tokens + (now - (tokenTime or now)) * SEND_PER_SECOND)
		tokenTime = now
		local _, open = m.Channels()
		for _, addon in ipairs({ unpack(m.order) }) do
			local inst = m.instances[addon]
			if inst then
				inst:IsEnabled()
			end
		end
		local success, throttles = SendResultCodes()
		local send = C_ChatInfo and C_ChatInfo.SendAddonMessage
		local delay
		local position = 1
		while position <= #queue do
			local entry = queue[position]
			local inst = entry.inst
			if inst.dead or entry.gen ~= inst.gen or not inst.active or not open[entry.channel] or not send then
				Remove(position)
			elseif now < blockedUntil then
				delay = blockedUntil - now
				break
			elseif tokens < 1 then
				delay = (1 - tokens) / SEND_PER_SECOND
				break
			else
				local ok, result = pcall(send, PREFIX, entry.payload, entry.channel)
				if ok and (result == true or result == success) then
					tokens = tokens - 1
					inst:RecordSent(entry)
					Remove(position)
				elseif ok and throttles[result] then
					entry.retries = entry.retries + 1
					if entry.retries > MAX_RETRIES then
						Remove(position)
					else
						blockedUntil = now + math.min(MAX_BACKOFF, 2 ^ entry.retries)
						delay = blockedUntil - now
						break
					end
				else
					Remove(position)
				end
			end
		end
		-- Only rows refused for capacity are retried automatically. Transport failures remain eligible for the next
		-- consumer Sync, but cannot keep an overflow refill alive forever.
		if #queue == 0 then
			for _, addon in ipairs(m.order) do
				local inst = m.instances[addon]
				if inst and next(inst.deferred) then
					pcall(inst.Sync, inst, inst.deferred)
				end
			end
		end
		if #queue > 0 and delay then
			m.Schedule(delay)
		end
	end
	m.Pump = Pump

	function m.OnEvent(event, ...)
		if event == "CHAT_MSG_ADDON" then
			local prefix, text, channel, sender = ...
			if prefix ~= PREFIX then
				return
			end
			for _, addon in ipairs({ unpack(m.order) }) do
				local inst = m.instances[addon]
				if inst then
					inst:Receive(prefix, text, channel, sender)
				end
			end
		elseif MEMBERSHIP_EVENTS[event] then
			if not (C_Timer and C_Timer.After) then
				m.SyncAll()
			elseif not syncPending then
				syncPending = true
				C_Timer.After(MEMBERSHIP_DELAY, function()
					syncPending = false
					if not m.retired then
						m.SyncAll()
					end
				end)
			end
		end
	end

	-- Hand the game events to a newer manager.
	function m.Retire()
		m.retired = true
		if m.frame and m.frame.UnregisterAllEvents then
			m.frame:UnregisterAllEvents()
		end
	end

	if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then
		pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
	end
	if CreateFrame then
		local frame = CreateFrame("Frame")
		frame:SetScript("OnEvent", function(_, event, ...)
			m.OnEvent(event, ...)
		end)
		for _, event in ipairs(EVENTS) do
			frame:RegisterEvent(event)
		end
		m.frame = frame
	end
	return m
end

local manager = _G.ForeverPeerStats
if type(manager) ~= "table" or type(manager.version) ~= "number" or type(manager.Register) ~= "function" then
	manager = CreateManager()
	_G.ForeverPeerStats = manager
elseif manager.version < MANAGER_VERSION then
	local old = manager
	manager = CreateManager()
	old.Retire()
	for _, addon in ipairs(old.order) do
		local inst = old.instances[addon]
		if inst then
			inst:Cancel()
			manager.Register(inst)
		end
	end
	_G.ForeverPeerStats = manager
end

-- The manager now published, which a newer copy may have replaced since this file ran.
local function Manager()
	local current = _G.ForeverPeerStats
	if type(current) == "table" and type(current.Enqueue) == "function" then
		return current
	end
end

--------------------------------------------------------------------------------------------------------------------
-- Saved state

-- Rebuild `raw` in place as the canonical layout: unknown metrics, bad subjects and values, own name and duplicate
-- identities removed, rows and peers capped. The result depends only on the content, never on iteration order.
---@param self ForeverPeerStatsInstance
local function SanitizeStore(self, raw)
	local now = Now()
	local own = OwnName()
	own = own and own:lower()
	local merged, order = {}, {}
	for _, key in ipairs(SortedStringKeys(raw, MAX_SCAN_KEYS)) do
		local clean, identity = Identity(key)
		local peerRaw = raw[key]
		if clean and identity and identity ~= own and type(peerRaw) == "table" then
			local peer = merged[identity]
			if not peer then
				peer = { key = clean, identity = identity, rows = {} }
				merged[identity], order[#order + 1] = peer, identity
			end
			for _, metric in ipairs(self.metricList) do
				local subjects = peerRaw[metric]
				if type(subjects) == "table" then
					local config = self.metrics[metric]
					for _, subject in ipairs(SortedStringKeys(subjects, MAX_SCAN_SUBJECTS)) do
						local record = subjects[subject]
						if ValidSubject(config.subject, subject) and type(record) == "table" then
							local value = IntIn(record.value, 0, MAX_VALUE)
							local unix = IntIn(record.eventUnix, 1, now + FUTURE_SECONDS)
							local slot = metric .. "|" .. subject
							if value and unix and Better(config.first, peer.rows[slot], value, unix) then
								peer.rows[slot] =
									{ metric = metric, subject = subject, value = value, eventUnix = unix }
							end
						end
					end
				end
			end
		end
	end

	local peers = {}
	for _, identity in ipairs(order) do
		local peer = merged[identity]
		local list = {}
		for _, row in pairs(peer.rows) do
			list[#list + 1] = row
		end
		table.sort(list, function(a, b)
			if a.eventUnix ~= b.eventUnix then
				return a.eventUnix > b.eventUnix
			end
			if a.metric ~= b.metric then
				return a.metric < b.metric
			end
			return a.subject < b.subject
		end)
		local kept, perMetric = {}, {}
		for _, row in ipairs(list) do
			if #kept < MAX_ROWS and (perMetric[row.metric] or 0) < MAX_SUBJECTS then
				kept[#kept + 1] = row
				perMetric[row.metric] = (perMetric[row.metric] or 0) + 1
			end
		end
		if #kept > 0 then
			peer.list, peer.latest = kept, kept[1].eventUnix
			peers[#peers + 1] = peer
		end
	end
	table.sort(peers, function(a, b)
		if a.latest ~= b.latest then
			return a.latest > b.latest
		end
		return a.identity < b.identity
	end)
	for index = #peers, MAX_PEERS + 1, -1 do
		peers[index] = nil
	end

	for key in pairs(raw) do
		raw[key] = nil
	end
	self.index, self.latest, self.peerCount = {}, {}, #peers
	for _, peer in ipairs(peers) do
		local saved = {}
		for _, row in ipairs(peer.list) do
			saved[row.metric] = saved[row.metric] or {}
			saved[row.metric][row.subject] = { value = row.value, eventUnix = row.eventUnix }
		end
		raw[peer.key] = saved
		self.index[peer.identity], self.latest[peer.identity] = peer.key, peer.latest
	end
end

-- The caller's peer table, sanitized the first time it is seen; nil while there is none.
---@param self ForeverPeerStatsInstance
local function EnsureStore(self)
	local ok, store = pcall(self.config.db)
	if not ok or type(store) ~= "table" then
		return nil
	end
	if store ~= self.store then
		SanitizeStore(self, store)
		self.store = store
	end
	return store
end

--------------------------------------------------------------------------------------------------------------------
-- Instance

---@class ForeverPeerStatsInstance
---@field config table
---@field addon string
---@field key string
---@field readOnly boolean
---@field dead boolean
---@field active boolean
---@field override boolean|nil
---@field gen integer
---@field sent table
---@field observed table<string, {value: number, unix: number}>
---@field deferred table<string, boolean>
---@field rate table
---@field rateCount integer
---@field index table<string, string>
---@field latest table<string, integer>
---@field peerCount integer
---@field metrics table<string, {subject: string, first: boolean}>
---@field metricList string[]
---@field store table|nil
local Instance = {}
Instance.__index = Instance

-- Queued sends gone, sent cache reset: nothing queued before this call can be sent after it.
function Instance:Cancel()
	self.gen = self.gen + 1
	self.sent = {}
	self.deferred = {}
	local current = Manager()
	if current then
		current.Purge(self)
	end
end

function Instance:Retire()
	self.dead = true
	self.active = false
	self:Cancel()
end

-- Whether this instance may send, receive and show peers now. The saved setting is the truth, SetEnabled(false)
-- overrides it until SetEnabled(true), and a missing database or setting means off. Turning off cancels at once.
function Instance:IsEnabled()
	local on = false
	if not self.dead and self.override ~= false and type(self.config.enabled) == "function" then
		local ok, value = pcall(self.config.enabled)
		on = ok and value and EnsureStore(self) ~= nil or false
	end
	if self.active and not on then
		self:Cancel()
	end
	self.active = on
	return on
end

function Instance:RecordSent(entry)
	if entry.gen == self.gen then
		self.sent[entry.channel .. "|" .. entry.key] =
			{ key = entry.key, value = entry.value, unix = entry.unix, epoch = entry.epoch }
	end
end

-- Offer the consumer's snapshot to every open channel. Rows unchanged since their last successful send on a channel
-- are skipped. Returns how many sends were queued.
function Instance:Sync(onlyDeferred)
	self.deferred = {}
	local current = Manager()
	if self.readOnly or not current or not self:IsEnabled() or type(self.config.snapshot) ~= "function" then
		return 0
	end
	local channels = current.Channels()
	if #channels == 0 then
		return 0
	end
	local ok, rows = pcall(self.config.snapshot)
	if not ok or type(rows) ~= "table" then
		return 0
	end
	local now = Now()
	local list, byKey, observed = {}, {}, {}
	for index = 1, math.min(#rows, MAX_SNAPSHOT) do
		local row = rows[index]
		local config = type(row) == "table" and type(row.metric) == "string" and self.metrics[row.metric]
		if config and ValidSubject(config.subject, row.subject) then
			local value = type(row.value) == "number" and row.value == row.value and math.floor(row.value) or nil
			value = value and IntIn(value, 0, MAX_VALUE)
			local key = row.metric .. "|" .. row.subject
			local unix = IntIn(row.eventUnix, 1, now + FUTURE_SECONDS)
			if not unix and not config.first and (row.eventUnix == nil or type(row.eventUnix) == "number") then
				local previous = self.observed[key]
				unix = previous and previous.value == value and previous.unix or now
			end
			if value and unix then
				observed[key] = { value = value, unix = unix }
				local item = { key = key, value = value, unix = unix }
				item.payload = table.concat({ WIRE_VERSION, self.addon, row.metric, row.subject, value, unix }, "|")
				if byKey[key] then
					list[byKey[key]] = item
				else
					list[#list + 1] = item
					byKey[key] = #list
				end
			end
		end
	end
	self.observed = observed
	for sentKey, entry in pairs(self.sent) do
		if not byKey[entry.key] then
			self.sent[sentKey] = nil
		end
	end
	local queued = 0
	for _, item in ipairs(list) do
		for _, channel in ipairs(channels) do
			local sendKey = channel .. "|" .. item.key
			local last = self.sent[sendKey]
			local same = last
				and last.value == item.value
				and last.unix == item.unix
				and last.epoch == (current.epoch[channel] or 0)
			if not same and (not onlyDeferred or onlyDeferred[sendKey]) then
				if current.Enqueue(self, channel, item.key, item.payload, item.value, item.unix) then
					queued = queued + 1
				else
					self.deferred[sendKey] = true
				end
			end
		end
	end
	return queued
end

-- Explicit opt-out cancels this instance's queue at once and hides peers; opt-in resends everything.
---@param flag boolean
---@return boolean enabled
function Instance:SetEnabled(flag)
	if self.dead then
		return false
	end
	if flag then
		self.override = nil
		self:Cancel()
		if self:IsEnabled() then
			self:Sync()
			return true
		end
		return false
	end
	self.override = false
	self.active = false
	self:Cancel()
	return false
end

---@param self ForeverPeerStatsInstance
local function AllowSender(self, identity)
	local now = GetTime()
	local bucket = self.rate[identity]
	if not bucket then
		if self.rateCount >= MAX_RATE_SENDERS then
			local oldest
			for key, other in pairs(self.rate) do
				if
					not oldest
					or other.last < self.rate[oldest].last
					or (other.last == self.rate[oldest].last and key < oldest)
				then
					oldest = key
				end
			end
			self.rate[oldest], self.rateCount = nil, self.rateCount - 1
		end
		bucket = { tokens = RECEIVE_BURST, last = now }
		self.rate[identity], self.rateCount = bucket, self.rateCount + 1
	end
	bucket.tokens = math.min(RECEIVE_BURST, bucket.tokens + math.max(0, now - bucket.last) * RECEIVE_PER_SECOND)
	bucket.last = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens = bucket.tokens - 1
	return true
end

-- Make room for a new peer by dropping the one with the oldest activity, but only when that is stale.
---@param self ForeverPeerStatsInstance
local function EvictStalePeer(self)
	local oldest
	for identity, latest in pairs(self.latest) do
		if not oldest or latest < self.latest[oldest] or (latest == self.latest[oldest] and identity < oldest) then
			oldest = identity
		end
	end
	if oldest and self.latest[oldest] < Now() - STALE_PEER_SECONDS then
		self.store[self.index[oldest]] = nil
		self.index[oldest], self.latest[oldest], self.peerCount = nil, nil, self.peerCount - 1
		return true
	end
	return false
end

---@param self ForeverPeerStatsInstance
local function Apply(self, key, identity, config, metric, subject, value, unix)
	local store = self.store
	if not store then
		return false, "disabled"
	end
	local peerKey = self.index[identity]
	local peer = peerKey and store[peerKey]
	if not peer then
		if self.peerCount >= MAX_PEERS and not EvictStalePeer(self) then
			return false, "peers"
		end
		peer = {}
		store[key], self.index[identity] = peer, key
		self.peerCount = self.peerCount + 1
	end
	local subjects = peer[metric]
	local record = subjects and subjects[subject]
	if record then
		if not Better(config.first, record, value, unix) then
			return false, "stale"
		end
		record.value, record.eventUnix = value, unix
	else
		local total, inMetric = 0, 0
		for name, rows in pairs(peer) do
			for _ in pairs(rows) do
				total = total + 1
				if name == metric then
					inMetric = inMetric + 1
				end
			end
		end
		if total >= MAX_ROWS or inMetric >= MAX_SUBJECTS then
			return false, "rows"
		end
		subjects = subjects or {}
		peer[metric], subjects[subject] = subjects, { value = value, eventUnix = unix }
	end
	if unix > (self.latest[identity] or 0) then
		self.latest[identity] = unix
	end
	return true
end

-- One addon message. Returns true when it changed a saved row, else false and why.
---@return boolean changed
---@return string? reason
function Instance:Receive(prefix, payload, channel, sender)
	if self.dead or prefix ~= PREFIX then
		return false, "prefix"
	end
	if type(payload) ~= "string" or #payload > MAX_PAYLOAD then
		return false, "payload"
	end
	if not ALLOWED_CHANNELS[channel] then
		return false, "channel"
	end
	if payload:match("^" .. WIRE_VERSION .. "|([^|]*)|") ~= self.addon then
		return false, "addon"
	end
	if not self:IsEnabled() then
		return false, "disabled"
	end
	local key, identity = Identity(sender)
	local own = OwnName()
	if not key or identity == (own and own:lower()) then
		return false, "sender"
	end
	if not AllowSender(self, identity) then
		return false, "rate"
	end
	local _, _, metric, subject, valueText, unixText = payload:match("^(%d+)|([^|]*)|([^|]*)|([^|]*)|([^|]*)|([^|]*)$")
	local config = metric and #metric <= MAX_METRIC and self.metrics[metric]
	if not config or not ValidSubject(config.subject, subject) then
		return false, "metric"
	end
	local value = ParseInt(valueText, 0, MAX_VALUE)
	local unix = ParseInt(unixText, 1, Now() + FUTURE_SECONDS)
	if not value or not unix then
		return false, "value"
	end
	return Apply(self, key, identity, config, metric, subject, value, unix)
end

-- A deep copy of every cached peer row in the saved layout; empty while disabled.
function Instance:Shared()
	local copy = {}
	if not self:IsEnabled() then
		return copy
	end
	for peer, metrics in pairs(self.store) do
		copy[peer] = {}
		for metric, subjects in pairs(metrics) do
			copy[peer][metric] = {}
			for subject, record in pairs(subjects) do
				copy[peer][metric][subject] = { value = record.value, eventUnix = record.eventUnix }
			end
		end
	end
	return copy
end

-- Ranked rows for one metric and subject: the personal row always, peers only while enabled. A first metric ranks by
-- earliest eventUnix (a row without one last); any other by value, highest first. Ties fall to the lowercase
-- identity, so the order never changes between runs. Rows: { rank, name, identity, value, eventUnix, self }.
---@param metric string
---@param subject? string defaults to "all"
---@param localValue? number
---@param localEventUnix? number
function Instance:Board(metric, subject, localValue, localEventUnix)
	subject = subject or "all"
	local config = self.metrics[metric]
	local first = config and config.first
	local name = OwnName() or "player"
	local rows = {
		{
			name = name,
			identity = name:lower(),
			value = IntIn(type(localValue) == "number" and math.floor(localValue) or nil, 0, MAX_VALUE) or 0,
			eventUnix = IntIn(localEventUnix, 1, Now() + FUTURE_SECONDS),
			self = true,
		},
	}
	if config and ValidSubject(config.subject, subject) and self:IsEnabled() then
		for identity, key in pairs(self.index) do
			local subjects = self.store[key] and self.store[key][metric]
			local record = subjects and subjects[subject]
			if record and identity ~= rows[1].identity then
				rows[#rows + 1] = {
					name = key,
					identity = identity,
					value = record.value,
					eventUnix = record.eventUnix,
				}
			end
		end
	end
	table.sort(rows, function(a, b)
		if first then
			if (a.eventUnix == nil) ~= (b.eventUnix == nil) then
				return a.eventUnix ~= nil
			end
			if a.eventUnix ~= b.eventUnix then
				return a.eventUnix < b.eventUnix
			end
		elseif a.value ~= b.value then
			return a.value > b.value
		end
		return a.identity < b.identity
	end)
	for rank, row in ipairs(rows) do
		row.rank = rank
	end
	return rows
end

--------------------------------------------------------------------------------------------------------------------

---@class ForeverPeerStatsNamespace
local PeerStats = { PREFIX = PREFIX, Identity = Identity }

-- A new instance for `config`, registered with the shared manager. A second instance for the same addon replaces the
-- first, so two loaded copies never send twice. A config without a valid addon id returns an inert instance.
---@param config table
---@return ForeverPeerStatsInstance
local function New(config, owner)
	config = type(config) == "table" and config or {}
	local addon = type(config.addon) == "string" and #config.addon <= MAX_ADDON and config.addon:find("^[%w_%-]+$")
	local readOnly = owner ~= false
	local validOwner = type(owner) == "string" and #owner <= MAX_ADDON and owner:find("^[%w_%-]+$")
	local dead = not addon or (readOnly and not validOwner)
	---@type ForeverPeerStatsInstance
	local self = setmetatable({
		config = config,
		addon = addon and config.addon or "",
		key = not dead and (type(owner) == "string" and (owner .. "@" .. config.addon) or config.addon) or "",
		readOnly = readOnly,
		dead = dead,
		active = false,
		gen = 0,
		sent = {},
		observed = {},
		deferred = {},
		rate = {},
		rateCount = 0,
		index = {},
		latest = {},
		peerCount = 0,
		metrics = {},
		metricList = {},
	}, Instance)
	if type(config.metrics) == "table" then
		for _, metric in ipairs(SortedStringKeys(config.metrics, MAX_METRICS)) do
			local entry = config.metrics[metric]
			local mode = type(entry) == "table" and entry.subject or ""
			if #metric <= MAX_METRIC and metric:find("^[%w_%.%-]+$") and SUBJECT_MODES[mode] then
				self.metrics[metric] = { subject = mode, first = entry.first == true }
				self.metricList[#self.metricList + 1] = metric
			end
		end
	end
	if not dead then
		local current = Manager()
		if current then
			current.Register(self)
		end
	end
	return self
end

function PeerStats.New(config)
	return New(config, false)
end

---@param owner string owner addon id, independent of the observed config.addon
---@param config table
---@return ForeverPeerStatsInstance
function PeerStats.Listen(owner, config)
	return New(config, owner or "")
end

ns.PeerStats = PeerStats
