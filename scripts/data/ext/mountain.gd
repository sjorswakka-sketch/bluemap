extends RefCounted
## A quiet northern mountain, authored around four accessible snow terraces.
const MAPS:={"steampeak":preload("res://scripts/maps/steampeak.gd")}
const ENEMIES:={"trail_macaque":{"name":"Roodkopaap","hp":4,"damage":0,"behavior":"animal","speed":20.0,"chase_speed":48.0,"sight":80.0,"panic_range":40.0,"sheet":"snow_macaque","cell":16,"scale":2.0,"radius":5.0,"shadow":7.0,"drops":[],"desc":"Een vreedzame roodkopaap met dikke wintervacht. De familie scharrelt rond de warme bronnen van Dampkroon."}}
const OBJECTS:={"mountain_scenery":"res://scripts/entities/mountain_scenery.gd"}
