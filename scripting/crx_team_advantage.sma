#include <amxmodx>
#include <amxmisc>
#include <cromchat>
#include <cstrike>

#define PLUGIN_VERSION "1.0"

enum
{
	SECTION_NONE = 0,
	SECTION_SETTINGS,
	SECTION_ADVANTAGES
}

enum _:Settings
{
	CsTeams:ADVANTAGE_TEAM,
	ADVANTAGE_FLAGS[32],
	bool:ADVANTAGE_USE_FLAGS,
	MAX_MONEY,
	bool:PLAYER_MESSAGE
}

new g_eSettings[Settings]

new Array:g_aLoses,
	Array:g_aMoney,
	bool:g_bRoundEnd,
	g_iLoses[CsTeams:3],
	g_iAdvantages

public plugin_init()
{
	register_plugin("Team Advantage", PLUGIN_VERSION, "OciXCrom")
	register_cvar("CRXTeamAdvantage", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY|FCVAR_UNLOGGED)
	register_dictionary("TeamAdvantage.txt")
	register_logevent("OnFirstRound", 2, "0=World triggered", "1&Restart_Round_")
	register_logevent("OnFirstRound", 2, "0=World triggered", "1=Game_Commencing")
	register_logevent("OnRoundStart", 2, "0=World triggered", "1=Round_Start")
	register_event("SendAudio", "OnTeamWin", "a", "2&%!MRAD_terwin", "2&%!MRAD_ctwin")
	g_aLoses = ArrayCreate(5)
	g_aMoney = ArrayCreate(8)
	ReadFile()
}

public plugin_end()
{
	ArrayDestroy(g_aLoses)
	ArrayDestroy(g_aMoney)
}

public OnFirstRound()
{
	g_iLoses[CS_TEAM_CT] = 0
	g_iLoses[CS_TEAM_T] = 0
}

public OnRoundStart()
	g_bRoundEnd = false

public OnTeamWin()
{
	if(g_bRoundEnd)
		return
		
	g_bRoundEnd = true
	
	new szTeam[9]
	read_data(2, szTeam, charsmax(szTeam))
	
	new CsTeams:iWinTeam = szTeam[7] == 'c' ? CS_TEAM_CT : CS_TEAM_T,
		CsTeams:iLoseTeam = iWinTeam == CS_TEAM_CT ? CS_TEAM_T : CS_TEAM_CT
	
	g_iLoses[iLoseTeam]++
	g_iLoses[iWinTeam] = 0
	
	if(g_eSettings[ADVANTAGE_TEAM] != CS_TEAM_UNASSIGNED && g_eSettings[ADVANTAGE_TEAM] != iLoseTeam)
		return
	
	new iMoney
	
	for(new i; i < g_iAdvantages; i++)
	{
		if(g_iLoses[iLoseTeam] == ArrayGetCell(g_aLoses, i))
		{
			iMoney = ArrayGetCell(g_aMoney, i)
			break
		}
	}
	
	if(!iMoney)
		return
		
	new iPlayers[32], iPnum
	get_players(iPlayers, iPnum, "e", iLoseTeam == CS_TEAM_CT ? "CT" : "TERRORIST")
	
	if(g_eSettings[ADVANTAGE_USE_FLAGS])
		CC_SendMessage(0, "%L", LANG_PLAYER, "ADVANTAGE_GET_FLAGS", g_eSettings[ADVANTAGE_FLAGS], LANG_PLAYER, iLoseTeam == CS_TEAM_CT ? "ADVANTAGE_TEAM_CT" : "ADVANTAGE_TEAM_T", iMoney, g_iLoses[iLoseTeam])
	else
		CC_SendMessage(0, "%L", LANG_PLAYER, "ADVANTAGE_GET_NORMAL", LANG_PLAYER, iLoseTeam == CS_TEAM_CT ? "ADVANTAGE_TEAM_CT" : "ADVANTAGE_TEAM_T", iMoney, g_iLoses[iLoseTeam])		
	
	for(new iPlayer, i; i < iPnum; i++)
	{
		iPlayer = iPlayers[i]
		
		if(g_eSettings[ADVANTAGE_USE_FLAGS] && !has_all_flags(iPlayer, g_eSettings[ADVANTAGE_FLAGS]))
			continue
			
		cs_set_user_money(iPlayers[i], clamp(cs_get_user_money(iPlayer) + iMoney, .max = g_eSettings[MAX_MONEY]))
		
		if(g_eSettings[PLAYER_MESSAGE])
			CC_SendMessage(iPlayer, "%L", iPlayer, "ADVANTAGE_GET_PLAYER", iMoney, g_iLoses[iLoseTeam])
	}
}

ReadFile()
{
	new szConfigsName[256], szFilename[256]
	get_configsdir(szConfigsName, charsmax(szConfigsName))
	formatex(szFilename, charsmax(szFilename), "%s/TeamAdvantage.ini", szConfigsName)
	
	new iFilePointer = fopen(szFilename, "rt")
	
	if(iFilePointer)
	{
		new szData[64], szKey[32], szValue[32], iNum, iSection = SECTION_NONE
		
		while(!feof(iFilePointer))
		{
			fgets(iFilePointer, szData, charsmax(szData))
			trim(szData)
			
			switch(szData[0])
			{
				case EOS, ';': continue
				case '[':
				{
					iNum = strlen(szData)
					
					if(szData[iNum - 1] == ']')
					{
						switch(szData[1])
						{
							case 'S', 's': iSection = SECTION_SETTINGS
							case 'A', 'a': iSection = SECTION_ADVANTAGES
						}
					}
					else continue
				}
				default:
				{
					strtok(szData, szKey, charsmax(szKey), szValue, charsmax(szValue), '=')
					trim(szKey); trim(szValue)
					
					if(!szValue[0])
						continue
						
					switch(iSection)
					{
						case SECTION_SETTINGS:
						{
							if(equal(szKey, "ADVANTAGE_TEAM"))
							{
								switch(szValue[0])
								{
									case 'C', 'c': g_eSettings[ADVANTAGE_TEAM] = CS_TEAM_CT
									case 'T', 't': g_eSettings[ADVANTAGE_TEAM] = CS_TEAM_T
									default: g_eSettings[ADVANTAGE_TEAM] = CS_TEAM_UNASSIGNED
								}
							}
							else if(equal(szKey, "ADVANTAGE_FLAGS"))
							{
								if(szValue[0] != '!')
								{
									g_eSettings[ADVANTAGE_USE_FLAGS] = true
									copy(g_eSettings[ADVANTAGE_FLAGS], charsmax(g_eSettings[ADVANTAGE_FLAGS]), szValue)
								}
							}
							else if(equal(szKey, "MAX_MONEY"))
								g_eSettings[MAX_MONEY] = str_to_num(szValue)
							else if(equal(szKey, "CHAT_PREFIX"))
								CC_SetPrefix(szValue)
							else if(equal(szKey, "PLAYER_MESSAGE"))
								g_eSettings[PLAYER_MESSAGE] = _:clamp(str_to_num(szValue), false, true)
						}
						case SECTION_ADVANTAGES:
						{
							iNum = str_to_num(szKey)
							ArrayPushCell(g_aLoses, iNum)
							
							iNum = str_to_num(szValue)
							ArrayPushCell(g_aMoney, iNum)
							
							g_iAdvantages++
						}
					}
				}
			}
		}
		
		fclose(iFilePointer)
	}
}