package pneumacore

/*
#include <stddef.h>
#include <stdlib.h>
#include "callbacks_utils.h"
*/
import "C"

import "unsafe"

func (pc *PneumaCore) RegisterDiscoveryCallback(cb unsafe.Pointer) {
	pc.DiscoveryCallback = cb
}

func (pc *PneumaCore) RegisterSosCallback(cb unsafe.Pointer) {
	pc.SosCallback = cb
}

func (pc *PneumaCore) RegisterMessageCallback(cb unsafe.Pointer) {
	pc.MessageCallback = cb
}

// отправляем чаты в ui
func (pc *PneumaCore) SendDiscoveryToUi(data []byte) {
	if pc.DiscoveryCallback == nil {
		return
	}

	cBytes := C.CBytes(data)
	// defer C.free(cBytes)
	cData := (*C.uint8_t)(cBytes)
	cLength := C.int(len(data))

	C.callDiscoveryCallback((C.DiscoveryCallback)(pc.DiscoveryCallback), cData, cLength)
}

// отправляем сос в ui
func (pc *PneumaCore) SendSosToUi(data []byte) {
	if pc.SosCallback == nil {
		return
	}

	cBytes := C.CBytes(data)
	// defer C.free(cBytes)
	cData := (*C.uint8_t)(cBytes)
	cLength := C.int(len(data))

	C.callSosCallback((C.SosCallback)(pc.SosCallback), cData, cLength)
}

// отправляем сообщение в ui
func (pc *PneumaCore) SendMessageToUi(data []byte) {
	if pc.MessageCallback == nil {
		return
	}

	cBytes := C.CBytes(data)
	// defer C.free(cBytes)
	cData := (*C.uint8_t)(cBytes)
	cLength := C.int(len(data))

	C.callMessageCallback((C.MessageCallback)(pc.MessageCallback), cData, cLength)
}
