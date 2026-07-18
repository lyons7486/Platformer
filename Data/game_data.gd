extends Node

# Games Save Data Goes Here
var save_data = {
	"Save_001":{
		# Data for each player goes here, like health, equipment, talent points, etc. This is what updates the Status UIs
		"PlayerData":{
			"Player_01":{
				"Health":10,
				"Weapon":{
					"Name":"Rifle",
					"Ammo":20
				}
			},
			"Player_02":{},
			"Player_03":{},
			"Player_04":{}
		},
		# World progress data goes here so when save is loaded back up players may continue
		"WorldData":{
			"Map":"",
			"Waypoint":""
		}
	}
}
