from enum import Enum

class Vehicle():
  '''
  The instantiation operation (“calling” a class object) creates an empty object. Many classes like to create objects with
   instances customized to a specific initial state. Therefore a class may define a special method named __init__(),
   like this:
  '''
  color ="red" # class attribute should not be changed  but we can change outside the class
  pi=3.14
  V_cnt=0 # class attribute

  def __init__(self,body,make): #Constructor Method,by default it will call when we create a object
    self.vehicle_body=body
    self.vehicle_make=make
    Vehicle.V_cnt +=1
  ''''
  When a class defines an __init__() method, class instantiation automatically invokes __init__() for the newly-created class 
  instance. So in this example, a new, initialized instance can be obtained by:
  '''
  def get_vehicle_count(self)-> int:
      return Vehicle.V_cnt

  def isMatch(self,str_word):
      if self.vehicle_make==str_word:
          print(f" Matches {self.vehicle_make} and {str_word}")
      else:
          print(f"no Match {self.vehicle_make} and {str_word}")

  def drive(self):
      print('Vehicle Driving..')

class Truck(Vehicle):
    def drive(self): #override the method ,inheritance
        print('Truck Driving..')

class motercycle(Vehicle):
    def drive(self): #override the method ,inheritance
        print('MoterCycle Driving is very fast ..')

class Shake(Enum):
    VANILLA = 7
    CHOCOLATE = 4
    COOKIES = 9
    MINT = 3


def main():
  car1 = Vehicle('Jeep','Toyota')
  car2 = Vehicle('SUV', 'Honda')
  car3 = Vehicle('Truck', 'RAM')
  car4 = Vehicle('Hatch Back', 'Maruti')
  #Vehicle.color = 'White' # class attribute
  print(car1.vehicle_make +' '+ car1.vehicle_body +' '+car1.color)
  print(car2.vehicle_make +' '+ car2.vehicle_body +' '+car2.color)
  print(car3.vehicle_make +' '+ car3.vehicle_body +' '+car3.color)
  print(car4.vehicle_make +' '+ car4.vehicle_body +' '+car4.color)
  car1.color = 'Black' # instance Variable
  #print(type(car1)) #<class '__main__.Vehicle'>
  print("===================================")
  print(car1.vehicle_make + ' ' + car1.vehicle_body + ' ' +car1.color)
  print(car2.vehicle_make + ' ' + car2.vehicle_body + ' ' + car2.color)
  print(car3.vehicle_make + ' ' + car3.vehicle_body + ' ' + car3.color)
  print(car4.vehicle_make + ' ' + car4.vehicle_body + ' ' + car4.color)
  car2.isMatch('Toyota')
  print(f"No# of cars {car1.get_vehicle_count()}")
  truck1 = Truck('Tata Vajra','TATA')
  truck2 = Truck('Toyota Aurmer','Toyota')
  truck3 = Truck('Tesla Truck','TESLA')
  print(truck1.vehicle_make + ' ' + truck1.vehicle_body + ' ' + truck1.color)
  print(truck2.vehicle_make + ' ' + truck2.vehicle_body + ' ' + truck2.color)
  print(truck3.vehicle_make + ' ' + truck3.vehicle_body + ' ' + truck3.color)
  print(f"No# of Trucks {truck1.get_vehicle_count()}")
  print(truck1.drive())
  motercycle1 = motercycle('Yamaha ', 'BAJAJ')
  print(motercycle1.drive())
  for v in [truck1,motercycle1,car1]: # three diff objects
      v.drive() # same method defined for three diff objects /classes 
  for shake in Shake:
      print(shake)

if __name__ == '__main__':
   print('main Starts ......')
   main()
   print("****DONE MAIN****")






