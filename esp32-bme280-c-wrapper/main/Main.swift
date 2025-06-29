@_cdecl("app_main")
func main() {
  print("ESP32-C6 talking to BME280 using Swift and BME280 C-wrapper")

  let BME280_SCL_PIN: Int32 = 4
  let BME280_SDA_PIN: Int32 = 5

  let status: Bool = bme280_wrapper_init(BME280_SCL_PIN, BME280_SDA_PIN)

  if status == true {
    print("Can init BME280")
  } else {
    print("Cannot init BME280")
    return
  }

  while true {

    print("")

    let temp: Double = bme280_wrapper_get_temp();
    print("Temperature: ", terminator: "")
    bme280_wrapper_print_double(temp)
    print(" C")

    let press: Double = bme280_wrapper_get_press();
    print("Pressure: ", terminator: "")
    bme280_wrapper_print_double(press)
    print(" hPa")

    let humd: Double = bme280_wrapper_get_humd();
    print("Humd: ", terminator: "")
    bme280_wrapper_print_double(humd)
    print(" %")

    wrapper_delay_us(1000000, nil)

  }


}

