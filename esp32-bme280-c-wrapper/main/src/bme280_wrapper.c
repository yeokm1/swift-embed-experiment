#include <rom/ets_sys.h>
#include <driver/i2c_master.h>
#include "bme280_wrapper.h"


#define I2C_ADDR_BME280 BME280_I2C_ADDR_PRIM

static i2c_master_bus_handle_t i2c_bus_handle;
static i2c_master_dev_handle_t i2c_dev_handle;

static struct bme280_dev bme280_device_handle;
static struct bme280_settings bme280_settings_handle;


// Read Register Function Pointer for BME280 library
BME280_INTF_RET_TYPE wrapper_i2c_read(uint8_t reg_addr, uint8_t *data, uint32_t len, void *intf_ptr)
{
    esp_err_t status = i2c_master_transmit_receive(i2c_dev_handle, &reg_addr, 1, data, len, -1);
    
    if(status == ESP_OK){
        return BME280_OK;
    } else {
        return BME280_E_COMM_FAIL;
    }
}

// Write Register Function Pointer for BME280 library
BME280_INTF_RET_TYPE wrapper_i2c_write(uint8_t reg_addr, const uint8_t *data, uint32_t len, void *intf_ptr)
{

    i2c_master_transmit_multi_buffer_info_t reg_buffer;
    reg_buffer.write_buffer = &reg_addr;
    reg_buffer.buffer_size = 1;

    i2c_master_transmit_multi_buffer_info_t data_buffer;
    data_buffer.write_buffer = (uint8_t *) data;
    data_buffer.buffer_size = len;

    i2c_master_transmit_multi_buffer_info_t buffers[2] = {reg_buffer, data_buffer};

    esp_err_t status = i2c_master_multi_buffer_transmit(i2c_dev_handle, buffers, 2, -1);

    if(status == ESP_OK){
        return BME280_OK;
    } else {
        return BME280_E_COMM_FAIL;
    }
    
}

// Delay Function Pointer for BME280 library
void wrapper_delay_us(uint32_t period, void *intf_ptr){
    ets_delay_us(period);
}


bool bme280_wrapper_init(int scl_pin, int sda_pin){

    // ESP32 I2C Configuration Start
    i2c_master_bus_config_t i2c_mst_config = {
        .clk_source = I2C_CLK_SRC_DEFAULT,
        .i2c_port = I2C_NUM_0,
        .scl_io_num = scl_pin,
        .sda_io_num = sda_pin,
        .glitch_ignore_cnt = 7,
    };

    ESP_ERROR_CHECK(i2c_new_master_bus(&i2c_mst_config, &i2c_bus_handle));

    i2c_device_config_t i2c_dev_cfg = {
        .dev_addr_length = I2C_ADDR_BIT_LEN_7,
        .device_address = I2C_ADDR_BME280,
        .scl_speed_hz = 100000,
    };

    ESP_ERROR_CHECK(i2c_master_bus_add_device(i2c_bus_handle, &i2c_dev_cfg, &i2c_dev_handle));

    // ESP32 I2C Configuration End


    // Configure BME280

    bme280_device_handle.intf = BME280_I2C_INTF;
    bme280_device_handle.read = wrapper_i2c_read;
    bme280_device_handle.write = wrapper_i2c_write;
    bme280_device_handle.delay_us = wrapper_delay_us;

    int rslt = bme280_init(&bme280_device_handle);

    if(rslt != BME280_OK){
        return false;
    }

    rslt = bme280_get_sensor_settings(&bme280_settings_handle, &bme280_device_handle);

    bme280_settings_handle.filter = BME280_FILTER_COEFF_2;

    bme280_settings_handle.osr_h = BME280_OVERSAMPLING_1X;
    bme280_settings_handle.osr_p = BME280_OVERSAMPLING_1X;
    bme280_settings_handle.osr_t = BME280_OVERSAMPLING_1X;

    bme280_settings_handle.standby_time = BME280_STANDBY_TIME_0_5_MS;

    rslt = bme280_set_sensor_settings(BME280_SEL_ALL_SETTINGS, &bme280_settings_handle, &bme280_device_handle);
    rslt = bme280_set_sensor_mode(BME280_POWERMODE_NORMAL, &bme280_device_handle);

    if(rslt == BME280_OK){
        return true;
    } else {
        return false;
    }
}

double bme280_wrapper_get_temp(){

    uint32_t period;
    bme280_cal_meas_delay(&period, &bme280_settings_handle);
    wrapper_delay_us(period, NULL);

    struct bme280_data comp_data;
    bme280_get_sensor_data(BME280_TEMP, &comp_data, &bme280_device_handle);
    return comp_data.temperature;
}

double bme280_wrapper_get_press(){

    uint32_t period;
    bme280_cal_meas_delay(&period, &bme280_settings_handle);
    wrapper_delay_us(period, NULL);

    struct bme280_data comp_data;
    bme280_get_sensor_data(BME280_PRESS, &comp_data, &bme280_device_handle);
    return comp_data.pressure;
}

double bme280_wrapper_get_humd(){

    uint32_t period;
    bme280_cal_meas_delay(&period, &bme280_settings_handle);
    wrapper_delay_us(period, NULL);

    struct bme280_data comp_data;
    bme280_get_sensor_data(BME280_HUM, &comp_data, &bme280_device_handle);
    return comp_data.humidity;
}

void bme280_wrapper_print_double(double value){
    printf("%0.2f", value);
}
