package main

import (
	"context"
	"pneumamesh-core/pb"

	pubsub "github.com/libp2p/go-libp2p-pubsub"
	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/peer"
	"google.golang.org/protobuf/proto"
)

type ChatState struct {
	Host        host.Host
	PubSub      *pubsub.PubSub
	Topic       *pubsub.Topic
	Sub         *pubsub.Subscription
	NetworkName string
	CurrentRoom string
	Ctx         context.Context
}

func (c *ChatState) StartListener() {
	go func(sub *pubsub.Subscription) {
		for {
			msg, err := sub.Next(c.Ctx)
			if err != nil {
				return
			}

			parsedMsg := &pb.ChatMessage{}

			err = proto.Unmarshal(msg.Data, parsedMsg)
			if err != nil {
				continue
			}

			if peer.ID(parsedMsg.Sender.Id) == c.Host.ID() {
				continue
			}

			sendToDart(msg.Data)
		}
	}(c.Sub)
}

func (c *ChatState) HandleJoin(rooms ...string) {
	if len(rooms) == 0 {
		return
	}

	newRoom := rooms[0]

	c.Sub.Cancel()
	c.Topic.Close()

	c.Topic, _ = c.PubSub.Join(newRoom)
	c.Sub, _ = c.Topic.Subscribe()
	c.CurrentRoom = newRoom

	c.StartListener()
}
