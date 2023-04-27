
SPATHS = {
  blue_ship: "sprites/ships/ship_0000.png",
  red_ship: "sprites/ships/ship_0001.png",
  single_bullet: "sprites/tiles/tile_0000.png",
  tank: "sprites/tiles/tile_0028.png",
  tank_base: "sprites/tiles/tile_0029.png",
  tank_top: "sprites/tiles/tile_0030.png",
  tank_explosion: "sprites/tiles/tile_0007.png",
  tank_bullet: "sprites/tiles/tile_0003.png",
  tileset: "sprites/tilemap/tiles.png",
}

WORLD_W = 256
CANVAS_W = 192
CANVAS_H = 240
CAMERA_RATIO = CANVAS_W / WORLD_W

def tick args
  # 12 x 15 grid, 16x16 tiles
  # world is 16 wide
  
  args.state.canvas ||= DRT::LowResolutionCanvas.new([CANVAS_W, CANVAS_H])
  scale = 1
  c = {x: 127, y: 32}
  
  args.state.file ||= (args.gtk.parse_json_file "LDtk/bullet-limbo.ldtk").deep_symbolize_keys
  args.state.level ||= args.state.file.levels.first
  args.state.enemy_instances ||= args.state.level.layerInstances.find do |l|
    l.__identifier == "Enemies"
  end.entityInstances
  args.state.tiles ||= args.state.level.layerInstances.find do |l|
    l.__identifier == "Terrain"
  end.autoLayerTiles
  
  h = args.state.level.pxHei

  ## Create Tanks
  args.state.enemies ||= args.state.enemy_instances.map do |e|
    {
      x: e.px.first,
      y: h - e.px.second,
      w: 16,
      h: 16,
      angle: 0,
      anchor_x: 0.5,
      anchor_y: 0.5,
      health: 2,
    }
  end

  ## Create Level Map Tiles
  
  args.state.bg ||= args.state.tiles.map do |t|
    {
      x: t.px.first,
      y: h - t.px.second - 16,
      w: 16,
      h: 16,
      path: SPATHS.tileset,
      tile_x: t.src.first,
      tile_y: t.src.second,
      tile_w: 16,
      tile_h: 16,
      flip_horizontally: (t.f & 1 << 0).pos?,
      flip_vertically: (t.f & 1 << 1).pos?,
    }
  end
  
  args.state.player ||= {
    x: c.x,
    y: 0,
    ry: c.y,
    wy: 0,
    h: 8,
    w: 8,
    anchor_x: 0.5,
    anchor_y: 0.5,
  }
  args.state.bullets ||= []
  args.state.enemy_bullets ||= []
  
  # Input Handling
  
  args.state.input ||= InputController.new
  args.state.input.update args
  dir = args.state.input.directional_vector
  
  # Updates
  
  player = args.state.player
  if player.hit_at && args.state.tick_count - player.hit_at > 90
    player.hit_at = nil
    args.state.enemy_bullets = []
  elsif player.hit_at
    d = c.x - player.x
    player.x += (c.x - player.x).sign * 2 unless d.abs < 2
  end
  player_active = !player.hit_at
  player.wy += 0.5 if player.wy < h - CANVAS_H
  
  if player_active && dir
    speed = 2
    player.x = (player.x + dir.x * speed)
                 .clamp(0, WORLD_W)
    player.ry = (player.ry + dir.y * speed)
                  .clamp(0, CANVAS_H)
  end
  player.y = player.wy + player.ry
  
  if player_active && args.state.input.shoot?
    args.state.bullets << {
      x: player.x.round,
      y: (player.y + player.h / 2).round,
      w: 8,
      h: 16,
      anchor_x: 0.5,
      anchor_y: 0.5,
      path: SPATHS.single_bullet
    }
  end


  # Select enemies
  
  in_enemies = args.state.enemies.filter do |e|
    (e.y > (player.wy - 16) && e.y < (player.wy + CANVAS_H + 16))
  end
    
  # Process Existing Bullets

  args.state.bullets.each do |b|
    b.y += 6
    args.state.bullets.delete b unless b.y < player.wy + CANVAS_H + 8
  end
  
  args.state.bullets.each do |b|
    in_enemies.each do |e|
      if b.intersect_rect? e
        e.health -= 1
        args.state.bullets.delete b
        args.state.enemies.delete e if e.health < 1
      end
    end
  end

  args.state.enemy_bullets.each do |b|
    v = (b.angle).to_vector
    b.x += v.x
    b.y += v.y
    
    args.state.enemy_bullets.delete b unless b.y < player.wy + CANVAS_H + 8

    if player_active && (b.intersect_rect? player)
      player.hit_at = args.state.tick_count
      player.ry = c.y
      args.state.enemy_bullets.delete b
    end
  end

  # Process Enemies

  in_enemies.each do |e|
    target = player.dup
    distance = args.geometry.distance target, e
    target.y += distance / 2
    
    e.target_angle = (e.angle_to target).round
    e.angle = e.target_angle + 90

    if args.state.tick_count % 60 == 0 \
       && e.health > 1 \
       && (args.geometry.distance player, e) > 64
      args.state.enemy_bullets << {
        x: e.x,
        y: e.y,
        w: 8,
        h: 8,
        anchor_x: 0.5,
        anchor_y: 0.5,
        angle: e.target_angle,
      }
    end
  end

  # Rendering
  # when player is at 0, offset should be 0
  # when player is at 256, offset should be 64 (256 - 192)
  
  cam_ratio = CAMERA_RATIO - 1
  camera = {
    x: (player.x * (CAMERA_RATIO - 1)).round,
    y: -player.wy
  }
 
  sprites = []
  
  sprites << args.state.bg.filter_map do |t|
    if (t.y > (player.wy - 16) && t.y < (player.wy + CANVAS_H))
      t.dup
    end
  end

  sprites << in_enemies.map do |e|
    s = []
    s << {
      x: e.x,
      y: e.y,
      w: 16,
      h: 16,
      anchor_x: e.anchor_x,
      anchor_y: e.anchor_y,
      path: SPATHS.tank_base
    }
    if e.health > 1
      s << {
        x: e.x,
        y: e.y,
        w: 16,
        h: 16,
        angle: e.angle,
        anchor_x: e.anchor_x,
        anchor_y: e.anchor_y,
        path: SPATHS.tank_top
      }
    end
    s
  end
  
  sprites << args.state.bullets.map do |b|
    {
      x: b.x,
      y: b.y,
      h: 16,
      w: 16,
      anchor_x: b.anchor_x,
      anchor_y: b.anchor_y,
      path: SPATHS.single_bullet
    }
  end

  sprites << {
    x: player.x * CAMERA_RATIO - camera.x,
    y: player.y,
    w: 32,
    h: 32,
    anchor_x: player.anchor_x,
    anchor_y: player.anchor_y,
    path: SPATHS.red_ship
  } if player_active

  sprites << args.state.enemy_bullets.map do |b|
    {
      x: b.x,
      y: b.y,
      h: 16,
      w: 16,
      anchor_x: b.anchor_x,
      anchor_y: b.anchor_y,
      rotation_anchor_x: b.anchor_x,
      rotation_anchor_y: b.anchor_y,
      angle: b.angle - 90,
      path: SPATHS.tank_bullet,
    }
  end

  sprites.flatten! 
  sprites.each do |s|
    s.x = (s.x + camera.x).floor
    s.y = (s.y + camera.y).floor
  end

  output = args.state.canvas
  output.sprites << sprites

  if args.state.debug_on
    output.borders << {
      x: player.x * CAMERA_RATIO,
      y: (player.y + camera.y).floor,
      w: player.w,
      h: player.h,
      anchor_x: player.anchor_x,
      anchor_y: player.anchor_y,
    }
    output.borders << args.state.enemies.map do |e|
      debug_rect e, camera
    end
    output.borders << args.state.enemy_bullets.map do |b|
      debug_rect b, camera
    end
  end
  
  args.outputs.primitives << output
  
  # debug overlay
  args.state.debug_on ||= false
  if args.inputs.keyboard.key_down.p
    args.state.debug_on = !args.state.debug_on
  end
  if args.state.debug_on
    args.outputs.debug << args.gtk.framerate_diagnostics_primitives
  end
  
end

def debug_rect entity, camera
  {
    x: (entity.x + camera.x).floor,
    y: (entity.y + camera.y).floor,
    h: entity.h,
    w: entity.w,
    anchor_x: entity.anchor_x,
    anchor_y: entity.anchor_y,
  }
end

class InputController
  def initialize
    @left = :a
    @right = :d
    @up = :w
    @down = :s
    @shoot = :space
    
    @last_shot = -1
  end
  
  def update args
    @tick_count = args.state.tick_count
    @inputs = args.inputs
  end
  
  def shoot?
    s = (key? @shoot) && (@tick_count > @last_shot + 12)
    @last_shot = @tick_count if s
    s
  end

  def directional_vector
      lr, ud = self.left_right, self.up_down

      if lr == 0 && ud == 0
        return nil
      elsif lr.abs == ud.abs
        return { x: 45.vector_x * lr.sign, y: 45.vector_y * ud.sign }
      else
        return { x: lr, y: ud }
      end
  end

  def left_right
    (key? @right or 0) <=> (key? @left or 0)
  end

  def up_down
    (key? @up or 0) <=> (key? @down or 0)
  end

  def key? k
    @inputs.keyboard.send k
  end

end

