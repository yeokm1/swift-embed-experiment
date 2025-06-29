@_cdecl("app_main")
func main() {
  print("ESP32-C6 talking to BME68x using Swift and BME68x C-wrapper")

  let BME68X_SCL_PIN: Int32 = 4
  let BME68X_SDA_PIN: Int32 = 5

  let status: Bool = bme680_wrapper_init(BME68X_SCL_PIN, BME68X_SDA_PIN)

  if status == true {
    print("Can init BME68X")
  } else {
    print("Cannot init BME68X")
    return
  }

  while true {

    print("")

    var temperature: Float = 0
    var humidity: Float = 0
    var pressure: Float = 0
    var gasResistance: Float = 0

    bme680_wrapper_get_data(&temperature, &humidity, &pressure, &gasResistance)


    print("Temperature: ", terminator: "")
    bme680_wrapper_print_float(temperature)
    print(" C")

    print("Pressure: ", terminator: "")
    bme680_wrapper_print_float(pressure)
    print(" hPa")

    print("Humidity: ", terminator: "")
    bme680_wrapper_print_float(humidity)
    print(" %")

    // print("Gas Resistance: ", terminator: "")
    // bme68x_wrapper_print_float(gasResistance)
    // print(" ohms")

    wrapper_delay_us(1000000, nil)

  }


}

