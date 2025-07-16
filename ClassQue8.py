class Vehicle:
    color = "red"
    pi = 3.14
    V_cnt = 0

    def __init__(self, body, make):
        self.vehicle_body = body
        self.vehicle_make = make
        Vehicle.V_cnt += 1

    def isMatch(self, str_word):
        if self.vehicle_make == str_word:
            print(f" Matches {self.vehicle_make} and {str_word}")
        else:
            print(f"no Match {self.vehicle_make} and {str_word}")

    def drive(self):
        print("Vehicle Driving..")


class Truck(Vehicle):
    def drive(self):
        print("Truck Driving..")


class motercycle(Vehicle):
    def drive(self):
        print("MoterCycle Driving is very fast ..")


car1 = Vehicle("Jeep", "Toyota")
car2 = Vehicle("SUV", "Honda")
car3 = Vehicle("Truck", "RAM")
truck1 = Truck("Tata Vajra", "TATA")
motercycle1 = motercycle("Yamaha ", "BAJAJ")
for v in [truck1, motercycle1, car1]:
    v.drive()
