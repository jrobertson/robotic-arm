#!/usr/bin/env ruby

# file: robotic-arm.rb

require 'libusb'


OFF = 0x00

class RoboticArm

  attr_reader :led, :wrist, :elbow, :shoulder, :base, :grip
  attr_reader :light, :gripper    # aliases for :led and :grip

  class Component

    def initialize(robot_arm)  @ra = robot_arm  end
      
    protected      
    
    def active?()  @active                      end    

    def activate(switch, val, seconds=0)  

      return if val == @previous_val
      
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

    def on(seconds=0)  activate(@switch,  0x01, seconds) unless on?  end
    def off()          activate(@switch, -0x01) if on?               end

    alias on? active?
  end

  class ComponentMoving < Component

    def initialize(robot_arm)  
      super(robot_arm)
      @switch, @val = 0, OFF  
    end
    
    def stop()  (@active = false;  activate(@switch, -(@prev_val))) if moving?   end

    alias moving? active?
    
    protected        
                                
    def activate(switch, val, seconds=0)        
      (@val = @prev_val; stop) if active?
      super(switch, val, seconds)
    end
                
  end

  class ComponentUpDown < ComponentMoving
                
    def up  (seconds=0)  activate(@switch, @upval,   seconds) end
    def down(seconds=0)  activate(@switch, @downval, seconds) end      
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

    def left (seconds=0)  activate(@switch, @val=0x02, seconds)  end
    def right(seconds=0)  activate(@switch, @val=0x01, seconds)  end
  end

  class Gripper  < ComponentMoving

    def open (seconds=0)  activate(@switch, @val=0x02, seconds)  end
    def close(seconds=0)  activate(@switch, @val=0x01, seconds)  end
  end


  def initialize()

    # Get the device object
    usb = LIBUSB::Context.new
    arm = usb.devices(:idVendor => 0x1267, :idProduct => 0x0000).first

    (puts "Arm not found!"; exit) unless arm

    # Take control of the device
    @handle = arm.open
    @handle.claim_interface(0)

    @led      = Led.new      self 
    @wrist    = Wrist.new    self
    @elbow    = Elbow.new    self
    @shoulder = Shoulder.new self
    @base     = Base.new     self
    @grip     = Gripper.new  self
    @register = [OFF,OFF,OFF]
    
    @light, @gripper = @led, @grip  #aliases
  end  

  def left(seconds=0)  @base.left  seconds  end
  def right(seconds=0) @base.right seconds  end

  # register and invoke the robotic action
  #
  def command(switch, val)

    @register[switch] += val
    handle_command
  end

  # turn off all active signals
  #
  def off()    
    led.off if on?
    stop
    @handle.release_interface(0)
  end

  # stop all robotic movement
  #
  def stop()    
    [wrist, elbow, shoulder, base, grip].each do |motor| 
      motor.stop if motor.moving?
    end
  end

  private
                
  # Send the signal 
  #
  def handle_command()

    message = { 
                bmRequestType:  0x40, 
                     bRequest:  6,
                       wValue:  0x100, 
                       wIndex:  0,
                      dataOut:  @register.pack('CCC'), 
                      timeout:  1000
              }
    @handle.control_transfer message
  end
                
end

if __FILE__ == $0 then
  ra = RoboticArm.new
  ra.led.on 1
end

