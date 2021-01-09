local BA = CreateFrame("frame")

local chatMessage          = "Eae %s, vai separar ou tá difícil? Você já stackou em %s pessoa%s."  -- %s are "player", "stacks" and "plural"
local plural               = "s"
local channelToSendMessage = "RAID"   -- valid options are SAY, YELL, RAID, PARTY

-- Don't touch anything below
local baDebug                     = false  -- BA debug messages
-- Chat Parameters
local delayBetweenMessagesPerChar = 2    -- This delay is per character
local maxMessagesSent             = 3    -- Max messages that can be send at once before getting muted by the server
local gracePeriodForSendMessages  = 1.2  -- Assuming that we can send at most 'maxMessagesSent' every 'gracePeriodForSendMessages' seconds

-- General spells
local ENERVATING_BRAND_ID = 74505

local validChannels       = {"SAY", "YELL", "RAID", "PARTY"}
local validInstances      = {"The Ruby Sanctum"}
local sentChatMessageTime = 0     -- Last time any chatMessage has been sent
local alertedPlayerTime   = {}
local stacksPerPlayer     = {}
local timeMessagesSent    = {}

-- Player current instance info
local instanceName

local addonPrefix = "|cfff02236BaltharusAlert:|r "
local addonVersion

-- Upvalues
local SendChatMessage, GetTime, UnitName, strsplit, wipe, format = SendChatMessage, GetTime, UnitName, strsplit, wipe, string.format

BA:SetScript("OnEvent", function(self, event, ...)
   self[event](self, ...)
end)

-- Utility functions
local function send(msg)
   if(msg~=nil) then print(addonPrefix .. msg) end
end

local function say(msg)
   if(msg~=nil) then SendChatMessage(msg, channelToSendMessage) end
end

local is_int = function(n)
   return (type(n) == "number") and (math.floor(n) == n)
end

-- [string utils]
-- Remove spaces on start and end of string
local function trim(s)
   if s==nil then return "" end
   assert(type(s) == "string", "bad argument #1: 's' needs to be a string; instead what came was " .. tostring(type(s)))
   return string.match(s,'^()%s*$') and '' or string.match(s,'^%s*(.*%S)')
end

local function removeWords(myString, howMany)
   if (myString~=nil and howMany~=nil) then
      assert(type(myString) == "string", "bad argument #1: 'myString' needs to be a string; instead what came was " .. tostring(type(myString)))
      assert(type(howMany) == "number", "bad argument #2: 'howMany' needs to be a number; instead what came was " .. tostring(type(howMany)))
      assert(math.floor(howMany) == howMany, "bad argument #2: 'howMany' needs to be an integer")

      for i=1, howMany do
         myString = string.gsub(myString,"^(%s*%a+)","",1)
      end
      return trim(myString)
   end
   return ""
end
-- end of [string utils]

local function tableHasThisEntry(table, entry)
   assert(table~=nil, "bad argument #1: 'table' cannot be nil")
   assert(type(table) == "table", "bad argument #1: 'table' needs to be a table; instead what came was " .. tostring(type(table)))
   assert(entry~=nil, "bad argument #2: 'entry' cannot be nil")

   for _, value in ipairs(table) do
      if value == entry then
         return true
      end
   end
   return false
end

local function tableHasThisKey(table, keyToSearch)
   assert(table~=nil, "bad argument #1: 'table' cannot be nil")
   assert(type(table) == "table", "bad argument #1: 'table' needs to be a table; instead what came was " .. tostring(type(table)))
   assert(keyToSearch~=nil, "bad argument #2: 'keyToSearch' cannot be nil")

   for key,_ in pairs(table) do
      if key == keyToSearch then
         return true
      end
   end
   return false
end

local function getTableLength(table)
   assert(table~=nil, "bad argument #1: 'table' cannot be nil")
   assert(type(table) == "table", "bad argument #1: 'table' needs to be a table; instead what came was " .. tostring(type(table)))

   local count = 0
   for _ in pairs(table) do count = count + 1 end
   return count
end

--local function isAddonEnabledForPlayerClass()
--   if(playerClass==nil) then send("playerClass came null inside function to check if addon should be enabled for class, report this"); return; end
--
--   -- If the key is for our class and if it's value is true then return true, else return false
--   for key, value in pairs(removeFor) do
--      if string.match(key, playerClass) and value then
--         return true
--      end
--   end
--   return false
--end

local function updatePlayerLocal()  -- Update variables with player current instance info
   instanceName = GetInstanceInfo()
end

local function updatePlayerLocalIfNeeded()
   if(instanceName==nil) then updatePlayerLocal() end
end

do
   local Messenger = CreateFrame("frame")
   local queuedMessages = {}

   -- Addon is going to check how many messages got sent in the last 'gracePeriodForSendMessages', and if its equal or maxMessageSent then this function will return true, indicating that player cannot send more messages for now
   local function isSendMessageGoingToMute()
      local now = GetTime()
      local count = 0

      for index, time in pairs(timeMessagesSent) do
         if (now <= (tonumber(time) + gracePeriodForSendMessages)) then
            count = count + 1
         else
            table.remove(timeMessagesSent,index)
         end
      end
      return count >= maxMessagesSent
   end

   -- Frame update handler
   local function onUpdate(this)
      if not BA.db.enabled then return end
      if #queuedMessages == 0 then
         if baDebug then send("unregistered onUpdate because there are no messages") end
         this:SetScript("OnUpdate", nil)
         return
      end
      if isSendMessageGoingToMute() then return end

      local now = GetTime()
      local message, srcName = strsplit("\t",queuedMessages[1])

      sentChatMessageTime = now
      alertedPlayerTime[srcName] = now
      table.insert(timeMessagesSent, now)

      say(message, channelToSendMessage)
      table.remove(queuedMessages,1)
   end

   function BA:QueueMsg(msg)
      if(msg~=nil) then
         queuedMessages = queuedMessages or {}
         table.insert(queuedMessages,msg)
         Messenger:SetScript("OnUpdate", onUpdate)
      end
   end

   function BA:CHAT_MSG_WHISPER(_, srcName)
      if srcName == UnitName("player") then table.insert(timeMessagesSent, GetTime()) end
   end

   function BA:CHAT_MSG_SAY(_, srcName)
      if srcName == UnitName("player") then table.insert(timeMessagesSent, GetTime()) end
   end

   function BA:CHAT_MSG_PARTY(_, srcName)
      if srcName == UnitName("player") then table.insert(timeMessagesSent, GetTime()) end
   end

   function BA:CHAT_MSG_RAID(_, srcName)
      if srcName == UnitName("player") then table.insert(timeMessagesSent, GetTime()) end
   end

   function BA:CHAT_MSG_RAID_LEADER(_, srcName)
      if srcName == UnitName("player") then table.insert(timeMessagesSent, GetTime()) end
   end

   function BA:CHAT_MSG_RAID_WARNING(_, srcName)
      if srcName == UnitName("player") then table.insert(timeMessagesSent, GetTime()) end
   end
end

-- Logic functions are under here
local function alertPlayer(srcName)
   if srcName==nil or srcName=="" then return end
   assert(type(srcName) == "string", "bad argument #1: 'srcName' needs to be a string; instead what came was " .. tostring(type(srcName)))

   local now = GetTime()
   stacksPerPlayer[srcName] = stacksPerPlayer[srcName] and (stacksPerPlayer[srcName] + 1) or 1
   if stacksPerPlayer[srcName] < 3 then return end

   local message = format(chatMessage,srcName,stacksPerPlayer[srcName],((stacksPerPlayer[srcName] > 1) and plural or ""))
   if not tableHasThisKey(alertedPlayerTime, srcName) then alertedPlayerTime[srcName] = 0 end

   if not (now > (alertedPlayerTime[srcName] + delayBetweenMessagesPerChar)) then
      BA:QueueMsg(format("%s\t%s",message,srcName))
   end
end

function BA:COMBAT_LOG_EVENT_UNFILTERED(_, event, _, srcName, _, _, destName, _, spellID, ...)
   if spellID==nil then return end  -- If spell doesn't have an ID, it's not relevant since all mind control spells have one

   -- If any player (except who is running this addon) is stacking Enervating Brand debuff on someone that is not himself, alert on chat
   if spellID == ENERVATING_BRAND_ID and event == "SPELL_AURA_APPLIED" and srcName~=UnitName("player") and srcName~=destName then
      alertPlayer(srcName)
   end
end

local function zeroVariables()
   sentChatMessageTime = 0
   wipe(alertedPlayerTime)
   wipe(stacksPerPlayer)
   wipe(timeMessagesSent)
end

local function regForAllEvents()
   if(BA==nil) then send("frame is nil inside function that register for all events function, report this"); return; end
   if baDebug then send("addon is now listening to all combatlog events.") end

   BA:RegisterEvents(
      "COMBAT_LOG_EVENT_UNFILTERED",
      "PLAYER_REGEN_DISABLED",
      "CHAT_MSG_WHISPER",
      "CHAT_MSG_SAY",
      "CHAT_MSG_PARTY",
      "CHAT_MSG_RAID",
      "CHAT_MSG_RAID_LEADER",
      "CHAT_MSG_RAID_WARNING"
   )
end

local function unregFromAllEvents()
   if(BA==nil) then send("frame is nil inside function that unregister all events function, report this"); return; end
   if baDebug then send("addon is no longer listening to combatlog events.") end

   BA:UnregisterEvents(
      "COMBAT_LOG_EVENT_UNFILTERED",
      "PLAYER_REGEN_DISABLED",
      "CHAT_MSG_WHISPER",
      "CHAT_MSG_SAY",
      "CHAT_MSG_PARTY",
      "CHAT_MSG_RAID",
      "CHAT_MSG_RAID_LEADER",
      "CHAT_MSG_RAID_WARNING"
   )
   zeroVariables()
end

-- Checks if addon should be enabled, and enable it if isn't enabled, and disable if it should not be enabled
local function checkIfAddonShouldBeEnabled()
   if(BA ==nil) then send("frame came nil inside function that check if this addon should be enabled, report this"); return; end
   updatePlayerLocalIfNeeded()

   local shouldIt = false
   local reason = "|cffffe83bstatus:|r addon is |cffff0000off|r because it was set as OFF by the command \'/ba toggle\'."
   if BA.db.enabled then
      if baDebug then
         shouldIt = true
         reason = "|cffffe83bstatus:|r addon is |cff00ff00on|r because debug mode is turned on."
      elseif tableHasThisEntry(validInstances, instanceName) then
         shouldIt = true
         reason = format("|cffffe83bstatus:|r addon is |cff00ff00on|r because you are inside a valid instance (%s).",instanceName)
      else
         reason = "|cffffe83bstatus:|r addon is |cffff0000off|r because you not inside a valid instance."
      end
   end

   if shouldIt then regForAllEvents()
   else unregFromAllEvents() end
   return shouldIt, reason
end

function BA:PLAYER_REGEN_DISABLED()
   zeroVariables()
end

function BA:PLAYER_ENTERING_WORLD()
   updatePlayerLocal()
   checkIfAddonShouldBeEnabled()
end

-- Slash commands functions
-- toggle, on, off
local function slashToggleAddon(state)
   if state == "on" or (not BA.db.enabled and state==nil) then
      BA.db.enabled = true
   elseif state == "off" or (BA.db.enabled and state==nil) then
      BA.db.enabled = false
   end
   checkIfAddonShouldBeEnabled()
   send(BA.db.enabled and "|cff00ff00on|r" or "|cffff0000off|r")
end

-- status, state
local function slashStatus()
   send(select(2,checkIfAddonShouldBeEnabled()))
end

-- version, ver
local function slashVersion()
   if(addonVersion==nil) then send("Try again later, addon still loading..."); return; end
   send("version " .. addonVersion)
end

-- debug
local function slashDebug()
   if not baDebug then
      baDebug = true
      BA.db.debug = true
   else
      baDebug = false
      BA.db.debug = false
   end
   send("debug mode turned " .. (baDebug and "|cff00ff00on|r" or "|cffff0000off|r"))
   checkIfAddonShouldBeEnabled()
end

-- channel
local function slashChannel(channel)
   if channel==nil or channel=="" then
      send(format("select channel is: |cfff84d13%s|r",channelToSendMessage))
      return
   end

   channel = channel:upper()
   -- Aliases
   if channel == "S" then channel = "SAY"
   elseif channel == "Y" then channel = "YELL"
   elseif channel == "R" then channel = "RAID"
   elseif channel == "P" then channel = "PARTY" end
   if tableHasThisKey(validChannels, channel) then
      send(format("you will now send messages on |cffff7631%s|r.",channel))
      channelToSendMessage = channel
      BA.db.channeltosendmessage = channelToSendMessage
   else
      local str = ""
      local validChannelsLength = getTableLength(validChannels)
      for index, value in ipairs(validChannels) do
         str = str .. "\"" .. value .. "\"" .. (index~=validChannelsLength and ", " or ".")
      end
      send(format("this channel doesn't exist, please choose one of the following: %s",str))
   end
end

local function slashTest()
   for i=1,20 do
      BA:QueueMsg(format("%s\t%s","It's a test " .. i,"Freezer"))
   end
end

local function slashCommand(typed)
   local cmd = string.match(typed,"^%s*(%w+)") -- Gets the first word the user has typed
   if cmd~=nil then cmd = cmd:lower() end           -- And makes it lower case
   local extra = removeWords(typed,1)

   if(cmd==nil or cmd=="" or cmd=="toggle") then slashToggleAddon()
   elseif(cmd=="on" or cmd=="enable") then slashToggleAddon("on")
   elseif(cmd=="off" or cmd=="disable") then slashToggleAddon("off")
   elseif(cmd=="status" or cmd=="state" or cmd=="reason") then slashStatus()
   elseif(cmd=="version" or cmd=="ver") then slashVersion()
   elseif(cmd=="debug") then slashDebug()
   elseif(cmd=="channel" or cmd=="c") then slashChannel(extra)
   elseif(cmd=="test") then slashTest()
   end
end
-- End of slash commands function

function BA:RegisterEvents(...)
   for i = 1, select("#", ...) do
      local ev = select(i, ...)
      self:RegisterEvent(ev)
   end
end

function BA:UnregisterEvents(...)
   for i = 1, select("#", ...) do
      local ev = select(i, ...)
      self:UnregisterEvent(ev)
   end
end

function BA:ADDON_LOADED(addon)
   if addon ~= "BaltharusAlert" then return end

   BADB = BADB or { enabled = true }
   self.db = BADB

   addonVersion = GetAddOnMetadata("BaltharusAlert", "Version")
   -- Loading variables
   baDebug = self.db.debug or baDebug
   channelToSendMessage = self.db.channeltosendmessage or channelToSendMessage
   SLASH_BALTHARUSALERT1 = "/ba"
   SLASH_BALTHARUSALERT2 = "/baltharusalert"
   SlashCmdList.BALTHARUSALERT = function(cmd) slashCommand(cmd) end
   if baDebug then send("remember that debug mode is |cff00ff00ON|r.") end

   self:RegisterEvent("PLAYER_ENTERING_WORLD")
   self:UnregisterEvent("ADDON_LOADED")
end

BA:RegisterEvent("ADDON_LOADED")