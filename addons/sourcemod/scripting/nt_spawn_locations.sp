#include <sourcemod>
#include <sdktools>
#include <dhooks>

#include <neotokyo>

#pragma newdecls required
#pragma semicolon 1

#define PLUGIN_VERSION "0.1.0"

char _tag[] = "[SPAWN]";

ConVar _cvar_new_spawn_allowed;

Handle _timer_rerespawn[NEO_MAXPLAYERS + 1] = { INVALID_HANDLE, ... };

public Plugin myinfo = {
	name = "Neotokyo Custom Spawn Locations",
	description = "Spawn players in custom locations in the maps",
	author = "Rain",
	version = PLUGIN_VERSION,
	url = ""
};

public void OnPluginStart()
{
	Handle gd = LoadGameConfigFile("neotokyo/spawn_locations");
	if (!gd)
	{
		SetFailState("Failed to load GameData");
	}
	DynamicDetour dd = DynamicDetour.FromConf(gd, "Fn_PlacePlayerInWorld");
	if (!dd)
	{
		SetFailState("Failed to create detour");
	}
	if (!dd.Enable(Hook_Post, PlacePlayerInWorld))
	{
		SetFailState("Failed to detour");
	}
	delete dd;
	CloseHandle(gd);

	_cvar_new_spawn_allowed = CreateConVar("sm_nt_allow_new_random_spawn", "1",
		"Whether to allow players to change their custom spawn location. \
This is useful if the player spawns in a bad location, such as outside playable area.",
		_, true, float(false), true, float(true));

	RegConsoleCmd("sm_spawn", Cmd_NewSpawn);
}

public void OnClientDisconnect_Post(int client)
{
	_timer_rerespawn[client] = INVALID_HANDLE;
}

public Action Cmd_NewSpawn(int client, int argc)
{
	if (!_cvar_new_spawn_allowed.BoolValue)
	{
		PrintToChat(client, "%s Changing spawn location has been disabled by admin",
			_tag
		);
		return Plugin_Handled;
	}

	if (_timer_rerespawn[client] != INVALID_HANDLE)
	{
		return Plugin_Handled;
	}

	if (IsPlayerDeadOrPlayingDead(client))
	{
		PrintToChat(client, "%s This command may only be used by alive players", _tag);
		return Plugin_Handled;
	}

	float respawn_delay = 5.0;
	int userid = GetClientUserId(client);
	_timer_rerespawn[client] = CreateTimer(respawn_delay, Timer_ReRespawn, userid);
	PrintToChat(client, "%s Changing location in %.1f seconds...", _tag, respawn_delay);

	ServerCommand("sm_beacon #%d", userid);

	return Plugin_Handled;
}

bool IsPlayerDeadOrPlayingDead(int client)
{
	// Check both for catching spectators and the custom nt_respawn'ers
	return !IsPlayerAlive(client) || GetClientHealth(client) == 0;
}

public Action Timer_ReRespawn(Handle timer, int userid)
{
	ServerCommand("sm_beacon #%d", userid);

	int client = GetClientOfUserId(userid);
	if (client == 0)
	{
		return Plugin_Stop;
	}
	_timer_rerespawn[client] = INVALID_HANDLE;

	if (IsPlayerDeadOrPlayingDead(client))
	{
		return Plugin_Stop;
	}

	if (!TeleportToRandomGoodLocation(client))
	{
		PrintToChat(client, "%s Failed to find a good spawn location, please try again!",
			_tag);
	}
	else
	{
		SetEntityMoveType(client, MOVETYPE_WALK);
	}
	return Plugin_Stop;
}

public MRESReturn PlacePlayerInWorld(int client)
{
	TeleportToRandomGoodLocation(client);
	return MRES_Ignored;
}

bool GetRandomPosWhereFits(const float mins[3], const float maxs[3], int mask, float out_pos[3])
{
	if (!IsValidEdict(0))  // the world must be valid!
	{
		return false;
	}

	float world_mins[3];
	float world_maxs[3];
	GetEntPropVector(0, Prop_Send, "m_WorldMins", world_mins);
	GetEntPropVector(0, Prop_Send, "m_WorldMaxs", world_maxs);
	if (VectorsEqual(world_mins, world_maxs))
	{
		return false;
	}

	int num_tries = 0, max_tries = 100;
	do {
		if (++num_tries > max_tries)
		{
			//PrintToServer("Gave up after %d tries", num_tries);
			return false;
		}
		out_pos[0] = GetURandomFloat_Range(world_mins[0], world_maxs[0]);
		out_pos[1] = GetURandomFloat_Range(world_mins[1], world_maxs[1]);
		out_pos[2] = GetURandomFloat_Range(world_mins[2], world_maxs[2]);
		TR_TraceHull(out_pos, out_pos, mins, maxs, mask);
	} while (TR_StartSolid());

	return false || SettleZWhereFits(mins, maxs, mask, out_pos);
}

bool SettleZWhereFits(const float mins[3], const float maxs[3], int mask, float mut_pos[3])
{
	float down[3] = { 90.0, 0.0, 0.0 };
	TR_TraceRay(mut_pos, down, mask, RayType_Infinite);
	if (!TR_DidHit())
	{
		//PrintToServer("No hit 1: %f %f %f -> down", mut_pos[0], mut_pos[1], mut_pos[2]);
		return false;
	}
	float end_pos[3];
	TR_GetEndPosition(end_pos);

	TR_TraceHull(mut_pos, end_pos, mins, maxs, mask);
	TR_GetEndPosition(mut_pos);
	return true;
}

bool GetSpawnLocation(int client, float pos[3], float ang[3], float vel[3])
{
	float client_mins[3];
	float client_maxs[3];
	GetClientMins(client, client_mins);
	GetClientMaxs(client, client_maxs);

	if (!GetRandomPosWhereFits(client_mins, client_maxs, MASK_PLAYERSOLID, pos))
	{
		return false;
	}

	ang[0] = 0.0;
	ang[1] = GetURandomFloat_Range(0.0, 360.0);
	ang[2] = 0.0;

	vel[0] = 0.0;
	vel[1] = 0.0;
	vel[2] = 0.0;

	return true;
}

bool TeleportToRandomGoodLocation(int client)
{
	float pos[3];
	float ang[3];
	float vel[3];
	if (GetSpawnLocation(client, pos, ang, vel))
	{
		TeleportEntity(client, pos, ang, vel);
		return true;
	}
	return false;
}

stock float GetURandomFloat_Range(float min, float max)
{
	return Lerp(min, max, GetURandomFloat());
}

// Linearly interpolate from a to b by scale.
// If scale equals zero, use GetGameFrameTime() value.
stock float Lerp(float a, float b, float scale = 0.0)
{
	if (scale == 0)
	{
		scale = GetGameFrameTime();
	}
	return a + (b - a) * scale;
}

// For vectors v1 and v2, return whether they are equal, within the max
// unit in the last place. If max_ulps equals 0, the vectors must exactly
// equal.
stock bool VectorsEqual(const float v1[3], const float v2[3],
	const float max_ulps = 0.0)
{
	return FloatEqual(v1[0], v2[0], max_ulps) &&
		FloatEqual(v1[1], v2[1], max_ulps) &&
		FloatEqual(v1[2], v2[2], max_ulps);
}

// For floats a and b, return whether they are equal within max_ulps
// units in the last place. If max_ulps equals 0, they must exactly equal.
stock bool FloatEqual(const float a, const float b, const float max_ulps = 0.0)
{
	if (max_ulps == 0)
	{
		return a == b;
	}
	return FloatAbs(a - b) <= max_ulps;
}
