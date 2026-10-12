extends RefCounted
## De nieuwe uitrusting volgt hetzelfde 16x16-pixelraster als de bestaande iconen.
## Een klein atlas uit rechthoeken blijft scherp op iedere menuschaal.

const INK := Color("263747")
const CLOTH := Color("7ba798")
const LEATHER := Color("a9784c")
const COPPER := Color("d39458")
const IRON := Color("99b6c8")
const LIGHT := Color("e3eef3")
const CRYSTAL := Color("65d3eb")


static func texture() -> Texture2D:
	var atlas := Image.create_empty(160, 16, false, Image.FORMAT_RGBA8)
	for index in 10:
		var x := index * 16
		var upgraded := index % 2 == 1
		match index / 2:
			0:
				# Kap of metalen helm, met een open gezicht.
				_rect(atlas, x, 3, 2, 10, 12, INK)
				_rect(atlas, x, 4, 3, 8, 10, COPPER if upgraded else CLOTH)
				_rect(atlas, x, 5, 6, 6, 7, INK)
				_rect(atlas, x, 5, 4, 6, 2, LIGHT if upgraded else Color("aac8b6"))
				if upgraded:
					_rect(atlas, x, 7, 2, 2, 9, COPPER)
					_rect(atlas, x, 7, 3, 1, 6, LIGHT)
			1:
				# Schouders, halsopening en een riem onderscheiden het borststuk.
				_rect(atlas, x, 1, 3, 14, 6, INK)
				_rect(atlas, x, 3, 7, 10, 8, INK)
				_rect(atlas, x, 2, 4, 12, 3, IRON if upgraded else LEATHER)
				_rect(atlas, x, 4, 6, 8, 8, IRON if upgraded else LEATHER)
				_rect(atlas, x, 6, 3, 4, 3, INK)
				_rect(atlas, x, 4, 11, 8, 2, Color("536877") if upgraded else Color("6a4937"))
				_rect(atlas, x, 7, 11, 2, 2, COPPER)
				_rect(atlas, x, 4, 6, 2, 4, LIGHT if upgraded else Color("cc9a62"))
			2:
				# Twee handschoenen, elk met zichtbare duim en manchet.
				for hand in [1, 9]:
					_rect(atlas, x, hand, 3, 5, 11, INK)
					_rect(atlas, x, hand - 1, 7, 2, 4, INK)
					_rect(atlas, x, hand + 1, 4, 3, 8, IRON if upgraded else LEATHER)
					_rect(atlas, x, hand, 7, 2, 3, IRON if upgraded else LEATHER)
					_rect(atlas, x, hand + 1, 11, 3, 2, COPPER if upgraded else CLOTH)
					_rect(atlas, x, hand + 1, 4, 1, 4, LIGHT if upgraded else Color("cc9a62"))
			3:
				# Ketting rond de hals met een hangende edelsteen.
				_rect(atlas, x, 3, 1, 2, 7, INK)
				_rect(atlas, x, 11, 1, 2, 7, INK)
				_rect(atlas, x, 4, 2, 1, 6, COPPER)
				_rect(atlas, x, 11, 2, 1, 6, LIGHT if upgraded else COPPER)
				_rect(atlas, x, 5, 7, 6, 2, COPPER)
				_rect(atlas, x, 5, 9, 6, 6, INK)
				_rect(atlas, x, 6, 10, 4, 4, CRYSTAL if upgraded else COPPER)
				_rect(atlas, x, 7, 10, 1, 2, LIGHT)
			4:
				# Een open ring met de steen bovenop, geen dicht munt-icoon.
				_rect(atlas, x, 3, 5, 10, 9, INK)
				_rect(atlas, x, 4, 6, 8, 7, IRON if upgraded else COPPER)
				_rect(atlas, x, 6, 8, 4, 3, INK)
				_rect(atlas, x, 6, 2, 5, 5, INK)
				_rect(atlas, x, 7, 3, 3, 3, CRYSTAL if upgraded else Color("e7bf69"))
				_rect(atlas, x, 7, 3, 1, 1, LIGHT)
	return ImageTexture.create_from_image(atlas)


static func _rect(atlas: Image, origin: int, x: int, y: int, width: int, height: int, color: Color) -> void:
	atlas.fill_rect(Rect2i(origin + x, y, width, height), color)
