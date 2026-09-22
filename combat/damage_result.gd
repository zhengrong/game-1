extends RefCounted
## Domain outcome consumed by the game coordinator, with no presentation calls.
enum Kind { NONE, SHIELD, TURRET, HULL }
var kind: Kind = Kind.NONE
var destroyed: bool = false
var origin: Vector2 = Vector2.ZERO
var score: int = 0
