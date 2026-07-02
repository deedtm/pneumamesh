//go:build android
// +build android

package main

/*
#include <jni.h>
#include <stdlib.h>

static const char* javaStringToChars(JNIEnv* env, jstring str) {
    return (*env)->GetStringUTFChars(env, str, NULL);
}
static void freeJavaString(JNIEnv* env, jstring str, const char* chars) {
    (*env)->ReleaseStringUTFChars(env, str, chars);
}
*/
import "C"

import (
	"context"
	"fmt"
	"net"
	log "pneumacore/log"
	tp "pneumacore/transport"
	"strings"
	"time"

	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/libp2p/go-libp2p/core/peerstore"
	ma "github.com/multiformats/go-multiaddr"
)

//export Java_com_muwa_pneumamesh_MainActivity_passBridgePortToGo
func Java_com_muwa_pneumamesh_MainActivity_passBridgePortToGo(env *C.JNIEnv, clazz C.jclass, port C.jint, peerId C.jstring, outbound C.jboolean) {
	cPeerId := C.javaStringToChars(env, peerId)
	if cPeerId == nil {
		log.Error("JNI: peerId is null")
		return
	}
	defer C.freeJavaString(env, peerId, cPeerId)

	remoteStr := strings.TrimSpace(C.GoString(cPeerId))
	log.Info("JNI: Got peerId=%s len=%d", remoteStr, len(remoteStr))

	remotePeer, err := peer.Decode(remoteStr)
	if err != nil {
		log.Error("JNI: peer.Decode failed: %v (peerId=%s)", err, remoteStr)
		return
	}

	isOutbound := outbound != 0
	goPort := int(port)
	conn, err := net.Dial("tcp", fmt.Sprintf("127.0.0.1:%d", goPort))
	if err != nil {
		log.Error("JNI: Dial bridge failed: %v", err)
		return
	}
	err = gInjectTransport.InjectConn(conn, remotePeer, isOutbound)
	if err != nil {
		log.Error("JNI: InjectConn failed: %v", err)
		conn.Close()
		return
	}

	log.Info("JNI: Bridge connected outbound=%v peer=%s", isOutbound, remotePeer.ShortString())

	if isOutbound && gCore.Host != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		gCore.Host.Network().Peerstore().AddAddrs(
			remotePeer,
			[]ma.Multiaddr{tp.InjectMultiaddr},
			peerstore.PermanentAddrTTL,
		)

		err = gCore.Host.Connect(ctx, peer.AddrInfo{
			ID:    remotePeer,
			Addrs: []ma.Multiaddr{tp.InjectMultiaddr},
		})
		if err != nil {
			log.Error("JNI: Host.Connect failed: %v", err)
		} else {
			log.Info("JNI: Host.Connect success")
		}
	}

}
