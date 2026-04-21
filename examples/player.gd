extends CharacterBody2D
class_name Player


@export var speed: int = 10
@export var push_strength: int = 75
@export var knockback_strength: float = 200
@export var acceleration: float = 5

@onready var animated_sprite = $AnimatedSprite2D

var is_attacking: bool = false
var can_interact: bool = false

func _ready() -> void:
	position = SceneManager.player_spawn_position
	update_treasure_label()
	update_player_hp()
	

func _physics_process(_delta):
	if SceneManager.player_hp <= 0:
		return
	
	if not is_attacking:
		move_player()
	push_blocks()
	update_treasure_label()
	
	if Input.is_action_just_pressed("interact") and not can_interact:
		attack()

	move_and_slide()
	
func update_treasure_label():
	var treasure_amount: int = SceneManager.opened_chests.size()
	%TreasureLabel.text = str(treasure_amount)

func move_player():
	var move_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	
	velocity = velocity.move_toward(move_vector*speed, acceleration)
	
	if velocity.x > 0:
		$InteractArea2D.position = Vector2(7, 2)
		animated_sprite.play("move_right")
	elif velocity.x < 0:
		$InteractArea2D.position = Vector2(-7, 2)
		animated_sprite.play("move_left")
	elif velocity.y < 0:
		$InteractArea2D.position = Vector2(0, -6)
		animated_sprite.play("move_up")
	elif velocity.y > 0:
		$InteractArea2D.position = Vector2(0, 8)
		animated_sprite.play("move_down")
	else:
		animated_sprite.stop()

func push_blocks():
	var collision: KinematicCollision2D = get_last_slide_collision()
	if collision:
		var collider_node = collision.get_collider()
		if collider_node.is_in_group("pushable"):
			var collision_normal: Vector2 = collision.get_normal()
			collider_node.apply_central_force(-collision_normal * push_strength)
	


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body.is_in_group("interactable"):
		can_interact = true
		body.can_interact = true


func _on_area_2d_body_exited(body: Node2D) -> void:
	if body.is_in_group("interactable"):
		can_interact = false
		body.can_interact = false


func _on_hitbox_area_2d_body_entered(body: Node2D) -> void:
	$DamageSFX.play()
	SceneManager.player_hp -= 1
	update_player_hp()
	if SceneManager.player_hp <= 0:
		die()
	else:
		print(SceneManager.player_hp)
	
	var distance_to_player: Vector2 = global_position - body.global_position
	var knockback_direction: Vector2 = distance_to_player.normalized()
	
	velocity += knockback_direction * knockback_strength
	
	var flash_white_color: Color = Color(50, 50, 50)
	modulate = flash_white_color
	await get_tree().create_timer(0.2).timeout
	var original_color: Color = Color(1,1,1)
	modulate = original_color


func die():
	$AnimatedSprite2D.play("death")
	if $DeathTimer.is_stopped():
		$DeathTimer.start()
	
func update_player_hp():
	if SceneManager.player_hp >= 3:
		%HPBar.play("3_hp")
	elif SceneManager.player_hp == 2:
		%HPBar.play("2_hp")
	elif SceneManager.player_hp == 1:
		%HPBar.play("1_hp")
	else:
		%HPBar.play("0_hp")


func _on_sword_area_2d_body_entered(body: Node2D) -> void:
	var distance_to_enemy: Vector2 = body.global_position - global_position
	var knockback_direction: Vector2 = distance_to_enemy.normalized()
	
	body.velocity += knockback_direction * knockback_strength
	
	body.take_damage()
	


func attack():
	if not $AttackDurationTimer.is_stopped():
		return
	
	$Sword.visible = true
	$Sword/SwordArea2D.monitoring = true
	$AttackDurationTimer.start()
	is_attacking = true
	velocity = Vector2(0,0)
	$SwordSFX.play()
	
	var player_animation: String = $AnimatedSprite2D.animation
	if player_animation == "move_up":
		$AnimatedSprite2D.play("attack_up")
		$AnimationPlayer.play("attack_up")
	elif player_animation == "move_down":
		$AnimatedSprite2D.play("attack_down")
		$AnimationPlayer.play("attack_down")
	elif player_animation == "move_right":
		$AnimatedSprite2D.play("attack_right")
		$AnimationPlayer.play("attack_right")
	elif player_animation == "move_left":
		$AnimatedSprite2D.play("attack_left")
		$AnimationPlayer.play("attack_left")

func _on_attack_duration_timer_timeout() -> void:
	$Sword.visible = false
	$Sword/SwordArea2D.monitoring = false
	is_attacking = false
	
	var player_animation: String = $AnimatedSprite2D.animation
	
	if player_animation == "attack_up":
		$AnimatedSprite2D.play("move_up")
	elif player_animation == "attack_down":
		$AnimatedSprite2D.play("move_down")
	elif player_animation == "attack_right":
		$AnimatedSprite2D.play("move_right")
	elif player_animation == "attack_left":
		$AnimatedSprite2D.play("move_left")
	

func _on_death_timer_timeout() -> void:
	SceneManager.player_hp = 3
	get_tree().call_deferred("reload_current_scene")
