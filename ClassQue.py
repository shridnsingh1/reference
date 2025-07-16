class RobotCar():
    def __init__(self, in_trigger_pin, in_servo_delay ):
	   self.in_servo_delay_var = in_servo_delay
       self.in_trigger_pin_var = in_trigger_pin
    

    def stop(self,t=0):
        print('Car stopping')
        self.right_motor_enable_pin.duty_u16(0)
        self.left_motor_enable_pin.duty_u16(0)
    
    def forward(self,t=0):
        print('Move forward')       
        '''
          self.right_motor_enable_pin = PWM(Pin(enable_pins[0]), freq=2000)
        '''
        self.right_motor_enable_pin.duty_u16(self.min_speed)
        self.left_motor_enable_pin.duty_u16(self.min_speed)

        self.right_motor_control_1.value(1)    