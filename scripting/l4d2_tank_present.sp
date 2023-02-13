/*
*	Tank Give Present Announce
*	Copyright (C) 2023 kahdeg
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#define PLUGIN_VERSION		"1.00"

/*=======================================================================================
	Plugin Info:

*	Name	:	[L4D2] Tank Give Present
*	Author	:	kahdeg
*	Descrp	:	Tank may give whacked player a M60.
*	Link	:	
*	Plugins	:	

========================================================================================
	Change Log:

1.0 (13-Feb-2023)
	- Initial creation.

======================================================================================*/

#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>

#define CVAR_FLAGS				FCVAR_NOTIFY


#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_VALID_HUMAN(%1)		(IS_VALID_CLIENT(%1) && IsClientConnected(%1) && !IsFakeClient(%1))
#define IS_SPECTATOR(%1)        (GetClientTeam(%1) == TEAM_SPECTATOR)
#define IS_SURVIVOR(%1)         (GetClientTeam(%1) == TEAM_SURVIVOR)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == TEAM_INFECTED)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_SURVIVOR(%1)   (IS_VALID_INGAME(%1) && IS_SURVIVOR(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_VALID_SPECTATOR(%1)  (IS_VALID_INGAME(%1) && IS_SPECTATOR(%1))
#define IS_SURVIVOR_ALIVE(%1)   (IS_VALID_SURVIVOR(%1) && IsPlayerAlive(%1))
#define IS_INFECTED_ALIVE(%1)   (IS_VALID_INFECTED(%1) && IsPlayerAlive(%1))
#define IS_HUMAN_SURVIVOR(%1)   (IS_VALID_HUMAN(%1) && IS_SURVIVOR(%1))
#define IS_HUMAN_INFECTED(%1)   (IS_VALID_HUMAN(%1) && IS_INFECTED(%1))

#define MAX_CLIENTS MaxClients

#define ZC_COMMON       "infected"
#define ZC_SMOKER       "smoker"
#define ZC_BOOMER       "boomer"
#define ZC_HUNTER       "hunter"
#define ZC_JOCKEY       "jockey"
#define ZC_CHARGER      "charger"
#define ZC_WITCH        "witch"
#define ZC_TANK         8

ConVar g_hCvarAllow, g_iCvarChance;
bool g_bCvarAllow;
int g_iSavior;

// ====================================================================================================
//					PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo = 
{
	name = "[L4D2] Tank Give Present", 
	author = "kahdeg", 
	description = "Tank may give whacked player a M60.", 
	version = PLUGIN_VERSION, 
	url = ""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion test = GetEngineVersion();
	if (test != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	ConVar version = FindConVar("left4dhooks_version");
	if (version != null)
	{
		char sVer[8];
		version.GetString(sVer, sizeof(sVer));
		
		float ver = StringToFloat(sVer);
		if (ver >= 1.101)
		{
			return;
		}
	}
	
	SetFailState("\n==========\nThis plugin requires \"Left 4 DHooks Direct\" version 1.01 or newer. Please update:\nhttps://forums.alliedmods.net/showthread.php?t=321696\n==========");
}

// ==================================================
// 					PLUGIN START
// ==================================================
public void OnPluginStart()
{
	g_hCvarAllow = CreateConVar("l4d2_tank_present_enable", "1", "0=Plugin off, 1=Plugin on.", CVAR_FLAGS);
	g_iCvarChance = CreateConVar("l4d2_tank_present_chance", "1", "% chance of getting a M60 after being hit by a tank.", CVAR_FLAGS, true, 0.0, true, 100.0);
	
	CreateConVar("l4d2_tank_present_version", PLUGIN_VERSION, "Tank Give Present plugin version", FCVAR_NOTIFY | FCVAR_DONTRECORD);
	AutoExecConfig(true, "l4d2_tank_present");
	
	g_hCvarAllow.AddChangeHook(ConVarChanged_Allow);
	
	g_iSavior = -1;
	//CreateTimer(5.0, Timer_CheckSavior, _, TIMER_REPEAT);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			SDKHook(i, SDKHook_WeaponDrop, OnWeaponDrop);
		}
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponDrop, OnWeaponDrop);
}

public void OnConfigsExecuted()
{
	IsAllowed();
}

void ConVarChanged_Allow(Handle convar, const char[] oldValue, const char[] newValue)
{
	IsAllowed();
}

void IsAllowed()
{
	bool bAllow = GetConVarBool(g_hCvarAllow);
	
	if (g_bCvarAllow == false && bAllow == true)
	{
		g_bCvarAllow = true;
		HookEvents(true);
	}
	else if (g_bCvarAllow == true && bAllow == false)
	{
		g_bCvarAllow = false;
		HookEvents(false);
	}
}

void HookEvents(bool hook)
{
	if (hook)
	{
		HookEvent("player_hurt", Event_PlayerHurt);
	}
	else
	{
		UnhookEvent("player_hurt", Event_PlayerHurt);
	}
}

Action OnWeaponDrop(int clientId, int weaponEntId) {
	if (!g_bCvarAllow)return Plugin_Continue;
	if (IS_VALID_CLIENT(clientId) && g_iSavior == clientId) {
		
		//survivor pickup weapon
		if (IS_VALID_HUMAN(clientId) && IS_VALID_SURVIVOR(clientId)) {
			
			char weaponName[64];
			GetEntityClassname(weaponEntId, weaponName, sizeof(weaponName));
			if (StrEqual(weaponName, "weapon_rifle_m60")) {
				g_iSavior = -1;
				RemoveEntity(weaponEntId);
			}
		}
	}
	return Plugin_Continue;
}

void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast) {
	if (!g_bCvarAllow)return;
	int victimId = event.GetInt("userid");
	int victimClientId = GetClientOfUserId(victimId);
	int attackerId = event.GetInt("attacker");
	int attackerClientId = GetClientOfUserId(attackerId);
	
	//tank whack player
	if (IS_VALID_SURVIVOR(victimClientId) && IS_VALID_CLIENT(attackerClientId)) {
		int zClass = GetEntProp(attackerClientId, Prop_Send, "m_zombieClass");
		
		if (zClass == ZC_TANK) {
			int slot1 = GetPlayerWeaponSlot(victimClientId, 0);
			if (slot1 != -1) {
				char weaponSlot1[255];
				GetEntPropString(slot1, Prop_Data, "m_ModelName", weaponSlot1, sizeof(weaponSlot1) - 1);
				if (g_iSavior == -1 && IsWeaponTier1(weaponSlot1)) {
					SpawnM60(victimClientId);
				}
			} else {
				SpawnM60(victimClientId);
			}
		}
		
	}
}

void SpawnM60(int clientId) {
	int chance = GetRandomInt(0, 1000);
	int mul = g_iCvarChance.IntValue;
	if (chance < (10 * mul)) {
		g_iSavior = clientId;
		HxFakeCHEAT(g_iSavior, "give", "rifle_m60");
	}
}

bool IsWeaponTier1(char[] weaponModelName) {
	if (StrContains(weaponModelName, "v_pumpshotgun", false) != -1 || StrContains(weaponModelName, "v_shotgun_chrome", false) != -1 || StrContains(weaponModelName, "v_smg", false) != -1 || StrContains(weaponModelName, "v_smg_mp5", false) != -1 || StrContains(weaponModelName, "v_silenced_smg", false) != -1) {
		return true;
	}
	return false;
}

void HxFakeCHEAT(int &client, const char[] sCmd, const char[] sArg)
{
	int iFlags = GetCommandFlags(sCmd);
	SetCommandFlags(sCmd, iFlags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s", sCmd, sArg);
	SetCommandFlags(sCmd, iFlags);
} 