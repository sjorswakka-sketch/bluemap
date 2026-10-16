extends RefCounted
const SOUNDS:=["orchard_pick"]
const ITEMS:={
 "or_carrot_seed":{"name":"Wortelzaad","type":"material","sheet":"items_orchard","icon":0,"desc":"Voor snelle wortelrijen. De volledige oogst geeft één zakje zaad terug voor opnieuw planten."},
 "or_pumpkin_seed":{"name":"Pompoenzaad","type":"material","sheet":"items_orchard","icon":1,"desc":"Voor een lage pompoenplant op één tegel. Oogsten geeft één zakje zaad terug."},
 "or_mint_seed":{"name":"Muntstek","type":"material","sheet":"items_orchard","icon":2,"desc":"Plant een blijvend kruid. Bloeiende munt voedt bijen; geplukte munt is voor thee."},
 "or_rosemary_seed":{"name":"Rozemarijnstek","type":"material","sheet":"items_orchard","icon":3,"desc":"Plant een blijvend kruid. De bloei voedt bijen; blaadjes zijn voor rozemarijnbalsem."},
 "or_apple_seed":{"name":"Appelboompje","type":"material","sheet":"items_orchard","icon":4,"desc":"Plant op bewerkte grond met drie bij drie tegels vrije kroonruimte. Aangesloten water binnen twee tegels voedt de wortels."},
 "or_berry_seed":{"name":"Bosbessenstek","type":"material","sheet":"items_orchard","icon":5,"desc":"Een lage, blijvende struik op één tegel. Levert dezelfde bosbessen als de bestaande wilde planten."},
 "or_carrot":{"name":"Tuinwortel","type":"use","heal":1,"sheet":"items_orchard","icon":6,"desc":"Een verse wortel herstelt één hartje. Met pompoen en zilverkruid bruikbaar voor tuinstoofpot."},
 "or_pumpkin":{"name":"Tuinpompoen","type":"material","sheet":"items_orchard","icon":7,"desc":"Een stevige groente uit je eigen tuin. Maak tuinstoofpot in de bestaande herbergkeuken."},
 "or_mint":{"name":"Tuinmuntblaadjes","type":"material","sheet":"items_orchard","icon":8,"desc":"Eigen munt voor honing-muntthee in de herberg. De wilde watermunt uit het moeras behoudt zijn eigen recepten."},
 "or_rosemary":{"name":"Rozemarijnblaadjes","type":"material","sheet":"items_orchard","icon":9,"desc":"Eigen kruid voor rozemarijnbalsem bij Lena's alchemietafel."},
 "or_apple":{"name":"Tuinappel","type":"use","heal":1,"stamina":10,"sheet":"items_orchard","icon":10,"desc":"Vers fruit van je eigen boom. Herstelt één hartje en tien stamina; de boom draagt opnieuw vrucht."},
 "or_stew":{"name":"Tuinstoofpot","type":"use","heal":3,"stamina":20,"sheet":"items_orchard","icon":11,"desc":"Pompoen, wortels en zilverkruid uit de herbergkeuken. Herstelt drie hartjes en twintig stamina."},
 "or_tea":{"name":"Honing-muntthee","type":"use","heal":1,"stamina":45,"sheet":"items_orchard","icon":12,"desc":"Tuinmunt met bloemenhoning, gezet in de herberg. Herstelt één hartje en 45 stamina."},
 "or_balm":{"name":"Rozemarijnbalsem","type":"use","heal":3,"sheet":"items_orchard","icon":13,"desc":"Rozemarijn, zilverkruid en honing van de alchemietafel. Herstelt drie hartjes."}
}
