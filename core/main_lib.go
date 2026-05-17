package main

/*
#include <stdint.h>
#include <stdlib.h>

typedef void (*MessageCallback)(uint8_t* data, int length);

static void invokeMessageCallback(MessageCallback cb, uint8_t* data, int length) {
    if (cb != NULL) {
        cb(data, length);
    }
}
*/
import "C"

import (
	"context"
	"encoding/base64"
	"pneumamesh-core/pb"
	"time"
	"unsafe"

	"github.com/libp2p/go-libp2p/core/crypto"
	"github.com/libp2p/go-libp2p/core/transport"

	"github.com/libp2p/go-libp2p"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
	"google.golang.org/protobuf/proto"
)

// Глобальные переменные
var (
	globalChatState       *ChatState
	globalCancel          context.CancelFunc
	globalInjectTransport *InjectTransport
	localUser             *pb.User
	dartCallback          C.MessageCallback
	lastInitError         error
)

//export GeneratePrivateKey
func GeneratePrivateKey() *C.char {
	priv, _, err := crypto.GenerateKeyPair(crypto.Ed25519, -1)
	if err != nil {
		return C.CString("")
	}
	bytes, err := crypto.MarshalPrivateKey(priv)
	if err != nil {
		return C.CString("")
	}
	return C.CString(base64.StdEncoding.EncodeToString(bytes))
}

//export StartNode
func StartNode(username *C.char, privKeyB64 *C.char) {
	goUsername := C.GoString(username)
	b64Str := C.GoString(privKeyB64)

	go func() {
		ctx, cancel := context.WithCancel(context.Background())
		globalCancel = cancel
		lastInitError = nil

		options := []libp2p.Option{
			libp2p.NoListenAddrs,
			libp2p.DisableRelay(),
			libp2p.Ping(false),
			libp2p.Transport(func(up transport.Upgrader) (transport.Transport, error) {
				globalInjectTransport = NewInjectTransport(up)
				return globalInjectTransport, nil
			}),
		}

		if b64Str != "" {
			keyBytes, err := base64.StdEncoding.DecodeString(b64Str)
			if err == nil {
				privKey, err := crypto.UnmarshalPrivateKey(keyBytes)
				if err == nil {
					options = append(options, libp2p.Identity(privKey))
				}
			}
		}

		h, err := libp2p.New(options...)
		if err != nil {
			lastInitError = err
			return
		}
		// Запускаем фейковый listener, чтобы inbound BLE conn забирались через Accept()
		_ = h.Network().Listen(injectMultiaddr)

		currentRoom := "main-room"
		networkName := "pneumamesh"

		ps, err := pubsub.NewGossipSub(ctx, h)
		if err != nil {
			lastInitError = err
			return
		}

		globalChatState = &ChatState{
			Host:        h,
			PubSub:      ps,
			NetworkName: networkName,
			CurrentRoom: currentRoom,
			Ctx:         ctx,
		}
		localUser = &pb.User{
			Id:                h.ID().String(),
			Name:              goUsername,
			RegisterTimestamp: time.Now().Unix(),
		}

		globalChatState.Topic, _ = globalChatState.PubSub.Join(globalChatState.CurrentRoom)
		globalChatState.Sub, _ = globalChatState.Topic.Subscribe()

		globalChatState.StartListener()
	}()
}

//export SendMessage
func SendMessage(msg *C.char) {
	if globalChatState == nil {
		return
	}

	goMsg := C.GoString(msg)

	msgStruct := &pb.ChatMessage{
		Sender:    localUser,
		Text:      goMsg,
		Timestamp: time.Now().Unix(),
	}

	msgBytes, err := proto.Marshal(msgStruct)
	if err != nil {
		return
	}

	err = globalChatState.Topic.Publish(globalChatState.Ctx, msgBytes)
	if err != nil {
		return
	}
}

//export JoinRoom
func JoinRoom(roomName *C.char) {
	if globalChatState == nil {
		return
	}
	newRoom := C.GoString(roomName)
	globalChatState.HandleJoin(newRoom)
}

//export RegisterMessageCallback
func RegisterMessageCallback(cb C.MessageCallback) {
	dartCallback = cb
}

func sendToDart(data []byte) {
	if dartCallback == nil {
		return
	}

	cBytes := C.CBytes(data)
	cData := (*C.uint8_t)(cBytes)
	cLength := C.int(len(data))

	C.invokeMessageCallback(dartCallback, cData, cLength)
}

//export StopNode
func StopNode() {
	if globalChatState != nil {
		if globalCancel != nil {
			globalCancel()
		}

		globalChatState.Sub.Cancel()
		globalChatState.Topic.Close()
		globalChatState.Host.Close()

		globalChatState = nil
		localUser = nil
	}
}

//export GetMyID
func GetMyID() *C.char {
	if globalChatState == nil {
		return C.CString("")
	}
	return C.CString(globalChatState.Host.ID().String())
}

//export GetFullState
func GetFullState(outLength *C.int) *C.uint8_t {
	if lastInitError != nil {
		state := &pb.FullState{
			User:        &pb.User{Id: "ERROR", Name: "Error"},
			CurrentRoom: lastInitError.Error(),
			Network:     "Error",
		}
		data, _ := proto.Marshal(state)
		*outLength = C.int(len(data))
		return (*C.uint8_t)(C.CBytes(data))
	}

	if globalChatState == nil || localUser == nil {
		return nil
	}

	state := &pb.FullState{
		User:        localUser,
		CurrentRoom: globalChatState.CurrentRoom,
		Network:     globalChatState.NetworkName,
	}

	data, err := proto.Marshal(state)
	if err != nil {
		return nil
	}

	*outLength = C.int(len(data))
	return (*C.uint8_t)(C.CBytes(data))
}

//export FreeMemory
func FreeMemory(ptr unsafe.Pointer) {
	if ptr != nil {
		C.free(ptr)
	}
}

func main() {}
