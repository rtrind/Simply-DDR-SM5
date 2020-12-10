-- This is mostly copy/pasted directly from SM5's _fallback theme with
-- very minor modifications.

local t = Def.ActorFrame{}

-- -----------------------------------------------------------------------

local function CreditsText( player )
	return LoadFont("Common Normal") .. {
		InitCommand=function(self)
			self:visible(false)
			self:name("Credits" .. PlayerNumberToString(player))
			ActorUtil.LoadAllCommandsAndSetXY(self,Var "LoadingScreen")
		end,
		UpdateTextCommand=function(self)
			-- this feels like a holdover from SM3.9 that just never got updated
			local str = ScreenSystemLayerHelpers.GetCreditsMessage(player)
			self:settext(str)
		end,
		UpdateVisibleCommand=function(self)
			local screen = SCREENMAN:GetTopScreen()
			local bShow = true

			self:diffuse(Color.White)

			if screen then
				bShow = THEME:GetMetric( screen:GetName(), "ShowCreditDisplay" )

				if (screen:GetName() == "ScreenEvaluationStage") or (screen:GetName() == "ScreenEvaluationNonstop") then
					-- ignore ShowCreditDisplay metric for ScreenEval
					-- only show this BitmapText actor on Evaluation if the player is joined
					bShow = GAMESTATE:IsHumanPlayer(player)
					--        I am not human^
					--        today, but there's always hope
					--        I'll see tomorrow

					-- dark text for RainbowMode
					if ThemePrefs.Get("RainbowMode") then self:diffuse(Color.Black) end
				end
			end

			self:visible( bShow )
		end
	}
end

-- -----------------------------------------------------------------------
-- player avatars
-- see: https://youtube.com/watch?v=jVhlJNJopOQ

for player in ivalues(PlayerNumber) do
	t[#t+1] = Def.Sprite{
		ScreenChangedMessageCommand=function(self)   self:queuecommand("Update") end,
		PlayerJoinedMessageCommand=function(self, params)   if params.Player==player then self:queuecommand("Update") end end,
		PlayerUnjoinedMessageCommand=function(self, params) if params.Player==player then self:queuecommand("Update") end end,

		UpdateCommand=function(self)
			local path = GetPlayerAvatarPath(player)

			if path == nil and self:GetTexture() ~= nil then
				self:Load(nil):diffusealpha(0):visible(false)
				return
			end

			-- only read from disk if not currently set
			if self:GetTexture() == nil then
				self:Load(path):finishtweening():linear(0.075):diffusealpha(1)

				local dim = 32
				local h   = (player==PLAYER_1 and left or right)
				local x   = (player==PLAYER_1 and    0 or _screen.w)

				self:horizalign(h):vertalign(bottom)
				self:xy(x, _screen.h):setsize(dim,dim)
			end

			local screen = SCREENMAN:GetTopScreen()
			if THEME:HasMetric(screen:GetName(), "ShowPlayerAvatar") then
				self:visible( THEME:GetMetric(screen:GetName(), "ShowPlayerAvatar") )
			else
				self:visible( THEME:GetMetric(screen:GetName(), "ShowCreditDisplay") )
			end
		end,
	}
end

-- -----------------------------------------------------------------------

-- what is aux?
t[#t+1] = LoadActor(THEME:GetPathB("ScreenSystemLayer","aux"))

-- Credits
t[#t+1] = Def.ActorFrame {
 	CreditsText( PLAYER_1 ),
	CreditsText( PLAYER_2 )
}


-- -----------------------------------------------------------------------
-- SystemMessage stuff
-- this is what appears when someone uses SCREENMAN:SystemMessage(text)
-- or MESSAGEMAN:Broadcast("SystemMessage", {text})
-- or SM(text)

local bmt = nil
local timestamp = nil

-- SystemMessage ActorFrame
t[#t+1] = Def.ActorFrame {
	InitCommand=function(self)
		self:SetUpdateFunction(updateTimestamp)
	end,
	SystemMessageMessageCommand=function(self, params)
		bmt:settext( params.Message )

		self:playcommand( "On" )
		if params.NoAnimate then
			self:finishtweening()
		end
		self:playcommand( "Off", params )
	end,
	HideSystemMessageMessageCommand=function(self) self:finishtweening() end,

	-- background quad behind the SystemMessage
	Def.Quad {
		InitCommand=function(self)
			self:zoomto(_screen.w, 30)
			self:horizalign(left):vertalign(top)
			self:diffuse(0,0,0,0)
		end,
		OnCommand=function(self)
			self:finishtweening():diffusealpha(0.85)
			self:zoomto(_screen.w, (bmt:GetHeight() + 16) * SL_WideScale(0.8, 1) )
		end,
		OffCommand=function(self, params)
			-- use 3.33 seconds as a default duration if none was provided as the second arg in SM()
			self:sleep(type(params.Duration)=="number" and params.Duration or 3.33):linear(0.25):diffusealpha(0)
		end,
	},

	-- BitmapText for the SystemMessage
	LoadFont("Common Normal")..{
		Name="Text",
		InitCommand=function(self)
			bmt = self

			self:maxwidth(_screen.w-20)
			self:horizalign(left):vertalign(top):xy(10, 10)
			self:diffusealpha(0):zoom(SL_WideScale(0.8, 1))
		end,
		OnCommand=function(self)
			self:finishtweening():diffusealpha(1)
		end,
		OffCommand=function(self, params)
			-- use 3 seconds as a default duration if none was provided as the second arg in SM()
			self:sleep(type(params.Duration)=="number" and params.Duration or 3):linear(0.5):diffusealpha(0)
		end,
	}
}
-- -----------------------------------------------------------------------

-- "Event Mode" or CreditText at lower-center of screen
t[#t+1] = LoadFont("Common Footer")..{
	InitCommand=function(self) self:xy(_screen.cx, _screen.h-16):zoom(0.5):horizalign(center) end,

	OnCommand=function(self) self:playcommand("Refresh") end,
	ScreenChangedMessageCommand=function(self) self:playcommand("Refresh") end,
	CoinModeChangedMessageCommand=function(self) self:playcommand("Refresh") end,
	CoinsChangedMessageCommand=function(self) self:playcommand("Refresh") end,

	RefreshCommand=function(self)

		local screen = SCREENMAN:GetTopScreen()

		-- if this screen's Metric for ShowCreditDisplay=false, then hide this BitmapText actor
		-- PS: "ShowCreditDisplay" isn't a real Metric as far as the engine is concerned.
		-- I invented it for Simply Love and it has (understandably) confused other themers.
		-- Sorry about this.
		if screen then
			self:visible( THEME:GetMetric( screen:GetName(), "ShowCreditDisplay" ) )
		end

		if PREFSMAN:GetPreference("EventMode") then
			self:settext( THEME:GetString("ScreenSystemLayer", "EventMode") )

		elseif GAMESTATE:GetCoinMode() == "CoinMode_Pay" then
			local credits = GetCredits()
			local text

			if credits.CoinsPerCredit > 1 then
				text = ("%s     %d     %d/%d"):format(
					THEME:GetString("ScreenSystemLayer", "CreditsCredits"),
					credits.Credits,
					credits.Remainder,
					credits.CoinsPerCredit
				)
			else
				text = ("%s     %d"):format(
					THEME:GetString("ScreenSystemLayer", "CreditsCredits"),
					credits.Credits
				)
			end

			self:settext(text)

		elseif GAMESTATE:GetCoinMode() == "CoinMode_Free" then
			self:settext( THEME:GetString("ScreenSystemLayer", "FreePlay") )

		elseif GAMESTATE:GetCoinMode() == "CoinMode_Home" then
			self:settext('')
		end
	end
}

function updateTimestamp(af)
	timestamp:playcommand("Refresh")
end

-- Date & time at lower-center of screen
-- This is only shown on the ScreenEvaluationStage and ScreenEvaluationSummary
-- screens. The above actor is not shown on either screen, so it doesn't
-- overlap with it.
t[#t+1] = LoadFont("Wendy/_wendy monospace numbers")..{
	InitCommand=function(self)
		timestamp = self

		self:x(_screen.cx):horizalign(center)
		self:zoom(0.18)
	end,

	OnCommand=function(self) self:playcommand("Refresh") end,
	ScreenChangedMessageCommand=function(self) self:playcommand("Refresh") end,

	RefreshCommand=function(self)
		local screen = SCREENMAN:GetTopScreen()
		local visible = false

		if screen then
			if screen:GetName() == 'ScreenEvaluationStage' then
				visible = true
				self:y(_screen.h - 15)
			elseif screen:GetName() == 'ScreenEvaluationSummary' then
				visible = true
				self:y(_screen.h - 20)
			end
		end

		self:visible(visible)
		self:diffuse(ThemePrefs.Get("RainbowMode") and Color.Black or Color.White)

		local DateFormat = "%04d/%02d/%02d %02d:%02d"
		self:settext(DateFormat:format(Year(), MonthOfYear()+1, DayOfMonth(), Hour(), Minute()))
	end
}

return t
