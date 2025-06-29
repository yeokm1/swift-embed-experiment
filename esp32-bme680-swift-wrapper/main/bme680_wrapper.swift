// BME680 constants manually redefined. Constants are defined in bme680_defs.h as macros which Swift cannot import directly
let I2C_ADDR_BME680: UInt16 = 0x77

let BME68X_OK: Int8 = 0
let BME68X_E_COM_FAIL: Int8 = -2
let BME68X_FILTER_OFF: UInt8 = 0
let BME68X_ODR_NONE: UInt8 = 8
let BME68X_OS_16X: UInt8 = 5
let BME68X_OS_1X: UInt8 = 1
let BME68X_OS_2X: UInt8 = 2

let BME68X_FORCED_MODE: UInt8 = 1
let BME68X_ENABLE: UInt8 = 0x01

// Heater temperature in degree Celsius
let temp_prof = UnsafeMutablePointer<UInt16>.allocate(capacity: 10)
// Heating duration in milliseconds
let dur_prof = UnsafeMutablePointer<UInt16>.allocate(capacity: 10)


var i2c_dev_handle: i2c_master_dev_handle_t?

var bme680_device_handle: UnsafeMutablePointer<bme68x_dev> = UnsafeMutablePointer<bme68x_dev>.allocate(capacity: 1)
var bme680_conf_handle: UnsafeMutablePointer<bme68x_conf>  = UnsafeMutablePointer<bme68x_conf>.allocate(capacity: 1)
var bme680_heatr_handle: UnsafeMutablePointer<bme68x_heatr_conf>  = UnsafeMutablePointer<bme68x_heatr_conf>.allocate(capacity: 1)

func wrapper_i2c_read(reg_addr: UInt8, data: UnsafeMutablePointer<UInt8>!, len: UInt32, intf_ptr: UnsafeMutableRawPointer?) -> Int8 {

    // Original attempt with UnsafeMutablePointer that is allocated on heap
    // let reg_addr_ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
    // reg_addr_ptr.initialize(to: reg_addr)
    // let status = i2c_master_transmit_receive(i2c_dev_handle, reg_addr_ptr, 1, data, Int(len), -1)
    // reg_addr_ptr.deinitialize(count: 1)
    // reg_addr_ptr.deallocate()

    // LLM guided
    // We duplicate the variable as the original reg_addr passed in is constant while C function needs UnsafePointer<UInt8>
    var reg_addr_temp: UInt8 = reg_addr
    
    let status = i2c_master_transmit_receive(i2c_dev_handle, &reg_addr_temp, 1, data, Int(len), -1)
    
    if status == ESP_OK {
        return BME68X_OK
    } else {
        return BME68X_E_COM_FAIL
    }

}


func wrapper_i2c_write(reg_addr: UInt8, data: UnsafePointer<UInt8>!, len: UInt32, intf_ptr: UnsafeMutableRawPointer?) -> Int8 {

    //Original attempt with UnsafeMutablePointer that is allocated on heap
    // let reg_addr_unsafe_ptr: UnsafeMutablePointer<UInt8> = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
    // reg_addr_unsafe_ptr.initialize(to: reg_addr)

    // let buffer1: i2c_master_transmit_multi_buffer_info_t = i2c_master_transmit_multi_buffer_info_t(write_buffer: reg_addr_unsafe_ptr, buffer_size: 1)
    // let buffer2: i2c_master_transmit_multi_buffer_info_t = i2c_master_transmit_multi_buffer_info_t(write_buffer: UnsafeMutablePointer(mutating: data), buffer_size: Int(len))

    // let buffers_unsafe_ptr: UnsafeMutablePointer<i2c_master_transmit_multi_buffer_info_t> = UnsafeMutablePointer<i2c_master_transmit_multi_buffer_info_t>.allocate(capacity: 2)
    // buffers_unsafe_ptr.initialize(to: buffer1)
    // (buffers_unsafe_ptr + 1).initialize(to: buffer2)

    // let status: esp_err_t = i2c_master_multi_buffer_transmit(i2c_dev_handle, buffers_unsafe_ptr, 2, -1)

    // buffers_unsafe_ptr.deinitialize(count: 2)
    // buffers_unsafe_ptr.deallocate()

    // reg_addr_unsafe_ptr.deinitialize(count: 1)
    // reg_addr_unsafe_ptr.deallocate()


    // LLM guided
    var status: esp_err_t = ESP_FAIL

    withUnsafePointer(to: reg_addr) { reg_addr_temp in
        //Change UnsafePointer to UnsafeMutablePointer. Allocated on stack.
        let regAddrMutPtr = UnsafeMutablePointer<UInt8>(mutating: reg_addr_temp)
        let dataMutPtr = UnsafeMutablePointer<UInt8>(mutating: data)

        let buffer1 = i2c_master_transmit_multi_buffer_info_t(
            write_buffer: regAddrMutPtr,
            buffer_size: 1
        )

        let buffer2 = i2c_master_transmit_multi_buffer_info_t(
            write_buffer: dataMutPtr,
            buffer_size: Int(len)
        )

        var buffers = [buffer1, buffer2]

        buffers.withUnsafeMutableBufferPointer { bufPtr in
            status = i2c_master_multi_buffer_transmit(i2c_dev_handle, bufPtr.baseAddress, 2, -1)
        }
    }

    if status == ESP_OK {
        return BME68X_OK
    } else {
        return BME68X_E_COM_FAIL
    }
}


func wrapper_delay_us(_ period: UInt32, _ intf_ptr: UnsafeMutableRawPointer?) {
    ets_delay_us(period)
}

func bme680_wrapper_init(sclPin: Int32, sdaPin: Int32) -> Bool {
    var i2c_mst_config: i2c_master_bus_config_t = i2c_master_bus_config_t()

    i2c_mst_config.clk_source = I2C_CLK_SRC_DEFAULT
    i2c_mst_config.i2c_port = i2c_port_num_t(I2C_NUM_0.rawValue)
    i2c_mst_config.scl_io_num = gpio_num_t(sclPin)
    i2c_mst_config.sda_io_num = gpio_num_t(sdaPin)
    i2c_mst_config.glitch_ignore_cnt = 7


    var i2c_bus_handle: i2c_master_bus_handle_t?

    guard i2c_new_master_bus(&i2c_mst_config, &i2c_bus_handle) == ESP_OK else {
        return false
    }

    var i2c_dev_cfg: i2c_device_config_t = i2c_device_config_t()
    i2c_dev_cfg.dev_addr_length = I2C_ADDR_BIT_LEN_7
    i2c_dev_cfg.device_address = I2C_ADDR_BME680
    i2c_dev_cfg.scl_speed_hz = 100000

    //var dev_handle: i2c_master_dev_handle_t?
    guard i2c_master_bus_add_device(i2c_bus_handle, &i2c_dev_cfg, &i2c_dev_handle) == ESP_OK else {
        return false
    }

    bme680_device_handle.pointee.intf = BME68X_I2C_INTF
    bme680_device_handle.pointee.read = wrapper_i2c_read
    bme680_device_handle.pointee.write = wrapper_i2c_write
    bme680_device_handle.pointee.delay_us = wrapper_delay_us

    guard bme68x_init(bme680_device_handle) == BME68X_OK else {
        return false
    }

    bme680_conf_handle.pointee.filter = BME68X_FILTER_OFF;
    bme680_conf_handle.pointee.odr = BME68X_ODR_NONE;
    bme680_conf_handle.pointee.os_hum = BME68X_OS_16X;
    bme680_conf_handle.pointee.os_pres = BME68X_OS_1X;
    bme680_conf_handle.pointee.os_temp = BME68X_OS_2X;

    guard bme68x_set_conf(bme680_conf_handle, bme680_device_handle) == BME68X_OK else {
        return false
    }

    let tempValues: [UInt16] = [200, 240, 280, 320, 360, 360, 320, 280, 240, 200]
    let durValues: [UInt16] = [100, 100, 100, 100, 100, 100, 100, 100, 100, 100]

    for i in 0..<10 {
        temp_prof[i] = tempValues[i]
        dur_prof[i] = durValues[i]
    }

    // Not enable heater to avoid affecting temperature reading
    
    // bme680_heatr_handle.pointee.enable = BME68X_ENABLE;
    // bme680_heatr_handle.pointee.heatr_temp_prof = temp_prof;
    // bme680_heatr_handle.pointee.heatr_dur_prof = dur_prof;
    // bme680_heatr_handle.pointee.profile_len = 10;

    // guard bme68x_set_heatr_conf(BME68X_FORCED_MODE, bme680_heatr_handle, bme680_device_handle) == BME68X_OK else {
    //     return false
    // }

    return true
}

func bme680_wrapper_get_data() -> (temperature: Float, humidity: Float, pressure: Float, gas_resistance: Float) {
    bme68x_set_op_mode(BME68X_FORCED_MODE, bme680_device_handle)

    let period = bme68x_get_meas_dur(BME68X_FORCED_MODE, bme680_conf_handle, bme680_device_handle)

    wrapper_delay_us(period, bme680_device_handle.pointee.intf_ptr)

    let data: UnsafeMutablePointer<bme68x_data>  = UnsafeMutablePointer<bme68x_data>.allocate(capacity: 1)
    let numFields: UnsafeMutablePointer<UInt8>  = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)

    bme68x_get_data(BME68X_FORCED_MODE, data, numFields, bme680_device_handle)

    let temperature = data.pointee.temperature
    let pressure = data.pointee.pressure
    let humidity = data.pointee.humidity
    let gas_resistance = data.pointee.gas_resistance


    numFields.deinitialize(count: 1)
    numFields.deallocate()

    data.deinitialize(count: 1)
    data.deallocate()

    return (temperature: temperature,
            humidity: humidity,
            pressure: pressure,
            gas_resistance: gas_resistance)
}

// Source: https://forums.swift.org/t/how-to-print-floating-point-numbers-in-embedded-swift/74520/2
func bme680_wrapper_float_to_str(value: Float) -> String {
    let int = Int(value)
    let frac = Int((value - Float(int)) * 100)
    return "\(int).\(frac)"
}
