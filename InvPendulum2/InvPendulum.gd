extends Node2D

#var init = true
var barDeg = 0.0			# バー角度、単位：度
var barRotVel = 0.0
var cartPosX;
var cartVel;
var rng = RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	cartPosX = $Cart.position.x
	pass # Replace with function body.

func _physics_process(delta):
	#var br = $Bar.rotation
	var deg = $Bar.rotation_degrees
	$BarRotLabel.text = "BarR: %.1f" % deg
	#print("rot = ", deg)
	var dr = deg - barDeg
	if dr >= 180: dr -= 360
	elif dr <= -180: dr += 360
	#print("dr = ", dr)
	barRotVel = dr / delta
	$BarRotVelLabel.text = "BarRV: %.1f" % barRotVel
	#print(barRotVel)
	$CartXLabel.text = "CartX: %.1f" % $Cart.position.x
	cartVel = ($Cart.position.x - cartPosX) / delta
	$CartVLabel.text = "CartV: %.1f" % cartVel
	#
	var ax = int(Input.is_action_pressed("ui_right")) - int(Input.is_action_pressed("ui_left"))
	if ax != 0:
		print("ax = ", ax)
		$Cart.apply_central_impulse(Vector2(10*ax, 0))
	#elif init:		#abs(barRotVel) < 0.01:
	else:
		#init = false
		#if (OS.get_ticks_msec() & 1):
		if rng.randf_range(0, 1) < 0.5:
			$Cart.apply_central_impulse(Vector2(10, 0))
		else:
			$Cart.apply_central_impulse(Vector2(-10, 0))
	barDeg = deg
	cartPosX = $Cart.position.x
	pass
