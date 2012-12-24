#!/usr/bin/env ruby

# file: robotic-arm.rb

require 'libusb'


OFF = 0x00


module Session

  class Recorder

    def initialize(obj)
      @log = []
      @recording = false
      @obj = obj
    end

    def start
      @log = [{:time => Time.now, :method => :stop}]
      @recording = true
    end

    def stop
      
      return unless @recording == true
      @log << {time: Time.now, class: nil, :method => :stop}
      
      @recording = false

      # convert the time to elapsed time in seconds

      @log.first[:time] = @log[1][:time]
      t1 = @log.first[:time]
      @log.first[:sleep] = 0
      @log[1..-2].each do |record|
        t2 = record[:time]
        record[:sleep] = (t2 - t1).round(2)
        t1 = t2
      end


      @rlog = @log.reverse.map{|x| x.clone}      
      t1 = @rlog.shift[:time]
      @rlog.pop
      
      @rlog[0..-2].each_with_index do |record,i |
        
        classname = record[:class]

        tmp = record.clone
        j = @rlog[(i+1)..-1].map{|x| x[:class]}.index(classname)
        
        next unless j

        record[:method] = swap_state @rlog[i+1+j][:method]
        record[:sleep] = swap_state @rlog[i+1+j][:sleep]

        @rlog[i+1+j][:method] = swap_state tmp[:method]
        @rlog[i+1+j][:sleep] = tmp[:sleep]

      end

      @log
    end

    def record(classname, methodname)
            
      @log << {
            time: Time.now, 
            class: classname.to_sym, 
            method: methodname.to_sym
      }
    end

    def recording?()    @recording  end
    def playback()      play @rlog  end
    def reverse_play()  play @rlog  end

    private

    def play(log)      

      log.each do |record|
        
        sleep record[:sleep].to_f          
        component, action = *[:class, :method].map{|x| record[x]}
        
        unless component.nil? then
          @obj.method(component).call.method(action).call
        else
          @obj.method(action).call
        end
      end
    end
    
    def swap_state(methodname)
      case methodname
        when :up
          :down
        when :down
          :up
        when :left
          :right
        when :right
          :left
        when :open
          :close
        when :close
          :open
        else
          methodname
      end
    end
    
  end

  def recording()   @sr ||= Recorder.new(self)                         end
  def recording?()  @sr ||= Recorder.new(self);  @sr.recording?        end
  def record(classname, methodname)  @sr.record classname, methodname  end

end

class RoboticArm
  include Session

  attr_reader :led, :wrist, :elbow, :shoulder, :base, :grip
  attr_reader :light, :gripper    # aliases for :led and :grip

  class Component

    def initialize(robot_arm)  @ra = robot_arm  end             
    def active?()  @active                      end    
      
    protected
    
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
    
    def inspect() '<' + self.class.to_s + '>' end
      
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
      @moving = false
    end
    
    def stop()
      if moving?  then
        @active = false
        activate(@switch, -(@prev_val))
      end
    end

    def moving?() @active ? @moving : false  end
    
    protected        
                                
    def activate(switch, val, seconds=0)        
      (@val = @prev_val; stop) if active?
      super(switch, val, seconds)
    end
                
  end

  class ComponentUpDown < ComponentMoving
                
    def up(seconds=0)
      return if @active and @moving == :up
      activate(@switch, @upval,   seconds)
      @moving = :up
    end
    
    def down(seconds=0)
      return if @active and @moving == :down
      activate(@switch, @downval, seconds)
      @moving = :down
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
      return if @active and @moving == :left
      activate(@switch, @val=0x02, seconds)
      @moving = :left  
    end
    
    def right(seconds=0)
      return if @active and @moving == :right
      activate(@switch, @val=0x01, seconds)
      @moving = :right
    end    
  end

  class Gripper  < ComponentMoving

    def open (seconds=0)
      return if @active and @moving == :open
      activate(@switch, @val=0x02, seconds)
      @moving = :open
    end
    
    def close(seconds=0)
      return if @active and @moving == :close
      activate(@switch, @val=0x01, seconds)
      @moving = :close
    end
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
  
  def inspect() '#<RoboticArm:>' end
  def left(seconds=0)  @base.left  seconds  end
  def right(seconds=0) @base.right seconds  end

  # register and invoke the robotic action
  #
  def command(switch, val)

    @register[switch] += val
    handle_command    

    if recording? then
      
      commands = {
          '21' => [:light,    :on],     '2-1' => [:light,    :off],
          '02' => [:gripper,  :open],    '01' => [:gripper,  :close],
         '0-2' => [:gripper,  :stop],   '0-1' => [:gripper,  :stop],
          '04' => [:wrist,    :up],      '08' => [:wrist,    :down],
         '0-4' => [:wrist,    :stop],   '0-8' => [:wrist,    :stop],
         '016' => [:elbow,    :up],     '032' => [:elbow,    :down],              
        '0-16' => [:elbow,    :stop],  '0-32' => [:elbow,    :stop], 
         '064' => [:shoulder, :up],    '0128' => [:shoulder, :down],
        '0-64' => [:shoulder, :stop], '0-128' => [:shoulder, :stop],        
          '12' => [:base,     :left],    '11' => [:base,     :right],
         '1-2' => [:base,     :stop],   '1-1' => [:base,     :stop]        
      }
      
      classname, methodname = *commands[switch.to_s + val.to_s]

      record classname, methodname
    end
  end

  # turn off all active signals
  #
  def off()        
    stop
    @handle.release_interface(0)
  end

  # stop all robotic movement
  #
  def stop()
    [wrist, elbow, shoulder, base, grip].each do |motor| 
      motor.stop if motor.moving?
    end
    led.off if led.on?    
    nil
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

