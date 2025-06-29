#ifndef _BME280_WRAPPER_H
#define _BME280_WRAPPER_H

/*! CPP guard */
#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdio.h>
#include "bme68x.h"

void wrapper_delay_us(uint32_t period, void *intf_ptr);

bool bme680_wrapper_init(int scl_pin, int sda_pin);

void bme680_wrapper_get_data(float *temperature, float *humidity, float *pressure, float *gas_resistance);

void bme680_wrapper_print_float(float value);

#ifdef __cplusplus
}
#endif /* End of CPP guard */
#endif /* _BME280_WRAPPER_H */
