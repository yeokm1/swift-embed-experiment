@_cdecl("app_main")
func main() {
  print("ESP32-C6 talking to BME280 using Swift and BME280 Swift-wrapper")

  let BME280_SCL_PIN: Int32 = 4
  let BME280_SDA_PIN: Int32 = 5

  let status: Bool = bme280_wrapper_init(sclPin: BME280_SCL_PIN, sdaPin: BME280_SDA_PIN)

  if status == true {
    print("Can init BME280")
  } else {
    print("Cannot init BME280")
    return
  }

  while true {

    print("")

    let temp: Double = bme280_wrapper_get_temp();
    let temp_str = bme280_wrapper_double_to_str(value: temp)
    print("Temperature: \(temp_str) C")

    let humd: Double = bme280_wrapper_get_humd();
    let humd_str = bme280_wrapper_double_to_str(value: humd)
    print("Humidity: \(humd_str) %")

    let press: Double = bme280_wrapper_get_press();
    let press_str = bme280_wrapper_double_to_str(value: press)
    print("Pressure: \(press_str) hPa")

    wrapper_delay_us(1000000, nil)

  }

}
