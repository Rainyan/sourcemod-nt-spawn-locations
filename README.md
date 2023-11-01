# sourcemod-nt-spawn-locations
SourceMod plugin for Neotokyo. Spawn players in custom locations in the maps.

This plugin is intended to accompany the [NT Respawns plugin](https://github.com/Rainyan/sourcemod-nt-respawns) for any custom game modes where random spawn points are desired. This plugin is **not** recommended to be run on regular CTG mode NT servers.

## Build requirements
* SourceMod 1.10 or newer
  * **If you are using SourceMod older than 1.11**: you also need the [DHooks extension](https://forums.alliedmods.net/showpost.php?p=2588686) for your version of SourceMod. SM 1.11 and newer **do not require this extension**.
* The [neotokyo.inc include](https://github.com/softashell/sourcemod-nt-include/blob/master/scripting/include/neotokyo.inc), version 1.0 or newer

## Installation
* Move the compiled .smx binary to `addons/sourcemod/plugins`
* Move the gamedata file to `addons/sourcemod/gamedata/neotokyo` (create the *"neotokyo"* folder in gamedata if it doesn't exist yet)

## Configuration

#### Cvars
* sm_nt_allow_new_random_spawn
  * Default value: `1`
  * Description: `Whether to allow players to change their custom spawn location.  This is useful if the player spawns in a bad location, such as outside playable area.`
  * Min: `float(false)`
  * Max: `float(true)`


* *sm_nt_allow_new_random_spawn*
  * Whether to allow players to change their custom spawn location. This is useful if the player spawns in a bad location, such as outside playable area.
  * default: `1`, min: `0`, max: `1`

## Usage
Spawn point is chosen automatically upon (re)spawn. If allowed by `sm_nt_allow_new_random_spawn`, players may opt to change their spawn location with the `sm_spawn` command (`!spawn` in chat). The command has a delay, and incurs a beacon upon the caller, as simple means of avoiding abuse of the teleportation for gameplay advantage.
