//-----------------------------------------------------------------------
//------------------- Copyright (c) samisalreadytaken -------------------
//
//                       github.com/samisalreadytaken
//
// This project is licensed under the terms of the MIT License.
// See <README.md> or <LICENSE> for details.
//-----------------------------------------------------------------------
//
// For CS:GO event examples, see the example map at
//   	https://github.com/samisalreadytaken/vscripts
//
// For vs_library documentation, see
//  	https://github.com/samisalreadytaken/vs_library/blob/master/Documentation.md
//
//-----------------------------------------------------------------------

//-----------------------------------------------------------------------
// Input  : int userid
// Output : player handle
//-----------------------------------------------------------------------
function VS::GetPlayerByUserid( userid )
{
	local ent, Ent = ::Entities;

	while( ent = Ent.Next(ent) ) if( ent.GetClassname() == "player" )
	{
		local s = ent.GetScriptScope();
		if( "userid" in s && s.userid == userid )
			return ent;
	}
}

//-----------------------------------------------------------------------
// Bind the input function to global 'OnGameEvent_' function in 'scope', 'this' by default.
//
// Input  : string|handle, closure|string, table
// Output :
//-----------------------------------------------------------------------
function VS::AddEventCallback(event,func,scope = null)
{
	if(!scope)
		scope = GetCaller();
	else if( typeof scope != "table" )
		throw "Invalid scope type " + typeof scope;;

	if( typeof func == "string" )
	{
		if( func.find("(") != null )
			throw "Invalid function string";
		else
			func = scope[func];
	}
	else if( typeof func != "function" )
		throw "Invalid function type " + typeof func;;

	if( typeof event == "instance" )
	{
		if( event instanceof ::CBaseEntity )
		{
			if( event.IsValid() )
				event = event.GetName();
			else
				throw "Invalid event input";
		};
	}
	else if( typeof event != "string" )
		throw "Invalid event input: " + typeof event;;

	::getroottable()["OnGameEvent_"+event] <- func.bindenv(scope);
}

//-----------------------------------------------------------------------

// OnEvent player_connect
// user function ::OnGameEvent_player_connect will still be called
//
// If events are correctly set up, add the userid, networkid (steamID32) and name to the player scope
// Bot networkid is "BOT"
//
// Only allows 128 unprocessed entries to be held
// This limit realistically will never be reached (unless the player_spawn listener
// was never created or correctly set up). It's a just-in-case check.
//
// When the limit is reached, the oldest 64 entries are deleted.
function VS::Events::player_connect(data)
{
	if(::_xa9b2dfB7ffe.len()>128)
	{
		for(local i=0;i<64;++i)::_xa9b2dfB7ffe.remove(0);
		::print("player_connect: ERROR!!! Player data is not being processed.\n")
	};
	::_xa9b2dfB7ffe.append(data);

	return::OnGameEvent_player_connect(data);
}

// OnEvent player_spawn
// user function ::OnGameEvent_player_spawn will still be called
function VS::Events::player_spawn(data)
{
	if( ::_xa9b2dfB7ffe.len() ) foreach( i, d in ::_xa9b2dfB7ffe ) if( d.userid == data.userid )
	{
		local player = ::VS.GetPlayerByIndex(d.index+1);

		if( !player.ValidateScriptScope() )
		{
			::print("player_connect: Invalid player entity.\n");
			break;
		};

		local scope = player.GetScriptScope();

		if( "networkid" in scope )
		{
			::print("player_connect: BUG!!! Something has gone wrong. ");

			if( scope.networkid==d.networkid )
			{
				::print("Duplicated data!\n");
				::_xa9b2dfB7ffe.remove(i);
			}
			else::print("Conflicting data!\n");

			break;
		};

		if( !d.networkid.len() )
			::print("player_connect: could not get event data.\n");

		scope.userid <- d.userid;
		scope.name <- d.name;
		scope.networkid <- d.networkid;
		::_xa9b2dfB7ffe.remove(i);
		break;
	};;

	return::OnGameEvent_player_spawn(data);
}

//-----------------------------------------------------------------------

// NOT INCLUDED IN BASE

// if something has gone wrong with automatic validation,
// force add userid. Requires player_info eventlistener
// that has the output:
// OnEventFired > player_info > RunScriptCode > VS.Events.player_info(event_data)
function VS::Events::ForceValidateUserid(ent)
{
	if( !ent || !ent.IsValid() || ent.GetClassname() != "player" )
		return::print("ForceValidateUserid: Invalid input.");

	if( !::Entc("logic_eventlistener") )
		return::print("ForceValidateUserid: No eventlistener found.");

	local proxy;

	if( !(proxy = ::VS.FindEntityByIndex(nPrxIx)) )
	{
		proxy = ::VS.CreateEntity("info_game_event_proxy", {event_name = "player_info"}, true);
		nPrxIx = proxy.entindex();
	};

	ent.ValidateScriptScope();
	_SV = ent.GetScriptScope();
	::EntFireByHandle(proxy, "generategameevent", "", 0, ent);
}

function VS::Events::player_info(data)
{
	if(_SV)
	{
		_SV.userid <- data.userid;

		if( !("name" in _SV) )
			_SV.name <- "";
		if( !("networkid" in _SV) )
			_SV.networkid <- "";

		_SV = null;
	};

	return::OnGameEvent_player_info(data);
}

::VS.Events._SV <- null;
::VS.Events.nPrxIx <- null;

if( !("OnGameEvent_player_info" in::getroottable()) )
	::OnGameEvent_player_info <- ::dummy;;
