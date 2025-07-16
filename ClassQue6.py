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


class Truck(Vehicle):
    def drive(self):  # override the method ,inheritance
        print("Truck Driving..")


car1 = Vehicle("Jeep", "Toyota")
car2 = Vehicle("SUV", "Honda")
car3 = Vehicle("Truck", "RAM")
truck1 = Truck("Tata Vajra", "TATA")
print(truck1.vehicle_make + " , " + truck1.vehicle_body + " , " + truck1.color)
