//go:build android
// +build android

package log

/*
#include <stdlib.h>
#include <android/log.h>
#define LOG_TAG "PNEUMACORE"
static void log_info(const char* msg) {
    __android_log_write(ANDROID_LOG_INFO, LOG_TAG, msg);
}
static void log_error(const char* msg) {
    __android_log_write(ANDROID_LOG_ERROR, LOG_TAG, msg);
}
*/
import "C"

import (
	"fmt"
	"unsafe"
)

func Info(format string, args ...interface{}) {
	msg := C.CString(fmt.Sprintf(format, args...))
	C.log_info(msg)
	C.free(unsafe.Pointer(msg))
}

func Error(format string, args ...interface{}) {
	msg := C.CString(fmt.Sprintf(format, args...))
	C.log_error(msg)
	C.free(unsafe.Pointer(msg))
}
