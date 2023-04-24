
SPATHS = {
  blue_ship: "sprites/ships/ship_0000.png",
  red_ship: "sprites/ships/ship_0001.png",
  single_bullet: "sprites/tiles/tile_0000.png",
  tank: "sprites/tiles/tile_0028.png",
  tileset: "sprites/tilemap/tiles.png",
}

def tick args
  # 12 x 15 grid, 16x16 tiles
  # world is 16 wide
  cw = 192
  ch = 240
  
  args.state.canvas ||= DRT::LowResolutionCanvas.new([cw, ch])
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
  args.state.enemies ||= args.state.enemy_instances.map do |e|
    {
      x: e.px.first + 8,
      y: h - e.px.second,
      w: 16,
      h: 16,
      anchor_x: 1,
      anchor_y: 0.5,
    }
  end
  
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
    h: 32 * scale,
    w: 32 * scale,
    anchor_x: 0.5,
    anchor_y: 0.5,
  }
  args.state.bullets ||= []
  
  # Input Handling
  
  args.state.input ||= InputController.new
  args.state.input.update args
  dir = args.state.input.directional_vector
  
  # Updates
  
  player = args.state.player
  
  player.wy += 0.5 if player.wy < h - ch
  
  if dir
    speed = 2
    player.x = (player.x + dir.x * speed)
      .clamp(0, 256)
    player.ry = (player.ry + dir.y * speed)
      .clamp(0, ch)
  end
  player.y = player.wy + player.ry
  
  args.state.bullets.each do |b|
    b.y += 6
    args.state.bullets.delete b unless b.y < player.wy + ch + 8
  end
  
  if args.state.input.shoot?
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
  
  # Rendering
  
  # when player is at 0, offset should be 0
  # when player is at 256, offset should be 64 (256 - 192)
  
  cam_ratio = cw / 256 - 1
  camera = {
    x: (player.x * cam_ratio).round,
    y: -player.wy
  }
  
  output = args.state.canvas
  
  output.sprites << args.state.bg.filter_map do |t|
    if (t.y > (player.wy - 16) && t.y < (player.wy + ch))
      t = t.dup
      t.x = (t.x + camera.x).floor
      t.y = (t.y + camera.y).floor
      t
    end
  end

  output.sprites << args.state.enemies.filter_map do |e|
    if (e.y > (player.wy - 16) && e.y < (player.wy + ch + 16))
      {
        x: (e.x + camera.x).floor,
        y: (e.y + camera.y).floor,
        w: 16,
        h: 16,
        anchor_x: e.anchor_x,
        anchor_y: e.anchor_y,
        path: SPATHS.tank
      }
    end
  end
  
  output.sprites << args.state.bullets.map do |b|
    {
      x: (b.x + camera.x).floor,
      y: (b.y + camera.y).floor,
      h: 16,
      w: 16,
      anchor_x: b.anchor_x,
      anchor_y: b.anchor_y,
      path: SPATHS.single_bullet
    }
  end
  
  output.sprites << {
    x: player.x * cw / 256,
    y: (player.y + camera.y).floor,
    w: player.w,
    h: player.h,
    anchor_x: player.anchor_x,
    anchor_y: player.anchor_y,
    path: SPATHS.red_ship
  }
  
  args.outputs.primitives << output
  
  # debug overlay
  if args.inputs.keyboard.key_down.p
    args.state.debug_on = !args.state.debug_on
  end
  if args.state.debug_on
    args.outputs.debug << args.gtk.framerate_diagnostics_primitives
  end
  
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

