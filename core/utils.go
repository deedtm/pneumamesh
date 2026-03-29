package main

import (
	"context"
	"fmt"
	"net"
	"strings"
	"time"

	"pneumamesh-core/pb"

	"github.com/libp2p/go-libp2p/core/host"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/multiformats/go-multiaddr"
	"google.golang.org/protobuf/proto"
)

const discoveryPort = 9999

func setupDiscovery(ctx context.Context, h host.Host, networkName string) error {
	go listenForBroadcasts(ctx, h, networkName)
	go broadcastPresence(ctx, h, networkName)
	return nil
}

func listenForBroadcasts(ctx context.Context, h host.Host, networkName string) {
	addr, err := net.ResolveUDPAddr("udp4", fmt.Sprintf("0.0.0.0:%d", discoveryPort))
	if err != nil {
		return
	}

	conn, err := net.ListenUDP("udp4", addr)
	if err != nil {
		return
	}
	defer conn.Close()

	go func() {
		<-ctx.Done()
		_ = conn.Close()
	}()

	buf := make([]byte, 2048)
	for {
		n, senderAddr, err := conn.ReadFromUDP(buf)
		if err != nil {
			select {
			case <-ctx.Done():
				return
			default:
			}
			continue
		}

		var packet pb.DiscoveryPacket
		if err := proto.Unmarshal(buf[:n], &packet); err != nil {
			continue
		}

		if packet.NetworkName != networkName || packet.PeerId == h.ID().String() {
			continue
		}

		pID, err := peer.Decode(packet.PeerId)
		if err != nil {
			continue
		}

		var mas []multiaddr.Multiaddr
		seen := map[string]struct{}{}
		for _, a := range packet.Addrs {
			if senderAddr != nil && strings.Contains(a, "127.0.0.1") {
				a = strings.Replace(a, "127.0.0.1", senderAddr.IP.String(), 1)
			}

			ma, err := multiaddr.NewMultiaddr(a)
			if err == nil {
				if _, ok := seen[ma.String()]; !ok {
					seen[ma.String()] = struct{}{}
					mas = append(mas, ma)
				}

				if senderAddr != nil {
					tcpPort, err := ma.ValueForProtocol(multiaddr.P_TCP)
					if err == nil {
						candidate := fmt.Sprintf("/ip4/%s/tcp/%s", senderAddr.IP.String(), tcpPort)
						candMA, err := multiaddr.NewMultiaddr(candidate)
						if err == nil {
							if _, ok := seen[candMA.String()]; !ok {
								seen[candMA.String()] = struct{}{}
								mas = append(mas, candMA)
							}
						}
					}
				}
			}
		}

		if len(mas) > 0 {
			peerInfo := peer.AddrInfo{
				ID:    pID,
				Addrs: mas,
			}
			go func() {
				h.Connect(context.Background(), peerInfo)
			}()
		}
	}
}

func broadcastPresence(ctx context.Context, h host.Host, networkName string) {
	ticker := time.NewTicker(3 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
		}

		var addrs []string
		for _, a := range h.Addrs() {
			s := a.String()
			if strings.Contains(s, "ip4") {
				addrs = append(addrs, s)
			}
		}

		packet := &pb.DiscoveryPacket{
			NetworkName: networkName,
			PeerId:      h.ID().String(),
			Addrs:       addrs,
		}

		data, err := proto.Marshal(packet)
		if err != nil {
			continue
		}

		sendDiscoveryPacket(data, fmt.Sprintf("127.0.0.1:%d", discoveryPort))

		bcastAddrs := getBroadcastAddresses(discoveryPort)
		for _, baddr := range bcastAddrs {
			sendDiscoveryPacket(data, baddr)
		}
	}
}

func sendDiscoveryPacket(data []byte, address string) {
	addr, err := net.ResolveUDPAddr("udp4", address)
	if err != nil {
		return
	}

	conn, err := net.DialUDP("udp4", nil, addr)
	if err != nil {
		return
	}
	defer conn.Close()

	_, _ = conn.Write(data)
}
