#include "callbacks_utils.h"

void callDiscoveryCallback(DiscoveryCallback cb, uint8_t *data, int length)
{
    cb(data, length);
}

void callSosCallback(SosCallback cb, uint8_t *data, int length)
{
    cb(data, length);
}

void callMessageCallback(MessageCallback cb, uint8_t *data, int length)
{
    cb(data, length);
}