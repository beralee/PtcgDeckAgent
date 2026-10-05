extends ColorRect
func _process(delta):
	color = Color.from_hsv(fmod(Time.get_ticks_msec()/4000.0,1.0),1,1)
