@_cdecl("app_main")
func main() {
  print("ESP32-C6 talking to BME680 using Swift and BME680 Swift-wrapper")

  let BME680_SCL_PIN: Int32 = 4
  let BME680_SDA_PIN: Int32 = 5

  let status: Bool = bme680_wrapper_init(sclPin: BME680_SCL_PIN, sdaPin: BME680_SDA_PIN)

  if status == true {
    print("Can init BME680")
  } else {
    print("Cannot init BME680")
    return
  }

  while true {

    print("")

    let data_tuple = bme680_wrapper_get_data()

    let temp_str = bme680_wrapper_float_to_str(value: data_tuple.temperature)
    print("Temperature: \(temp_str) C")

    let humd_str = bme680_wrapper_float_to_str(value: data_tuple.humidity)
    print("Humidity: \(humd_str) %")

    let press_str = bme680_wrapper_float_to_str(value: data_tuple.pressure)
    print("Pressure: \(press_str) hPa")

    // let gas_str = bme680_wrapper_float_to_str(value: data_tuple.gas_resistance)
    // print("Gas Resistance: \(gas_str) ohms")

    wrapper_delay_us(1000000, nil)

  }

}
