package main

import (
	"context"
	"errors"
	"net"
	"sync"

	"github.com/libp2p/go-libp2p/core/network"
	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/libp2p/go-libp2p/core/transport"
	ma "github.com/multiformats/go-multiaddr"
	manet "github.com/multiformats/go-multiaddr/net"
)

type injectedConn struct {
	conn     net.Conn
	remoteID peer.ID
	outbound bool
}

type InjectTransport struct {
	upgrader transport.Upgrader
	mu       sync.Mutex
	closed   bool
	outbound chan injectedConn
	inbound  chan injectedConn
}

func NewInjectTransport(up transport.Upgrader) *InjectTransport {
	return &InjectTransport{
		upgrader: up,
		outbound: make(chan injectedConn, 64),
		inbound:  make(chan injectedConn, 64),
	}
}

func (t *InjectTransport) InjectConn(conn net.Conn, remote peer.ID, outbound bool) error {
	t.mu.Lock()
	defer t.mu.Unlock()
	if t.closed {
		return errors.New("transport closed")
	}
	if outbound {
		t.outbound <- injectedConn{conn: conn, remoteID: remote, outbound: true}
	} else {
		t.inbound <- injectedConn{conn: conn, remoteID: remote, outbound: false}
	}
	return nil
}

func (t *InjectTransport) Dial(ctx context.Context, raddr ma.Multiaddr, p peer.ID) (transport.CapableConn, error) {
	logInfo("[INJECT] Dial waiting outbound peer=%s", p)
	select {
	case item := <-t.outbound:
		remote := item.remoteID
		if remote == "" {
			remote = p
		}
		logInfo("[INJECT] Dial got outbound peer=%s", remote)
		return t.upgradeConn(ctx, item.conn, remote, network.DirOutbound)
	case <-ctx.Done():
		return nil, ctx.Err()
	}
}

func (t *InjectTransport) Listen(laddr ma.Multiaddr) (transport.Listener, error) {
	return &injectListener{t: t, laddr: laddr}, nil
}

func (t *InjectTransport) CanDial(addr ma.Multiaddr) bool { return true }
func (t *InjectTransport) Protocols() []int               { return []int{ma.P_TCP} }
func (t *InjectTransport) Proxy() bool                    { return false }

func (t *InjectTransport) Close() error {
	t.mu.Lock()
	defer t.mu.Unlock()
	t.closed = true
	close(t.outbound)
	close(t.inbound)
	return nil
}

var injectMultiaddr = mustMultiaddr("/ip4/127.0.0.1/tcp/1")

func mustMultiaddr(s string) ma.Multiaddr {
	m, _ := ma.NewMultiaddr(s)
	return m
}

func (t *InjectTransport) upgradeConn(ctx context.Context, conn net.Conn, remote peer.ID, dir network.Direction) (transport.CapableConn, error) {
	logInfo("[INJECT] upgradeConn start dir=%v remote=%s", dir, remote)
	maconn, err := manet.WrapNetConn(conn)
	if err != nil {
		logError("[INJECT] WrapNetConn failed: %v", err)
		return nil, err
	}
	logInfo("[INJECT] WrapNetConn ok")
	rm := &network.NullResourceManager{}
	scope, err := rm.OpenConnection(dir, false, injectMultiaddr)
	if err != nil {
		logError("[INJECT] OpenConnection failed: %v", err)
		return nil, err
	}
	logInfo("[INJECT] calling Upgrade...")
	cc, err := t.upgrader.Upgrade(ctx, t, maconn, dir, remote, scope)
	if err != nil {
		logError("[INJECT] Upgrade failed: %v", err)
		return nil, err
	}
	logInfo("[INJECT] Upgrade success")
	return cc, nil
}

type injectListener struct {
	t     *InjectTransport
	laddr ma.Multiaddr
}

func (l *injectListener) Accept() (transport.CapableConn, error) {
	item, ok := <-l.t.inbound
	if !ok {
		logError("[INJECT] Accept: listener closed")
		return nil, errors.New("listener closed")
	}
	logInfo("[INJECT] Accept got inbound peer=%s", item.remoteID)
	// inbound: remote peer ID unknown until handshake; pass empty to let upgrader discover it
	return l.t.upgradeConn(context.Background(), item.conn, "", network.DirInbound)
}

func (l *injectListener) Close() error            { return nil }
func (l *injectListener) Addr() net.Addr          { return nil }
func (l *injectListener) Multiaddr() ma.Multiaddr { return l.laddr }
