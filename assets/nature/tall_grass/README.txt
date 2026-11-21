TALL GRASS (chunky style)
=========================
Each asset has:
  <name>.png             still frame
  <name>_idle_8f.png     gentle sway, 8 frames side by side (loop, ~8 FPS)
  <name>_rustle_4f.png   quick shake when walked through, 4 frames (no loop, ~12 FPS)

  tall_grass_small     16x16      tall_grass_medium   16x24
  tall_grass_wide      32x24      tall_grass_big      32x32  (good for hiding fireflies / items)
  talahib_cogon        16x32      talahib_patch       32x32  (cogon grass with white fluffy tips)
  tall_grass_flowers   16x24      (tiny pink / yellow / white flowers)
  tall_grass_dry       16x24      tall_grass_dry_wide 32x24  (dry, golden summer grass)

GODOT
-----
Use scripts/tall_grass.gd on an Area2D (see comments in the script).
Put the grass in your Y-sorted Objects node with AnimatedSprite2D Offset y = -(height / 2),
so the player is drawn BEHIND the grass when standing above it and in front when below.
Give the player's collision layer to the Area2D's mask so body_entered fires.
