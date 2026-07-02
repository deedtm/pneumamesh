package pneumacore

import (
	"context"
	"encoding/base64"
	log "pneumacore/log"
	pb "pneumacore/proto"
	"time"

	"github.com/libp2p/go-libp2p"
	pubsub "github.com/libp2p/go-libp2p-pubsub"
	"github.com/libp2p/go-libp2p/core/crypto"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/multiformats/go-multiaddr"
	"google.golang.org/protobuf/proto"
)

func (pc *PneumaCore) StartNetwork(transportConstructor any, injectMultiaddr multiaddr.Multiaddr, privateKeyB64 string, username string) {
	ctx, cancel := context.WithCancel(context.Background())

	pc.ctx = ctx
	pc.Cancel = cancel

	options := []libp2p.Option{
		libp2p.NoListenAddrs,
		libp2p.DisableRelay(),
		libp2p.Ping(false),
		libp2p.Transport(transportConstructor),
	}

	if privateKeyB64 != "" {
		keyBytes, err := base64.StdEncoding.DecodeString(privateKeyB64)
		if err == nil {
			privKey, err := crypto.UnmarshalPrivateKey(keyBytes)
			if err == nil {
				options = append(options, libp2p.Identity(privKey))
			}
		}
	}

	h, err := libp2p.New(options...)
	if err != nil {
		log.Error("pneumacore/network.go:StartNetwork():1:libp2p.New(options...): %v", err)
		return
	}
	pc.Host = h
	pc.Username = username

	_ = pc.Host.Network().Listen(injectMultiaddr)

	ps, err := pubsub.NewGossipSub(ctx, pc.Host)
	if err != nil {
		log.Error("pneumacore/network.go:StartNetwork():2:pubsub.NewGossipSub(ctx, pc.host): %v", err)
		return
	}
	pc.pubsub = ps

	var sub *pubsub.Subscription
	var topic *pubsub.Topic
	rooms := pc.GetActiveRooms()
	for _, r := range rooms {
		topic, sub = pc.JoinRoom(r.ID)
		if topic != nil && sub != nil {
			pc.SetTopic(r.ID, topic)
			switch r.ID {
			case DiscoveryRoomId:
				pc.discoveryTopic = topic
				go pc.listenDiscovery(sub)
			case SosRoomId:
				pc.sosTopic = topic
				go pc.listenSos(sub)
			default:
				go pc.ListenMessages(sub)
			}
		}
	}
}

func (pc *PneumaCore) StopNetwork() {
	rooms := pc.GetActiveRooms()
	for _, r := range rooms {
		if r.Topic != nil {
			r.Topic.Close()
		}
	}

	pc.Lock()
	for k := range pc.rooms {
		delete(pc.rooms, k)
	}
	pc.Unlock()

	if pc.Host != nil {
		pc.Host.Close()
	}
	if pc.Cancel != nil {
		pc.Cancel()
	}
	pc.Cancel = nil
}

func (pc *PneumaCore) JoinRoom(roomID string) (*pubsub.Topic, *pubsub.Subscription) {
	topic, err := pc.pubsub.Join(roomID)
	if err != nil {
		log.Error("pneumacore/network.go:joinRoom():1:pc.pubsub.Join(roomID): %v", err)
		return nil, nil
	}
	sub, err := topic.Subscribe()
	if err != nil {
		log.Error("pneumacore/network.go:joinRoom():2:topic.Subscribe(): %v", err)
		return nil, nil
	}
	return topic, sub
}

// отправляем дискавери сами
func (pc *PneumaCore) SendDiscovery() {
	if pc.discoveryTopic == nil {
		return
	}
	packet := &pb.DiscoveryPacket{Timestamp: time.Now().Unix(), Type: pb.DiscoveryPacketType_SHARE}
	rooms := pc.GetNotServiceRooms()
	for _, r := range rooms {
		packet.Rooms = append(packet.Rooms, &pb.Room{Id: r.ID, Name: r.Name})
	}
	data, err := proto.Marshal(packet)
	if err != nil {
		log.Error("pneumacore/network.go:sendDiscovery():1:proto.Marshal(packet): %v", err)
		return
	}
	pc.discoveryTopic.Publish(pc.ctx, data)
}

// отправляем сос сами
func (pc *PneumaCore) SendSos(position *pb.PositionInfo) {
	if pc.sosTopic == nil {
		return
	}
	packet := &pb.SosPacket{
		Sender: &pb.User{
			Id:   pc.Host.ID().String(),
			Name: pc.Username,
		},
		Position: position,
	}
	data, err := proto.Marshal(packet)
	if err != nil {
		log.Error("pneumacore/network.go:sendSos():1:proto.Marshal(packet): %v", err)
		return
	}
	pc.sosTopic.Publish(pc.ctx, data)
}

// отправляем сообщение сами
func (pc *PneumaCore) SendMessage(packet *pb.MessagePacket) {
	room := pc.GetRoom(packet.Room.Id)

	if room == nil {
		log.Error("pneumacore/network.go:sendMessage():1:room==nil")
		return
	} else if room.Topic == nil {
		log.Error("pneumacore/network.go:sendMessage():2:room.Topic==nil")
		return
	}

	data, err := proto.Marshal(packet)
	if err != nil {
		log.Error("pneumacore/network.go:sendMessage():3:proto.Marshal(packet): %v", err)
		return
	}

	err = room.Topic.Publish(pc.ctx, data)
	if err != nil {
		log.Error("pneumacore/network.go:sendMessage():4:room.Topic.Publish(pc.ctx, data): %v", err)
		return
	}

	pc.UpdateRoomLastActive(packet.Room.Id, time.Unix(packet.Timestamp, 0))
}

// слушаем чужие дискавери
func (pc *PneumaCore) listenDiscovery(sub *pubsub.Subscription) {
	packet := &pb.DiscoveryPacket{}

	for {
		msg, err := sub.Next(pc.ctx)
		if err != nil {
			log.Error("pneumacore/network.go:listenDiscovery():1:sub.Next(pc.ctx): %v", err)
			return
		}

		err = proto.Unmarshal(msg.Data, packet)
		if err != nil {
			continue
		}

		rooms := packet.GetRooms()
		currentRooms := pc.GetActiveRooms()

		var newRooms []*pb.Room
		var isNew bool
		for _, newRoom := range rooms {
			isNew = true
			for _, room := range currentRooms {
				if room.ID == newRoom.Id {
					isNew = false
					break
				}
			}
			if isNew {
				newRooms = append(newRooms, newRoom)
			}
		}

		if len(newRooms) == 0 {
			continue
		}

		var roomId, roomName string
		var topic *pubsub.Topic
		var sub *pubsub.Subscription
		for _, r := range newRooms {
			roomId = r.GetId()
			roomName = r.GetName()

			if pc.GetRoom(roomId) != nil {
				log.Info("pneumacore/network.go:listenDiscovery(): Room %s already exists in pc.rooms, skipping join.", roomId)
				continue
			}
			topic, sub = pc.JoinRoom(roomId)
			if sub == nil {
				continue
			}
			pc.AddRoom(roomId, roomName)
			pc.SetTopic(roomId, topic)
			go pc.ListenMessages(sub)
		}

		allRoomsPacket := &pb.DiscoveryPacket{}
		for _, r := range currentRooms {
			allRoomsPacket.Rooms = append(allRoomsPacket.Rooms, &pb.Room{Id: r.ID, Name: r.Name})
		}
		allRoomsData, err := proto.Marshal(packet)
		if err != nil {
			log.Error("pneumacore/network.go:listenDiscovery():2:proto.Marshal(packet): %v", err)
			return
		}
		pc.SendDiscoveryToUi(allRoomsData)
	}
}

// слушаем чужие сос
func (pc *PneumaCore) listenSos(sub *pubsub.Subscription) {
	packet := &pb.SosPacket{}

	for {
		msg, err := sub.Next(pc.ctx)
		if err != nil {
			log.Error("pneumacore/network.go:listenSos():1:sub.Next(pc.ctx): %v", err)
			return
		}

		err = proto.Unmarshal(msg.Data, packet)
		if err != nil {
			continue
		}

		sender := packet.GetSender()
		if sender == nil || peer.ID(sender.Id) == pc.Host.ID() {
			continue
		}

		pc.SendSosToUi(msg.Data)
	}
}

// слушаем чужие сообщения
func (pc *PneumaCore) ListenMessages(sub *pubsub.Subscription) {
	packet := &pb.MessagePacket{}
	for {
		msg, err := sub.Next(pc.ctx)
		if err != nil {
			log.Error("pneumacore/network.go:listenMessages():1:sub.Next(pc.ctx): %v", err)
			return
		}

		err = proto.Unmarshal(msg.Data, packet)
		if err != nil {
			continue
		}

		sender := packet.GetSender()
		if sender == nil || peer.ID(sender.Id) == pc.Host.ID() {
			continue
		}

		pc.SendMessageToUi(msg.Data)
		pc.UpdateRoomLastActive(packet.Room.Id, time.Unix(packet.Timestamp, 0))
	}
}
