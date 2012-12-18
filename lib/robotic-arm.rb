#!/usr/bin/env ruby

# file: robotic-arm.rb

require 'libusb'


OFF = 0x00

class RoboticArm

  attr_reader :led, :wrist, :elbow, :shoulder, :base, :grip

  class Component

    def initialize(robot_arm)  @ra = robot_arm  end
    def active?()  @active                      end
    
    protected

    def activate(switch, val, seconds)  
      @active = val >= 0
      @prev_val = val 
      @ra.command(switch, val)
      if seconds > 0 then
        sleep seconds  
        @ra.command(switch, -(val))
        @active = false
      end
    end
  end

  class Led             < Component

    def initialize(robot_arm)  

      super(robot_arm)
      @switch = 2 
    end

    def on(seconds=0)
      activate(@switch, 0x01, seconds) unless on?
    end

    def off(seconds=0)  
      activate(@switch, -0x01, seconds) if on?
    end

    alias on? active?
  end

  class ComponentMoving < Component

    def initialize(robot_arm)  
      super(robot_arm)
      @switch, @val = 0, OFF  
    end

    def activate(switch, val, seconds=0)  
      if active? then
        @val = @prev_val
        stop
      end
      super(switch, val, seconds)
    end

    def stop()
      if moving? then
        @active = false
        activate(@switch, -(@prev_val))
      end 
    end

    alias moving? active?

  end

  class ComponentUpDown < ComponentMoving

    def up(seconds=0)
      activate(@switch, @upval,seconds)
    end

    def down(seconds=0)
      activate(@switch, @downval, seconds)
    end
  end

  class Shoulder < ComponentUpDown

    def initialize(robot_arm)
      super(robot_arm)
      @upval, @downval = 0x40, 0x80
    end
  end

  class Elbow    < ComponentUpDown

    def initialize(robot_arm)
      super(robot_arm)
      @upval, @downval = 0x10, 0x20
    end
  end

  class Wrist    < ComponentUpDown

    def initialize(robot_arm)
      super(robot_arm)
      @upval, @downval = 0x04, 0x08
    end
  end

  class Base     < ComponentMoving

    def initialize(robot_arm)
      super(robot_arm)
      @switch = 1     
    end

    def left(seconds=0)  
      activate(@switch, @val=0x02, seconds)
    end

    def right(seconds=0)
      activate(@switch, @val=0x01, seconds)
    end
  end

  class Grip     < ComponentMoving

    def open(seconds=0)
      activate(@switch, @val=0x02, seconds)
    end

    def close(seconds=0)
      activate(@switch, @val=0x01, seconds)
    end
  end


  def initialize()

    # Get the device object
    usb = LIBUSB::Context.new
    arm = usb.devices(:idVendor => 0x1267, :idProduct => 0x0000).first

    if arm == nil
      puts "Arm not found!"
      exit
    end

    # Take control of the device
    @handle = arm.open
    @handle.claim_interface(0)

    @led      = Led.new      self 
    @wrist    = Wrist.new    self
    @elbow    = Elbow.new    self
    @shoulder = Shoulder.new self
    @base     = Base.new     self
    @grip     = Grip.new     self
    @register = [OFF,OFF,OFF]
  end  

  def left(seconds=0)  @base.left  seconds  end
  def right(seconds=0) @base.right seconds  end

  # register and invoke the robotic action
  #
  def command(switch, val)

    @register[switch] += val
    handle_command
  end

  # Send the signal 
  #
  def handle_command()

    @handle.control_transfer(:bmRequestType => 0x40, :bRequest => 6, \
      :wValue => 0x100, :wIndex => 0, :dataOut => @register.pack('CCC'), \
      :timeout => 1000)
  end

  # turn off all active signals
  #
  def off()    
    @register= [OFF,OFF,OFF]
    handle_command
    @handle.release_interface(0)
  end

  # stop all robotic movement
  #
  def stop()    
    @register[0] = OFF
    @register[1] = OFF
    handle_command
  end

end

if __FILE__ == $0 then
  ra = RoboticArm.new
  ra.led.on 1
end

