
SPATHS = {
  blue_ship: "sprites/ships/ship_0000.png",
  red_ship: "sprites/ships/ship_0001.png",
  single_bullet: "sprites/tiles/tile_0000.png"
}

def tick args
  scale = 2
  c = args.grid.center

  args.state.player ||= {
    x: c.x,
    y: c.y,
    h: 32 * scale,
    w: 32 * scale,
  }
  args.state.bullets ||= []

  # Input Handling
  
  args.state.input ||= InputController.new
  args.state.input.update args
  dir = args.state.input.directional_vector
  
  # Updates
  
  player = args.state.player
  if dir
    speed = 3
    player.x += dir.x * speed
    player.y += dir.y * speed
  end

  args.state.bullets.each do |b|
    b.y += 12
    args.state.bullets.delete b unless b.y < 750
  end
   
  if args.state.input.shoot?
    args.state.bullets << {
      x: player.x,
      y: player.y + player.h / 2,
      w: 16 * scale,
      h: 16 * scale,
      anchor_x: 0.5,
      anchor_y: 0.5,
      path: SPATHS.single_bullet
    }
  end

  # Rendering
  
  args.outputs.sprites << args.state.bullets
  
  args.outputs.sprites << {
    **args.state.player,
    anchor_x: 0.5,
    anchor_y: 0.5,
    path: SPATHS.red_ship
  }

end

class InputController
  def initialize
    @left = :a
    @right = :d
    @up = :w
    @down = :s
    @shoot = :space
    
    @h_keys = []
    @v_keys = []
    @last_shot = -100
  end
  
  def update args
    @tick_count = args.state.tick_count
    @inputs = args.inputs
    
    @h_keys.unshift :left if key_down? @left
    @h_keys.delete :left if key_up? @left
    
    @h_keys.unshift :right if key_down? @right
    @h_keys.delete :right if key_up? @right

    @v_keys.unshift :up if key_down? @up
    @v_keys.delete :up if key_up? @up
    
    @v_keys.unshift :down if key_down? @down
    @v_keys.delete :down if key_up? @down
  end
  
  def shoot?
    s = (key? @shoot) && (@tick_count > @last_shot + 10)
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
    k = @h_keys.first

    return -1 if k == :left
    return 1 if k == :right
    return 0  
  end

  def up_down
    k = @v_keys.first

    return -1 if k == :down
    return 1 if k == :up
    return 0
  end

  def key_down? k
    @inputs.keyboard.key_down.send k
  end

  def key_up? k
    @inputs.keyboard.key_up.send k
  end

  def key? k
    @inputs.keyboard.send k
  end

end
