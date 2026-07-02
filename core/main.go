package main

/*
#include <stdlib.h>
#include <stdint.h>
#include "pneumacore/callbacks_utils.h"
*/
import "C"
import (
	"context"
	"encoding/base64"
	log "pneumacore/log"
	"pneumacore/pneumacore"
	pb "pneumacore/proto"
	tp "pneumacore/transport"
	"unsafe"

	"github.com/google/uuid"
	"github.com/libp2p/go-libp2p/core/crypto"
	"github.com/libp2p/go-libp2p/core/transport"
	"google.golang.org/protobuf/proto"
)

var (
	gCore            *pneumacore.PneumaCore
	gCancel          context.CancelFunc
	gInjectTransport *tp.InjectTransport
)

//export GeneratePrivateKey
func GeneratePrivateKey() *C.char {
	priv, _, err := crypto.GenerateKeyPair(crypto.Ed25519, -1)
	if err != nil {
		log.Error("main.go:GeneratePrivateKey():1:crypto.GenerateKeyPair(crypto.Ed25519, -1): %v", err)
		return C.CString("")
	}
	bytes, err := crypto.MarshalPrivateKey(priv)
	if err != nil {
		log.Error("main.go:GeneratePrivateKey():2:crypto.MarshalPrivateKey(priv): %v", err)
		return C.CString("")
	}
	log.Info("Generated private key: %v", base64.StdEncoding.EncodeToString(bytes))
	return C.CString(base64.StdEncoding.EncodeToString(bytes))
}

//export InitCore
func InitCore(cPrivateKey64 *C.char, cUsername *C.char) {
	if gCore != nil {
		log.Info("main.go:InitCore():1:gCore != nil")
		return
	}

	privateKey64 := C.GoString(cPrivateKey64)
	username := C.GoString(cUsername)

	ctx, cancel := context.WithCancel(context.Background())
	gCancel = cancel
	gCore = pneumacore.NewCore(ctx)
	gCore.StartNetwork(func(up transport.Upgrader) (transport.Transport, error) {
		gInjectTransport = tp.NewInjectTransport(up)
		return gInjectTransport, nil
	}, tp.InjectMultiaddr, privateKey64, username)

	log.Info("Started network with username: %v", username)
}

//export StopCore
func StopCore() {
	if gCore == nil {
		log.Error("main.go:StopCore():1:gCore == nil")
		return
	}
	gCore.StopNetwork()
	if gCancel != nil {
		gCancel()
		gCancel = nil
	}
	gCore = nil

	log.Info("Stopped network")
}

//export GetMe
func GetMe(outLength *C.int) *C.uint8_t {
	if gCore == nil {
		log.Info("main.go:GetMe():1:gCore == nil")
		return nil
	}

	packet := &pb.User{Id: gCore.Host.ID().String(), Name: gCore.Username}

	data, err := proto.Marshal(packet)
	if err != nil || len(data) == 0 {
		log.Error("main.go:GetMe():1:proto.Marshal(packet): %v", err)
		return nil
	}

	*outLength = C.int(len(data))

	log.Info("Sent user packet: %v", packet)

	return (*C.uint8_t)(C.CBytes(data))
}

//export GetRooms
func GetRooms(outLength *C.int) *C.uint8_t {
	if gCore == nil {
		log.Info("main.go:GetRooms():1:gCore == nil")
		return nil
	}

	rooms := gCore.GetNotServiceRooms()
	packet := &pb.DiscoveryPacket{Timestamp: 0, Type: pb.DiscoveryPacketType_SHARE}

	for _, r := range rooms {
		packet.Rooms = append(packet.Rooms, &pb.Room{Id: r.ID, Name: r.Name})
	}

	data, err := proto.Marshal(packet)
	if err != nil || len(data) == 0 {
		log.Error("main.go:GetRooms():1:proto.Marshal(packet): %v", err)
		return nil
	}

	*outLength = C.int(len(data))

	log.Info("Sent rooms packet: %v", packet)

	return (*C.uint8_t)(C.CBytes(data))
}

//export RegisterDiscoveryCallback
func RegisterDiscoveryCallback(cb C.DiscoveryCallback) {
	if gCore == nil {
		log.Info("main.go:RegisterDiscoveryCallback():1:gCore == nil")
		return
	}
	gCore.RegisterDiscoveryCallback(unsafe.Pointer(cb))
	log.Info("Registered discovery callback")
}

//export RegisterSosCallback
func RegisterSosCallback(cb C.SosCallback) {
	if gCore == nil {
		log.Info("main.go:RegisterSosCallback():1:gCore == nil")
		return
	}
	gCore.RegisterSosCallback(unsafe.Pointer(cb))
	log.Info("Registered sos callback")
}

//export RegisterMessageCallback
func RegisterMessageCallback(cb C.MessageCallback) {
	if gCore == nil {
		log.Info("main.go:RegisterMessageCallback():1:gCore == nil")
		return
	}
	gCore.RegisterMessageCallback(unsafe.Pointer(cb))
	log.Info("Registered message callback")
}

func importRoom(roomId string, roomName string) *pb.Room {
	if gCore == nil {
		log.Info("main.go:importRoom():1:gCore == nil")
	}
	existingRoom := gCore.GetRoom(roomId)
	if existingRoom != nil {
		return &pb.Room{Id: existingRoom.ID, Name: existingRoom.Name}
	}

	topic, sub := gCore.JoinRoom(roomId)
	if topic == nil || sub == nil {
		log.Error("main.go:importRoom():1:gCore.JoinRoom(roomId):topic, sub == %v, %v", topic, sub)
		return nil
	}
	gCore.AddRoom(roomId, roomName)
	gCore.SetTopic(roomId, topic)
	go gCore.ListenMessages(sub)

	room := &pb.Room{Id: roomId, Name: roomName}
	log.Info("Imported room: %v", room)

	return room
}

//export ImportRoom
func ImportRoom(cRoomId *C.char, cRoomName *C.char) {
	roomId := C.GoString(cRoomId)
	roomName := C.GoString(cRoomName)
	importRoom(roomId, roomName)
}

//export CreateRoom
func CreateRoom(cRoomName *C.char, outLength *C.int) *C.uint8_t {
	roomName := C.GoString(cRoomName)
	roomId := uuid.New().String()

	packet := importRoom(roomId, roomName)

	data, err := proto.Marshal(packet)
	if err != nil {
		log.Error("main.go:CreateRoom():2:proto.Marshal(packet): %v", err)
		return nil
	}
	*outLength = C.int(len(data))

	log.Info("Created room: %v", packet)

	return (*C.uint8_t)(C.CBytes(data))
}

//export BlockRoom
func BlockRoom(cRoomId *C.char) {
	if gCore == nil {
		log.Info("main.go:BlockRoom():1:gCore == nil")
		return
	}
	roomId := C.GoString(cRoomId)
	gCore.BlockRoom(roomId)
	log.Info("Blocked room: %v", roomId)
}

//export UnblockRoom
func UnblockRoom(cRoomId *C.char) {
	if gCore == nil {
		log.Info("main.go:UnblockRoom():1:gCore == nil")
		return
	}
	roomId := C.GoString(cRoomId)
	gCore.UnblockRoom(roomId)
	log.Info("Unblocked room: %v", roomId)
}

//export SendMessage
func SendMessage(data *C.uint8_t, length C.int) {
	if gCore == nil {
		log.Info("main.go:SendMessage():1:gCore == nil")
		return
	}
	bytes := C.GoBytes(unsafe.Pointer(data), length)

	var packet pb.MessagePacket
	err := proto.Unmarshal(bytes, &packet)
	if err != nil {
		log.Error("main.go:SendMessage():2:proto.Unmarshal(bytes, &packet):%v", err)
		return
	}

	gCore.SendMessage(&packet)

	log.Info("Sent message: %v", &packet)
}

//export SendSos
func SendSos(data *C.uint8_t, length C.int) {
	bytes := C.GoBytes(unsafe.Pointer(data), length)

	var pos pb.PositionInfo
	err := proto.Unmarshal(bytes, &pos)

	if err != nil {
		log.Error("main.go:SendSos():1:proto.Unmarshal(bytes, &pos):%v", err)
		return
	}
	gCore.SendSos(&pos)
}

//export FreeMemory
func FreeMemory(ptr unsafe.Pointer) {
	if ptr != nil {
		C.free(ptr)
	}
}

func main() {}
