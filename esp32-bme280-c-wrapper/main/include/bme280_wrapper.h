#ifndef _BME280_WRAPPER_H
#define _BME280_WRAPPER_H

/*! CPP guard */
#ifdef __cplusplus
extern "C" {
#endif

#include <stdbool.h>
#include <stdio.h>
#include "bme280.h"

void wrapper_delay_us(uint32_t period, void *intf_ptr);

bool bme280_wrapper_init(int scl_pin, int sda_pin);

double bme280_wrapper_get_temp();
double bme280_wrapper_get_press();
double bme280_wrapper_get_humd();

void bme280_wrapper_print_double(double value);

#ifdef __cplusplus
}
#endif /* End of CPP guard */
#endif /* _BME280_WRAPPER_H */
