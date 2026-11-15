class_name NetFailure
extends RefCounted
## net-platform "Failure reasons": why a host or join request failed. Enum holder only, because
## the NetManager autoload may declare no enum (core-services). Each reason's line, Spanish first
## with English beside, lives in game/resources/net_backends.tres; NONE and CANCELLED have none.

enum Reason {
	NONE,
	UNREACHABLE,
	TIMED_OUT,
	FULL,
	NOT_FOUND,
	CANCELLED,
	UNSUPPORTED,
	PLATFORM_UNAVAILABLE,
	NOT_SIGNED_IN,
	NO_PRIVILEGE,
	PORT_UNAVAILABLE,
	HOST_LEFT,
	INVALID_TARGET,
}
