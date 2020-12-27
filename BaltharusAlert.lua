local BA = CreateFrame("frame")

local chatMessage          = "Eae %s, vai separar ou tá difícil? Você já stackou em %s pessoa%s."  -- %s are "player", "stacks" and "plural"
local plural               = "s"
local channelToSendMessage = "RAID"   -- valid options are SAY, YELL, RAID, PARTY

-- Don't touch anything below
local baDebug                     = false  -- BA debug messages
-- Chat Parameters
local delayBetweenMessagesPerChar = 2   -- This delay is per character
local maxMessagesSent             = 4   -- Max messages that can be send at once before getting muted by the server
local gracePeriodForSendMessages  = 1.2   -- Assuming that we can send at most 'maxMessagesSent' every 'gracePeriodForSendMessages' seconds

-- General spells
local ENERVATING_BRAND_ID = 74505

local validChannels       = {"SAY", "YELL", "RAID", "PARTY"}
local validInstances      = {"The Ruby Sanctum"}
local sentChatMessageTime = 0     -- Last time any chatMessage has been sent
local alertedPlayerTime   = {}
local stacksPerPlayer     = {}
local timeMessagesSent    = {}
local queuedMessages

-- Player current instance info
local instanceName

local addonPrefix = "|cfff02236BaltharusAlert:|r "
local addonVersion

-- Upvalues
local SendChatMessage, GetTime, UnitName, format = SendChatMessage, GetTime, UnitName, string.format

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
   return string.match(s,'^()%s*$') and '' or string.match(s,'^%s*(.*%S)')
end

local function removeWords(myString, numberOfWords)
   if (myString~=nil and numberOfWords~=nil) then
      if is_int(numberOfWords) then
         for i=1, numberOfWords do
            myString = string.gsub(myString,"^(%s*%a+)","",1)
         end
         return trim(myString)
      else send("numberOfWords arg came, it's not nil BUT it's also NOT an integer, report this, type = " .. tostring(type(numberOfWords))) end
   end
   return ""
end
-- end of [string utils]

local function tableHasThisEntry(table, entry)
   if table==nil then send("table came nil inside function that check if table has a value, report this");return; end
   if entry==nil then send("entry came nil inside function to check if table has a value, report this");return; end

   for _, value in ipairs(table) do
      if value == entry then
         return true
      end
   end
   return false
end

local function tableHasThisKey(table, keyToSearch)
   if table==nil then send("table came nil inside function that check if table has a key, report this");return; end
   if keyToSearch==nil then send("keyToSearch came nil inside function to check if table has a key, report this");return; end

   for key,_ in pairs(table) do
      if key == keyToSearch then
         return true
      end
   end
   return false
end

local function getTableLength(table)
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

-- Addon is going to check how many messages got sent in the last 'gracePeriodForSendMessages', and if its equal or maxMessageSent then this function will return true, indicating that player cannot send more messages for now
local function isSendMessageGoingToMute()
   local now = GetTime()
   local time
   local count = 0

   for index, time in pairs(timeMessagesSent) do
      if (now <= (tonumber(time) + gracePeriodForSendMessages)) then
         count = count + 1
      else
         table.remove(timeMessagesSent,index)
      end
   end
   if count >= maxMessagesSent then return true
   else return false end
end

-- Frame update handler
local function onUpdate(this)
   if not BA.db.enabled then return end
   if not queuedMessages then
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
   if getTableLength(queuedMessages)==0 then queuedMessages = nil end
end

-- Logic functions are under here
local function alertPlayer(srcName)
   if srcName==nil or srcName=="" then return end

   local now = GetTime()
   stacksPerPlayer[srcName] = stacksPerPlayer[srcName] and (stacksPerPlayer[srcName] + 1) or 1
   if stacksPerPlayer[srcName] < 3 then return end

   local message = format(chatMessage,srcName,stacksPerPlayer[srcName],((stacksPerPlayer[srcName] > 1) and plural or ""))
   if not tableHasThisKey(alertedPlayerTime, srcName) then alertedPlayerTime[srcName] = 0 end
   --if not queuedMessages and not isSendMessageGoingToMute() and (now > (alertedPlayerTime[srcName] + delayBetweenMessagesPerChar)) then
   --   sentChatMessageTime        = now
   --   alertedPlayerTime[srcName] = now
   --   table.insert(messagesSent, format("%s\t%s",now,srcName))
   --   say(message, channelToSendMessage)
   --elseif isSendMessageGoingToMute() and not (now > (alertedPlayerTime[srcName] + delayBetweenMessagesPerChar)) then
   --   queuedMessages = queuedMessages or {}
   --   table.insert(queuedMessages,format("%s\t%s",message,srcName))
   --   BA:SetScript("OnUpdate", onUpdate)
   --end
   if not (now > (alertedPlayerTime[srcName] + delayBetweenMessagesPerChar)) then
      queuedMessages = queuedMessages or {}
      table.insert(queuedMessages,format("%s\t%s",message,srcName))
      BA:SetScript("OnUpdate", onUpdate)
   end
end

function BA:COMBAT_LOG_EVENT_UNFILTERED(_, event, _, srcName, _, _, destName, _, spellID, ...)
   if spellID==nil then return end  -- If spell doesn't have an ID, it's not relevant since all mind control spells have one

   -- If any player (except who is running this addon) is stacking Enervating Brand debuff on someone that is not himself, alert on chat
   if spellID == ENERVATING_BRAND_ID and event == "SPELL_AURA_APPLIED" and srcName~=UnitName("player") and srcName~=destName then
      alertPlayer(srcName)
   end
end

local function regForAllEvents()
   if(BA==nil) then send("frame is nil inside function that register for all events function, report this"); return; end
   if baDebug then send("addon is now listening to all combatlog events.") end

   BA:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
   BA:RegisterEvent("PLAYER_REGEN_ENABLED")
   BA:RegisterEvent("PLAYER_REGEN_DISABLED")
end

local function unregFromAllEvents()
   if(BA==nil) then send("frame is nil inside function that unregister all events function, report this"); return; end
   if baDebug then send("addon is no longer listening to combatlog events.") end

   BA:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
   BA:UnregisterEvent("PLAYER_REGEN_ENABLED")
   BA:UnregisterEvent("PLAYER_REGEN_DISABLED")
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

local function zeroVariables()
   alertedPlayerTime   = {}
   stacksPerPlayer     = {}
   sentChatMessageTime = 0
   timeMessagesSent    = {}
   queuedMessages      = nil
end

function BA:PLAYER_ENTERING_WORLD()
   updatePlayerLocal()
   checkIfAddonShouldBeEnabled()
   zeroVariables()
end

function BA:PLAYER_REGEN_ENABLED()
   zeroVariables()
end

function BA:PLAYER_REGEN_DISABLED()
   zeroVariables()
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
   queuedMessages = queuedMessages or {}
   for i=1,20 do
      table.insert(queuedMessages,format("%s\t%s","It's a test " .. i,"Freezer"))
   end
   BA:SetScript("OnUpdate", onUpdate)
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

function BA:ADDON_LOADED(addon)
   if addon ~= "BaltharusAlert" then return end

   BADB = BADB or { enabled = true }
   self.db = BADB

   addonVersion = GetAddOnMetadata("BaltharusAlert", "Version")
   -- Loading variables
   baDebug = self.db.debug or baDebug
   channelToSendMessage = self.db.channeltosendmessage or channelToSendMessage
   SLASH_BALTHARUSALERT1 = "/ba"
   SLASH_BALTHARUSALERTL2 = "/baltharusalert"
   SlashCmdList.BALTHARUSALERT = function(cmd) slashCommand(cmd) end
   if baDebug then send("remember that debug mode is |cff00ff00ON|r.") end

   self:RegisterEvent("PLAYER_ENTERING_WORLD")
   self:UnregisterEvent("ADDON_LOADED")
end

BA:RegisterEvent("ADDON_LOADED")