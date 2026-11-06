class_name PlayerIdentity
extends RefCounted
## coop-reconnect "Player identity": an install's random player id and its separate secret.
## The id names the player for a run; the secret proves a rejoin is really that install. Both
## are lowercase hex. The host compares secrets only as SHA-256 hashes.

const ID_LENGTH: int = 32
const SECRET_LENGTH: int = 64
const HEX_DIGITS: String = "0123456789abcdef"

var id: String = ""
var secret: String = ""


## A fresh random identity.
static func create() -> PlayerIdentity:
	var crypto := Crypto.new()
	return from(crypto.generate_random_bytes(ID_LENGTH / 2).hex_encode(), crypto.generate_random_bytes(SECRET_LENGTH / 2).hex_encode())


## An identity with these values, unchecked (see is_valid()).
static func from(player_id: String, player_secret: String) -> PlayerIdentity:
	var identity := PlayerIdentity.new()
	identity.id = player_id
	identity.secret = player_secret
	return identity


## Whether `text` is exactly `length` lowercase hex digits.
static func is_hex(text: String, length: int) -> bool:
	if text.length() != length:
		return false
	for i: int in text.length():
		if not HEX_DIGITS.contains(text[i]):
			return false
	return true


## The SHA-256 of `player_secret`, the only form in which the host keeps it.
static func hash_secret(player_secret: String) -> PackedByteArray:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(player_secret.to_utf8_buffer())
	return context.finish()


func is_valid() -> bool:
	return is_hex(id, ID_LENGTH) and is_hex(secret, SECRET_LENGTH)
