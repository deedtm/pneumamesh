package pneumacore

import "time"

// обозначения в айди комнат:
// ! - обязательная комната, которая должна быть всегда
// # - сервис-комната = обязательная, для служебных сообщений (поэтому должна быть скрыта в ui)

var (
	NetworkName       = "pneumamesh"
	DiscoveryRoomId   = "#discovery"
	DiscoveryRoomName = "discovery-room"
	SosRoomId         = "#sos"
	SosRoomName       = "SOS"
	MainRoomId        = "!main"
	MainRoomName      = "main-room"

	DefaultRoomsIds = []string{DiscoveryRoomId, SosRoomId, MainRoomId}

	DiscoveryInterval             = 25 * time.Second
	InactiveRoomsRemovingInterval = 61 * time.Second
	RoomDeactivationTime          = 5 * time.Minute
)

var PacketType = struct {
	Message   string
	Sos       string
	Discovery string
}{
	Message:   "MESSAGE",
	Sos:       "SOS",
	Discovery: "DISCOVERY",
}
