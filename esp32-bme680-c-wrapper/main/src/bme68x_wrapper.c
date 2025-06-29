#include <rom/ets_sys.h>
#include <driver/i2c_master.h>
#include "bme68x_wrapper.h"


#define I2C_ADDR_BME68X BME68X_I2C_ADDR_HIGH 

static i2c_master_bus_handle_t i2c_bus_handle;
static i2c_master_dev_handle_t i2c_dev_handle;

static struct bme68x_dev bme680_device_handle;
static struct bme68x_conf bme680_conf_handle;
static struct bme68x_heatr_conf bme680_heater_handle;

/* Heater temperature in degree Celsius */
uint16_t temp_prof[10] = { 200, 240, 280, 320, 360, 360, 320, 280, 240, 200 };

/* Heating duration in milliseconds */
uint16_t dur_prof[10] = { 100, 100, 100, 100, 100, 100, 100, 100, 100, 100 };


// Read Register Function Pointer for BME68X library
BME68X_INTF_RET_TYPE wrapper_i2c_read(uint8_t reg_addr, uint8_t *data, uint32_t len, void *intf_ptr)
{
    esp_err_t status = i2c_master_transmit_receive(i2c_dev_handle, &reg_addr, 1, data, len, -1);
    
    if(status == ESP_OK){
        return BME68X_OK;
    } else {
        return BME68X_E_COM_FAIL;
    }
}

// Write Register Function Pointer for BME68X library
BME68X_INTF_RET_TYPE wrapper_i2c_write(uint8_t reg_addr, const uint8_t *data, uint32_t len, void *intf_ptr)
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
        return BME68X_OK;
    } else {
        return BME68X_E_COM_FAIL;
    }
    
}

// Delay Function Pointer for BME68X library
void wrapper_delay_us(uint32_t period, void *intf_ptr){
    ets_delay_us(period);
}


bool bme680_wrapper_init(int scl_pin, int sda_pin){

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
        .device_address = I2C_ADDR_BME68X,
        .scl_speed_hz = 100000,
    };

    ESP_ERROR_CHECK(i2c_master_bus_add_device(i2c_bus_handle, &i2c_dev_cfg, &i2c_dev_handle));


    // ESP32 I2C Configuration End


    // Configure BME68X

    bme680_device_handle.read = wrapper_i2c_read;
    bme680_device_handle.write = wrapper_i2c_write;
    bme680_device_handle.intf = BME68X_I2C_INTF;
    bme680_device_handle.delay_us = wrapper_delay_us;

    int8_t rslt = bme68x_init(&bme680_device_handle);

    if(rslt != BME68X_OK){
        return false;
    }

    bme680_conf_handle.filter = BME68X_FILTER_OFF;
    bme680_conf_handle.odr = BME68X_ODR_NONE;
    bme680_conf_handle.os_hum = BME68X_OS_16X;
    bme680_conf_handle.os_pres = BME68X_OS_1X;
    bme680_conf_handle.os_temp = BME68X_OS_2X;
    rslt = bme68x_set_conf(&bme680_conf_handle, &bme680_device_handle);

    if(rslt != BME68X_OK){
        return false;
    }

    // Not enable heater to avoid affecting temperature reading

    // bme680_heater_handle.enable = BME68X_ENABLE;
    // bme680_heater_handle.heatr_temp_prof = temp_prof;
    // bme680_heater_handle.heatr_dur_prof = dur_prof;
    // bme680_heater_handle.profile_len = 10;
    // rslt = bme68x_set_heatr_conf(BME68X_FORCED_MODE, &bme680_heater_handle, &bme680_device_handle);

    // if(rslt != BME68X_OK){
    //     return false;
    // }

    return true;
}

void bme680_wrapper_get_data(float *temperature, float *humidity, float *pressure, float *gas_resistance) {
    bme68x_set_op_mode(BME68X_FORCED_MODE, &bme680_device_handle);

    uint32_t period = bme68x_get_meas_dur(BME68X_FORCED_MODE, &bme680_conf_handle, &bme680_device_handle);

    wrapper_delay_us(period, bme680_device_handle.intf_ptr);

    struct bme68x_data data;
    uint8_t num_fields = 1;

    bme68x_get_data(BME68X_FORCED_MODE, &data, &num_fields, &bme680_device_handle);

    if (temperature) {
        *temperature = data.temperature;
    }
    
    if (humidity) {
        *humidity = data.humidity;
    }

    if (pressure) {
        *pressure = data.pressure;
    }
    
    if (gas_resistance) {
        *gas_resistance = data.gas_resistance;
    }
}

void bme680_wrapper_print_float(float value){
    printf("%0.2f", value);
}
