extends Node2D

const ALPHA = 0.2
const GAMMA = 0.99

const SCREEN_WIDTH = 640
const SCREEN_CX = SCREEN_WIDTH / 2
const LR_SPC = 20
const MIN_POSX = LR_SPC
const MAX_POSX = SCREEN_WIDTH - LR_SPC
const FIELD_WIDTH2 = SCREEN_CX - LR_SPC
const MAX_STEPS = 10000.0
const N_AVG = 10
#const N_AVG = 25

const CART_POSX_STEP = 10.0
const N_POSX : int = int((SCREEN_WIDTH - LR_SPC*2) / CART_POSX_STEP)		# [20, 620) 10ピクセルごと
#const N_VEL : int = 11			#	0, 10, 20, 30, 40, 50～（プラスマイナス）
const N_VEL : int = 11			#	0, 0.2, 0.4, 0.6, 0.8, 1.0～（プラスマイナス）
const N_ANGLE : int = 9			#	-40, -30, ... 0, +10, +20, +30, +40
const N_ANGLE_VEL : int = 11		#	0, 5, 10, 15, 20, 25～（プラスマイナス）
const QT_SIZE = N_ANGLE * N_ANGLE_VEL * N_POSX * N_VEL
const QIX_POS_OFFSET = N_ANGLE * N_ANGLE_VEL * N_VEL

enum {
	ACT_LEFT = 0,
	ACT_RIGHT,
	ACT_SUM = ACT_LEFT + ACT_RIGHT,
}

var started = false;
var nSteps = 0
var nEpisode = 0
var nEpisodeRest = 0
var node = null
var cart = null		# カート
var bar = null		# 振り子バー
var barDeg = 0.0			# 振り子角度、単位：度
var barRotVel = 0.0
var cartPosX
var cartVel
var score = 0
var sumScore : float = 0.0
var center_pix = 0
var qix_org = -1
var qix0 = -1			# 前回の qix
var qix0_R = -1			# 前回の左右反転 qix、for ミラー処理
var act0 = 0
var Q = []				# Q値テーブル
var lstQIX = []			# qix 履歴
var InvPendulum = load("res://InvPendulum.tscn")
var rng = RandomNumberGenerator.new()

func init_node():
	node = InvPendulum.instance()
	add_child(node)
	cart = node.get_node("Cart")
	cartPosX = cart.position.x			# カート位置
	bar = node.get_node("Bar")
	barDeg = 0.0						# 振り子角度
	center_pix = cartPosX_to_pix(SCREEN_CX)
	
func _ready():
	rng.randomize()
	Q.resize(QT_SIZE)
	# 悲観的初期値
	#for i in range(Q.size()): Q[i] = [0.0, 0.0]		# X軸方向 0 for マイナス、1 for プラス加速度
	# 楽観的初期値
	for i in range(Q.size()): Q[i] = [1.0, 1.0]		# X軸方向 0 for マイナス、1 for プラス加速度
	init_node()
	qix_org = get_qix(SCREEN_CX, 0, 0, 0)
	print(Q[qix_org])
	pass
func get_qix(cartPosX, cartVel, deg, ddeg):
	var pix : int = clamp(round((cartPosX - MIN_POSX) / CART_POSX_STEP), 0, N_POSX-1)
	#var vix : int = clamp(round(cartVel/10.0) + 5, 0, N_VEL-1)
	var vix : int = clamp(round(cartVel*5.0) + 5, 0, N_VEL-1)
	var aix : int = clamp(round(deg / 10.0) + 4, 0, N_ANGLE-1)
	var avix : int = clamp(round(ddeg / 5.0) + 5, 0, N_ANGLE_VEL-1)
	return (((pix * N_VEL) + vix) * N_ANGLE + aix) * N_ANGLE_VEL + avix
func cartPosX_to_pix(cartPosX) -> int:
	return int(clamp(round((cartPosX - MIN_POSX) / CART_POSX_STEP), 0, N_POSX-1))
func pix_to_cartPosX(pix):
	return pix * CART_POSX_STEP + MIN_POSX
func qix_to_xvaav(qix) -> Array:
	var ddeg = (qix % N_ANGLE_VEL - 5) * 5
	qix /= N_ANGLE_VEL
	var deg = (qix % N_ANGLE - 4) * 10
	qix /= N_ANGLE
	var vel = (qix % N_VEL - 5) * 5
	qix /= N_VEL
	var posx = (qix * 10) + MIN_POSX
	return [posx, vel, deg, ddeg]
func nNotUpdated():			# 未更新Q値の数
	var n = 0
	for i in range(Q.size()):
		if Q[i][ACT_LEFT] == 1.0: n += 1
		if Q[i][ACT_RIGHT] == 1.0: n += 1
	return n
func _physics_process(delta):
	if !started: return
	nSteps += 1
	if nSteps >= MAX_STEPS:			# 最大ステップ数を超えた場合は現エピソード修了
		sumScore += nSteps
		if nEpisode % N_AVG == 0:		# 10エピソードごとにスコア、非更新率表示
			var nu = nNotUpdated()
			print("%.1f, %.1f%%" % [(sumScore / N_AVG), nu * 100.0 / (Q.size() * 2)])
			sumScore = 0
		nEpisodeRest -= 1
		if nEpisodeRest > 0:
			doStart()			# 次のエピソードを始める
		else:
			print(Q[qix_org])
			started = false
			node.queue_free()
			init_node()
		return
	$StepLabel.text = "Steps: %d" % nSteps		# ステップ数表示
	var deg = bar.rotation_degrees
	$BarRotLabel.text = "BarR: %.1f" % deg
	var ddeg = deg - barDeg		# 角度変異
	if ddeg >= 180: ddeg -= 360
	elif ddeg <= -180: ddeg += 360
	#print("ddeg = ", ddeg)
	$BarRotVelLabel.text = "BarRV: %.1f" % ddeg
	$CartXLabel.text = "CartX: %.1f" % cart.position.x
	cartVel = (cart.position.x - cartPosX)
	#cartVel = (cart.position.x - cartPosX) / delta
	$CartVLabel.text = "CartV: %.1f" % cartVel
	cartPosX = cart.position.x
	if cartPosX < MIN_POSX || cartPosX >= MAX_POSX || abs(deg) >= 45:	# 範囲外の場合は失敗
		if qix0 >= 0:
			var reward = -1.0		# マイナス報酬
			Q[qix0][act0] += ALPHA * (reward - Q[qix0][act0])
			if $Mirror.is_pressed() || $Parallel.is_pressed():
				Q[qix0_R][ACT_SUM - act0] = Q[qix0][act0]			# ミラー処理
			assert( Q[qix0][act0] >= -1.0 && Q[qix0][act0] <= 1.0 )
			#Q[qix0_R][ACT_SUM - act0] += ALPHA * (reward + Q[qix0_R][ACT_SUM - act0])
			if abs(deg) >= 45:	# 倒れた場合
				parallel_move_learning_failed(reward)		# 並行移動した状態も同様に学習
		#print("score = ", score)
		##sumScore += score
		sumScore += nSteps
		if nEpisode % N_AVG == 0:		# 10エピソードごとにスコア、非更新率表示
			var nu = nNotUpdated()
			print("%.1f, %.1f%%" % [(sumScore / N_AVG), nu * 100.0 / (Q.size() * 2)])
			#print(Q[qix_org])
			#print("avg num of steps = %.1f" % (sumScore / 10.0))
			sumScore = 0
		nEpisodeRest -= 1
		if nEpisodeRest > 0:
			doStart()
		else:
			print(Q[qix_org])
			started = false
			node.queue_free()
			init_node()
	else:		# カート位置・速度、バー角度が範囲内の場合
		var act = 0
		var qix = get_qix(cartPosX, cartVel, deg, ddeg)
		lstQIX.push_back(qix)
		if true:
			#if qix >= 0 && Q[qix][ACT_LEFT] != Q[qix][ACT_RIGHT] && rng.randf_range(0, 1) < 0.95:
			if qix >= 0 && Q[qix][ACT_LEFT] != Q[qix][ACT_RIGHT]:
				# 左右のQ値が異なる場合は、大きい方を行動とする
				act = ACT_LEFT if Q[qix][ACT_LEFT] > Q[qix][ACT_RIGHT] else ACT_RIGHT
			else:		# 左右のQ値が等しい場合は、乱数で行動を決める
				act = ACT_LEFT if rng.randf_range(0, 1) < 0.5 else ACT_RIGHT
		else:
			act = ACT_LEFT if rng.randf_range(0, 1) < 0.5 else ACT_RIGHT
		if act == ACT_LEFT:
			cart.apply_central_impulse(Vector2(-20, 0))	# 左方向加速度
		else:
			cart.apply_central_impulse(Vector2(20, 0))	# 右方向加速度
		var reward0 = 1.0 if abs(bar.rotation_degrees) <= 5 else 0.0	# バーがプラマイ５以内なら、報酬 +1.0
		# 位置が中央から外れている場合は、報酬をへらす 300 → 0.3
		var reward = reward0 - abs(cartPosX - SCREEN_CX) / 1000.0
		if qix >= 0 && qix0 >= 0:
			#var reward = 0
			var maxQ = Q[qix].max()
			var t = min(1.0, reward + GAMMA * maxQ)
			Q[qix0][act0] += ALPHA * (t - Q[qix0][act0])	# Q値更新
			#Q[qix0][act0] += ALPHA * (reward + GAMMA * maxQ - Q[qix0][act0])
			if $Mirror.is_pressed() || $Parallel.is_pressed():
				Q[qix0_R][ACT_SUM - act0] = Q[qix0][act0]		# ミラー処理
			#Q[qix0_R][ACT_SUM - act0] += ALPHA * (reward + GAMMA * maxQ - Q[qix0_R][ACT_SUM - act0])
			if Q[qix0][act0] < -1.0 || Q[qix0][act0] > 1.0: print(Q[qix0][act0])
			assert( Q[qix0][act0] >= -1.1 && Q[qix0][act0] <= 1.1 )
			Q[qix0][act0] = clamp(Q[qix0][act0], -1.0, 1.0)
			# 並行移動した状態についても学習
			parallel_move_learning(qix, reward0)
		act0 = act
		qix0 = qix
		qix0_R = get_qix(SCREEN_WIDTH - cartPosX, -cartVel, -deg, -ddeg)	# ミラー処理のために、qix を保存しておく
func parallel_move_learning(qix, reward0):
	if !$Parallel.is_pressed(): return
	var qx = qix - QIX_POS_OFFSET
	var qx0 = qix0 - QIX_POS_OFFSET
	var cx = cartPosX - CART_POSX_STEP
	var qx0R = qix0_R + QIX_POS_OFFSET
	while qx >= 0 && qx0 >= 0:
		var reward = reward0 - abs(cartPosX - SCREEN_CX) / 1000.0		# 300 → 0.3
		var t2 = min(1.0, reward + GAMMA * Q[qx].max())
		Q[qx0][act0] += ALPHA * (t2 - Q[qx0][act0])
		if qx0R < Q.size():
			Q[qx0R][ACT_SUM - act0] = Q[qx0][act0]
		qx -= QIX_POS_OFFSET
		qx0 -= QIX_POS_OFFSET
		cx -= CART_POSX_STEP
		qx0R += QIX_POS_OFFSET
	qx = qix + QIX_POS_OFFSET
	qx0 = qix0 + QIX_POS_OFFSET
	cx = cartPosX + CART_POSX_STEP
	qx0R = qix0_R - QIX_POS_OFFSET
	while qx < Q.size() && qx0 < Q.size():
		var reward = reward0 - abs(cartPosX - SCREEN_CX) / 1000.0		# 300 → 0.3
		var t2 = min(1.0, reward + GAMMA * Q[qx].max())
		Q[qx0][act0] += ALPHA * (t2 - Q[qx0][act0])
		Q[qx0R][ACT_SUM - act0] = Q[qx0][act0]
		qx += QIX_POS_OFFSET
		qx0 += QIX_POS_OFFSET
		cx += CART_POSX_STEP
		qx0R -= QIX_POS_OFFSET
func parallel_move_learning_failed(reward):
	if !$Parallel.is_pressed(): return
	var qx0 = qix0 - QIX_POS_OFFSET
	var qx0R = qix0_R + QIX_POS_OFFSET
	while qx0 >= 0:
		Q[qx0][act0] += ALPHA * (reward - Q[qx0][act0])
		#Q[qx0R][ACT_SUM - act0] = Q[qx0][act0]
		qx0 -= QIX_POS_OFFSET
		#qx0R += QIX_POS_OFFSET
	qx0 = qix0 + QIX_POS_OFFSET
	while qx0 < Q.size():
		Q[qx0][act0] += ALPHA * (reward - Q[qx0][act0])
		qx0 += QIX_POS_OFFSET
	pass
func doStart():
	node.queue_free()
	init_node()
	nEpisode += 1
	$RoundLabel.text = "Episode: #%d" % nEpisode
	score = 0
	qix0 = -1
	started = true
	nSteps = 0
	lstQIX = []			# qix 履歴クリア
	
func _on_RestartButton_pressed():
	doStart()
	pass # Replace with function body.


func _on_100RoundButton_pressed():
	nEpisodeRest = 100
	doStart()
	pass # Replace with function body.


func _on_1000RoundButton_pressed():
	nEpisodeRest = 1000
	doStart()
	pass # Replace with function body.


func _on_10000RoundButton_pressed():
	nEpisodeRest = 10000
	doStart()
	pass # Replace with function body.


func _on_Mirror_toggled(button_pressed):
	if button_pressed: $Parallel.set_pressed(false)
	pass # Replace with function body.


func _on_Parallel_toggled(button_pressed):
	if button_pressed: $Mirror.set_pressed(false)
	pass # Replace with function body.
