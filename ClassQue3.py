class Vehicle:
    color = "red"
    pi = 3.14
    V_cnt = 0

    def __init__(self, body, make):
        self.vehicle_body = body
        self.vehicle_make = make
        Vehicle.V_cnt += 1

    def get_vehicle_count(self) -> int:
        return Vehicle.V_cnt


def main():
    car1 = Vehicle("Jeep", "Toyota")
    print(f"No# of cars {car1.get_vehicle_count()}")


if __name__ == "__main__":
    print("main Starts ......")
    main()
    print("****DONE MAIN****")
