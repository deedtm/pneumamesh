#ifndef CALLBACKS_UTILS_H
#define CALLBACKS_UTILS_H
#include <stdint.h>
#include <stdlib.h>

typedef void (*DiscoveryCallback)(uint8_t *data, int length);
typedef void (*SosCallback)(uint8_t *data, int length);
typedef void (*MessageCallback)(uint8_t *data, int length);

void callDiscoveryCallback(DiscoveryCallback cb, uint8_t *data, int length);
void callSosCallback(SosCallback cb, uint8_t *data, int length);
void callMessageCallback(MessageCallback cb, uint8_t *data, int length);

#endif