package pneumacore

import (
	log "pneumacore/log"
	pb "pneumacore/proto"
	"slices"
	"strings"
	"time"

	pubsub "github.com/libp2p/go-libp2p-pubsub"
	"google.golang.org/protobuf/proto"
)

// добавление комнаты в локальный список
func (pc *PneumaCore) AddRoom(id string, name string) {
	pc.Lock()
	defer pc.Unlock()
	pc.rooms[id] = &Room{
		ID:         id,
		Name:       name,
		LastActive: time.Now(),
	}
}

// получить все комнаты текущего юзера
func (pc *PneumaCore) GetActiveRooms() []Room {
	pc.RLock()
	defer pc.RUnlock()
	var list []Room
	for _, room := range pc.rooms {
		list = append(list, *room)
	}
	return list
}

// получить все комнаты кроме сервисных
func (pc *PneumaCore) GetNotServiceRooms() []Room {
	rooms := pc.GetActiveRooms()
	var list []Room
	for _, room := range rooms {
		if !strings.HasPrefix(room.ID, "#") {
			list = append(list, room)
		}
	}
	return list
}

// получить комнату по айди
func (pc *PneumaCore) GetRoom(id string) *Room {
	pc.RLock()
	defer pc.RUnlock()
	return pc.rooms[id]
}

func (pc *PneumaCore) RemoveRoom(id string) {
	pc.Lock()
	defer pc.Unlock()
	room := *pc.rooms[id]
	pc.rooms[id].Topic.Close()
	delete(pc.rooms, id)
	log.Info("Removed room: %v", room)
}

// установить инстанс топика комнаты
func (pc *PneumaCore) SetTopic(id string, topic *pubsub.Topic) {
	pc.Lock()
	defer pc.Unlock()
	pc.rooms[id].Topic = topic
}

// заблокировать комнату
func (pc *PneumaCore) BlockRoom(id string) {
	pc.Lock()
	defer pc.Unlock()
	pc.BlockedRoomsIds = append(pc.BlockedRoomsIds, id)
}

// разблокировать комнату
func (pc *PneumaCore) UnblockRoom(id string) {
	pc.Lock()
	defer pc.Unlock()
	if i := slices.Index(pc.BlockedRoomsIds, id); i != -1 {
		pc.BlockedRoomsIds = slices.Delete(pc.BlockedRoomsIds, i, i+1)
	}
}

// обновить последнюю активность комнаты
func (pc *PneumaCore) UpdateRoomLastActive(id string, timestamp time.Time) {
	pc.Lock()
	defer pc.Unlock()
	pc.rooms[id].LastActive = timestamp
	log.Info("Changed %q room last active value to %v", pc.rooms[id].Name, timestamp)
}

// удалить неактивные комнаты
func (pc *PneumaCore) RemoveInactiveRooms() {
	var roomsToRemove []string
	pc.RLock()
	for roomId, room := range pc.rooms {
		if slices.Contains(DefaultRoomsIds, roomId) || slices.Contains(pc.BlockedRoomsIds, roomId) {
			continue
		}
		if time.Since(room.LastActive) > RoomDeactivationTime {
			roomsToRemove = append(roomsToRemove, roomId)
		}
	}
	pc.RUnlock()

	if len(roomsToRemove) == 0 {
		return
	}

	pc.Lock()
	for _, roomId := range roomsToRemove {
		pc.rooms[roomId].Topic.Close()
		delete(pc.rooms, roomId)
	}
	pc.Unlock()

	log.Info("Removed inactive rooms: %v", roomsToRemove)
}

// отправка всех своих комнат в дискавери-комнату
func (pc *PneumaCore) startDiscoveryTicker() {
	ticker := time.NewTicker(DiscoveryInterval)
	defer ticker.Stop()

	for {
		select {
		case <-pc.ctx.Done():
			return
		case <-ticker.C:
			pc.SendDiscovery()
		}
	}
}

// удаление неактивных комнат
func (pc *PneumaCore) startInactiveRoomsTicker() {
	ticker := time.NewTicker(InactiveRoomsRemovingInterval)
	defer ticker.Stop()

	for {
		select {
		case <-pc.ctx.Done():
			return
		case <-ticker.C:
			pc.RemoveInactiveRooms()

			rooms := pc.GetNotServiceRooms()
			packet := &pb.DiscoveryPacket{Timestamp: time.Now().Unix(), Type: pb.DiscoveryPacketType_ACTIVE}
			for _, r := range rooms {
				packet.Rooms = append(packet.Rooms, &pb.Room{Id: r.ID, Name: r.Name})
			}
			data, err := proto.Marshal(packet)
			if err != nil {
				log.Error("pneumacore/rooms.go:startInactiveRoomsTicker():1:proto.Marshal(packet): %v", err)
				return
			}
			pc.SendDiscoveryToUi(data)

			log.Info("Sent discovery packet to ui: %v", packet)
		}
	}
}
