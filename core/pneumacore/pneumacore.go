package pneumacore

/*
#include "callbacks_utils.h"
*/
import "C"

import (
	"context"
	"sync"
	"time"
	"unsafe"

	pubsub "github.com/libp2p/go-libp2p-pubsub"
	"github.com/libp2p/go-libp2p/core/host"
)

// структура комнаты
// ID - uuid генерируемый в ядре при добавлении комнаты
// Name - имя идущее из ui при добавлении, которое будут видеть юзеры
// LastActive - последняя активность (каждые N сек юзер посылает пинг в сервис комнату, где N - значение из config.go)
// Topic - инстанс топика для отправки сообщений
type Room struct {
	ID         string
	Name       string
	LastActive time.Time
	Topic      *pubsub.Topic
}

// заблокированная (blocked) комната - комната, которую нельзя удалять из списка всех комнат, даже если она стала неактивна

type PneumaCore struct {
	sync.RWMutex
	ctx               context.Context
	rooms             map[string]*Room
	Host              host.Host
	Username          string
	pubsub            *pubsub.PubSub
	discoveryTopic    *pubsub.Topic
	sosTopic          *pubsub.Topic
	Cancel            context.CancelFunc
	DiscoveryCallback unsafe.Pointer
	SosCallback       unsafe.Pointer
	MessageCallback   unsafe.Pointer
	BlockedRoomsIds   []string
}

// создание объекта ядра
func NewCore(ctx context.Context) *PneumaCore {
	rooms := map[string]*Room{
		DiscoveryRoomId: {
			ID:         DiscoveryRoomId,
			Name:       DiscoveryRoomName,
			LastActive: time.Now(),
		},
		SosRoomId: {
			ID:         SosRoomId,
			Name:       SosRoomName,
			LastActive: time.Now(),
		},
		MainRoomId: {
			ID:         MainRoomId,
			Name:       MainRoomName,
			LastActive: time.Now(),
		},
	}

	pc := &PneumaCore{
		ctx:   ctx,
		rooms: rooms,
	}
	go pc.startDiscoveryTicker()
	go pc.startInactiveRoomsTicker()
	return pc
}

func (pc *PneumaCore) ResetCallbacks() {
	pc.DiscoveryCallback = nil
	pc.SosCallback = nil
	pc.MessageCallback = nil
}
