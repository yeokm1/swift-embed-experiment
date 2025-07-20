// BME280 constants manually redefined. Constants are defined in bme280_defs.h as macros which Swift cannot import directly
let I2C_ADDR_BME280: UInt16 = 0x76
let BME280_OK: Int8 = 0
let BME280_E_COMM_FAIL: Int8 = -2
let BME280_FILTER_COEFF_2: UInt8 = 0x01
let BME280_OVERSAMPLING_1X: UInt8 = 0x01
let BME280_STANDBY_TIME_0_5_MS: UInt8 = 0x00
let BME280_SEL_ALL_SETTINGS: UInt8 = 0x1F
let BME280_POWERMODE_NORMAL: UInt8 = 0x03
let BME280_PRESS: UInt8 = 1
let BME280_TEMP: UInt8 = 1 << 1
let BME280_HUM: UInt8 = 1 << 2


var i2c_dev_handle: i2c_master_dev_handle_t?

var bme280_device_handle: UnsafeMutablePointer<bme280_dev> = UnsafeMutablePointer<bme280_dev>.allocate(capacity: 1)
var bme280_settings_handle: bme280_settings = bme280_settings()


func wrapper_i2c_read(reg_addr: UInt8, data: UnsafeMutablePointer<UInt8>!, len: UInt32, intf_ptr: UnsafeMutableRawPointer?) -> Int8 {

    // Original attempt with UnsafeMutablePointer that is allocated on heap
    // let reg_addr_ptr = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
    // reg_addr_ptr.initialize(to: reg_addr)
    // let status = i2c_master_transmit_receive(i2c_dev_handle, reg_addr_ptr, 1, data, Int(len), -1)
    // reg_addr_ptr.deinitialize(count: 1)
    // reg_addr_ptr.deallocate()

    //LLM guided
    //We duplicate the variable as the original reg_addr passed in is constant while C function needs UnsafePointer<UInt8>
    var reg_addr_temp: UInt8 = reg_addr
    
    let status = i2c_master_transmit_receive(i2c_dev_handle, &reg_addr_temp, 1, data, Int(len), -1)
    
    if status == ESP_OK {
        return BME280_OK
    } else {
        return BME280_E_COMM_FAIL
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

    // if status == ESP_OK {
    //     return BME280_OK
    // } else {
    //     return BME280_E_COMM_FAIL
    // }


    // LLM guided
    var status: esp_err_t = ESP_FAIL

    var reg_addr_copy: UInt8 = reg_addr
    withUnsafeMutablePointer(to: &reg_addr_copy) { regAddrMutPtr in
        
        //Change UnsafePointer to UnsafeMutablePointer. Allocated on stack.
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
        return BME280_OK
    } else {
        return BME280_E_COMM_FAIL
    }
}


func wrapper_delay_us(_ period: UInt32, _ intf_ptr: UnsafeMutableRawPointer?) {
    ets_delay_us(period)
}

func bme280_wrapper_init(sclPin: Int32, sdaPin: Int32) -> Bool {
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
    i2c_dev_cfg.device_address = I2C_ADDR_BME280
    i2c_dev_cfg.scl_speed_hz = 100000

    //var dev_handle: i2c_master_dev_handle_t?
    guard i2c_master_bus_add_device(i2c_bus_handle, &i2c_dev_cfg, &i2c_dev_handle) == ESP_OK else {
        return false
    }

    bme280_device_handle.pointee.intf = BME280_I2C_INTF
    bme280_device_handle.pointee.read = wrapper_i2c_read
    bme280_device_handle.pointee.write = wrapper_i2c_write
    bme280_device_handle.pointee.delay_us = wrapper_delay_us

    guard bme280_init(bme280_device_handle) == BME280_OK else {
        return false
    }

    guard bme280_get_sensor_settings(&bme280_settings_handle, bme280_device_handle) == BME280_OK else {
        return false
    }

    bme280_settings_handle.filter = BME280_FILTER_COEFF_2
    bme280_settings_handle.osr_h = BME280_OVERSAMPLING_1X
    bme280_settings_handle.osr_p = BME280_OVERSAMPLING_1X
    bme280_settings_handle.osr_t = BME280_OVERSAMPLING_1X
    bme280_settings_handle.standby_time = BME280_STANDBY_TIME_0_5_MS

    guard bme280_set_sensor_settings(BME280_SEL_ALL_SETTINGS, &bme280_settings_handle, bme280_device_handle) == BME280_OK else {
        return false
    }

    guard bme280_set_sensor_mode(BME280_POWERMODE_NORMAL, bme280_device_handle) == BME280_OK else {
        return false
    }

    return true
}


func bme280_wrapper_get_temp() -> Double {
    var period: UInt32 = 0
    bme280_cal_meas_delay(&period, &bme280_settings_handle)
    wrapper_delay_us(period, nil)

    var comp_data: bme280_data = bme280_data()
    bme280_get_sensor_data(BME280_TEMP, &comp_data, bme280_device_handle)
    return comp_data.temperature
}

func bme280_wrapper_get_press() -> Double {
    var period: UInt32 = 0
    bme280_cal_meas_delay(&period, &bme280_settings_handle)
    wrapper_delay_us(period, nil)

    var comp_data: bme280_data = bme280_data()
    bme280_get_sensor_data(BME280_PRESS, &comp_data, bme280_device_handle)
    return comp_data.pressure
}

func bme280_wrapper_get_humd() -> Double {
    var period: UInt32 = 0
    bme280_cal_meas_delay(&period, &bme280_settings_handle)
    wrapper_delay_us(period, nil)

    var comp_data: bme280_data = bme280_data()
    bme280_get_sensor_data(BME280_HUM, &comp_data, bme280_device_handle)
    return comp_data.humidity
}

// Source: https://forums.swift.org/t/how-to-print-floating-point-numbers-in-embedded-swift/74520/2
func bme280_wrapper_double_to_str(value: Double) -> String {
    let int = Int(value)
    let frac = Int((value - Double(int)) * 100)
    return "\(int).\(frac)"
}
