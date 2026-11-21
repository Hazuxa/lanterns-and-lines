GRASS TUFTS (fan-shaped, like your reference) - 16 variants
===========================================================
Blades grow from one narrow, rounded base and fan outwards. Bright layered greens, no outline.
Each variant:  <name>.png (still)  |  <name>_idle_8f.png (sway)  |  <name>_rustle_4f.png (walk-through shake)

  grass_tuft_small 16x14      grass_tuft 16x18           grass_tuft_tall 16x24
  grass_tuft_wide 24x20       grass_tuft_big 24x28       grass_tuft_huge 32x34
  grass_tuft_spring 16x18 (light green)   grass_tuft_forest 16x20 (dark green)
  grass_tuft_teal 16x18 (blue-green)      grass_tuft_dry 16x18 / grass_tuft_dry_tall 24x26 (golden)
  grass_tuft_flowers_pink / _yellow / _white 16x20
  talahib_tuft 16x30 / talahib_tuft_big 24x34 (cogon with white plumes)

GODOT: same setup as before - Area2D + AnimatedSprite2D ("idle" = _idle_8f, 8 frames, 8 FPS, loop;
"rustle" = _rustle_4f, 4 frames, 12 FPS, no loop) + CollisionShape2D at the base +
tall_grass.gd (included). AnimatedSprite2D Offset y = -(height / 2).
For grass that never moves, just use the still <name>.png in a Sprite2D.
