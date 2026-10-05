extends RefCounted
## Find a nearby empty screen-space pocket. Never move the board to fit speech.
static func find_slot(bounds: Rect2, wanted: Vector2, preferred: Vector2, obstacles: Array[Rect2]) -> Rect2:
	if wanted.x > bounds.size.x or wanted.y > bounds.size.y: return Rect2()
	var xs := [preferred.x, bounds.position.x, bounds.end.x - wanted.x]
	var ys := [preferred.y, bounds.position.y, bounds.end.y - wanted.y]
	for obstacle: Rect2 in obstacles:
		xs.append(obstacle.end.x + 2.0)
		xs.append(obstacle.position.x - wanted.x - 2.0)
		ys.append(obstacle.end.y + 2.0)
		ys.append(obstacle.position.y - wanted.y - 2.0)
	var best := Rect2()
	var score := INF
	for x: float in xs:
		if x < bounds.position.x or x + wanted.x > bounds.end.x: continue
		for y: float in ys:
			if y < bounds.position.y or y + wanted.y > bounds.end.y: continue
			var at := Vector2(x, y)
			var distance := at.distance_squared_to(preferred)
			if distance >= score: continue
			var candidate := Rect2(at, wanted)
			var clear := true
			for obstacle: Rect2 in obstacles:
				if candidate.intersects(obstacle):
					clear = false
					break
			if clear:
				best = candidate
				score = distance
	return best
