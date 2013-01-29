#Introducing the Robotic-arm gem

This gem controls the USB OWI Robotic arm. 

## Prequisites

* You will need to apt-get at least 1 libusb package if I remember correctly. It might be libusb-dev but I can't be certain.

## Example codes

    require 'robotic-arm'

    ra = RoboticArm.new
    ra.led.on
    ra.shoulder.up 0.5
    ra.elbow.up 0.5
    ra.wrist.up 0.3
    ra.base.left 0.7
    ra.gripper.close 0.2
    ra.gripper.open 0.4
    ra.led.off
    ra.stop

Note: The user must have permission to use the libusb device. You can run the above code as root.
