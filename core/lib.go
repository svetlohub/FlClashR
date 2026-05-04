//go:build cgo

package main

/*
#include <stdlib.h>
*/
import "C"
import (
	bridge "core/dart-bridge"
	"encoding/json"
	"unsafe"
)

var messagePort int64 = -1

var dartApiInitialized bool

//export initNativeApiBridge
func initNativeApiBridge(api unsafe.Pointer) {
	// Dart_InitializeApiDL must only be called ONCE per process.
	// The service FlutterEngine also calls this — second call would
	// overwrite the Dart VM function pointers and corrupt SendToPort.
	if dartApiInitialized {
		return
	}
	bridge.InitDartApi(api)
	dartApiInitialized = true
}

//export attachMessagePort
func attachMessagePort(mPort C.longlong) {
	messagePort = int64(mPort)
}

//export getTraffic
func getTraffic() *C.char {
	return C.CString(handleGetTraffic())
}

//export getTotalTraffic
func getTotalTraffic() *C.char {
	return C.CString(handleGetTotalTraffic())
}

//export freeCString
func freeCString(s *C.char) {
	C.free(unsafe.Pointer(s))
}

// portFromCallback reads the Dart SendPort integer that was stored in
// ActionResult.Callback by invokeAction. Returns -1 if Callback is nil.
func portFromCallback(cb unsafe.Pointer) int64 {
	if cb == nil {
		return -1
	}
	return *(*int64)(cb)
}

// send posts the serialised ActionResult JSON to the Dart ReceivePort.
// The target port is stored in result.Callback (set by invokeAction).
// Port int64 was removed from ActionResult upstream; Callback is the
// replacement mechanism for carrying the opaque port reference.
func (result ActionResult) send() {
	port := portFromCallback(result.Callback)
	if port == -1 {
		return
	}
	data, err := result.Json()
	if err != nil {
		return
	}
	bridge.SendToPort(port, string(data))
}

//export invokeAction
func invokeAction(paramsChar *C.char, port C.longlong) {
	params := C.GoString(paramsChar)
	i := int64(port)
	var action = &Action{}
	err := json.Unmarshal([]byte(params), action)
	if err != nil {
		bridge.SendToPort(i, err.Error())
		return
	}
	// Heap-allocate the port integer so it can be stored as unsafe.Pointer
	// in ActionResult.Callback. The pointer is valid for the goroutine's
	// lifetime; Go's GC will not move it (pinned by the pointer itself).
	portPtr := new(int64)
	*portPtr = i
	result := ActionResult{
		Id:       action.Id,
		Method:   action.Method,
		Callback: unsafe.Pointer(portPtr),
	}
	go handleAction(action, result)
}

func sendMessage(message Message) {
	if messagePort == -1 {
		return
	}
	// Heap-allocate port for Callback, same pattern as invokeAction.
	portPtr := new(int64)
	*portPtr = messagePort
	result := ActionResult{
		Method:   messageMethod,
		Callback: unsafe.Pointer(portPtr),
		Data:     message,
	}
	result.send()
}

//export getConfig
func getConfig(s *C.char) *C.char {
	path := C.GoString(s)
	config, err := handleGetConfig(path)
	if err != nil {
		return C.CString("")
	}
	marshal, err := json.Marshal(config)
	if err != nil {
		return C.CString("")
	}
	return C.CString(string(marshal))
}

//export startListener
func startListener() {
	handleStartListener()
}

//export stopListener
func stopListener() {
	handleStopListener()
}
