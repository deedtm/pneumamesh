//go:build android
// +build android

package main

/*
#include <jni.h>
#include <stdlib.h>
#include <android/log.h>

#define LOG_TAG "PNEUMAMESH_GO"

static void log_info(const char* msg) {
    __android_log_write(ANDROID_LOG_INFO, LOG_TAG, msg);
}
static void log_error(const char* msg) {
    __android_log_write(ANDROID_LOG_ERROR, LOG_TAG, msg);
}

static const char* jstring2chars(JNIEnv* env, jstring str) {
    return (*env)->GetStringUTFChars(env, str, NULL);
}
static void freeJString(JNIEnv* env, jstring str, const char* chars) {
    (*env)->ReleaseStringUTFChars(env, str, chars);
}
*/
import "C"

import (
	"fmt"
	"net"
	"context"
	"strings"
	"time"

	"github.com/libp2p/go-libp2p/core/peer"
	"github.com/libp2p/go-libp2p/core/peerstore"
	ma "github.com/multiformats/go-multiaddr"
)

//export Java_com_muwa_pneumamesh_MainActivity_passBridgePortToGo
func Java_com_muwa_pneumamesh_MainActivity_passBridgePortToGo(env *C.JNIEnv, clazz C.jclass, port C.jint, peerId C.jstring, outbound C.jboolean) {
	cPeerId := C.jstring2chars(env, peerId)
	if cPeerId == nil {
		logError("JNI: peerId is null")
		return
	}
	defer C.freeJString(env, peerId, cPeerId)

	remoteStr := strings.TrimSpace(C.GoString(cPeerId))
	logInfo("JNI: Got peerId=%s len=%d", remoteStr, len(remoteStr))

	remotePeer, err := peer.Decode(remoteStr)
	if err != nil {
		logError("JNI: peer.Decode failed: %v (peerId=%s)", err, remoteStr)
		return
	}

	isOutbound := outbound != 0
	goPort := int(port)
	conn, err := net.Dial("tcp", fmt.Sprintf("127.0.0.1:%d", goPort))
	if err != nil {
		logError("JNI: Dial bridge failed: %v", err)
		return
	}
	err = globalInjectTransport.InjectConn(conn, remotePeer, isOutbound)
	if err != nil {
		logError("JNI: InjectConn failed: %v", err)
		conn.Close()
		return
	}

	logInfo("JNI: Bridge connected outbound=%v peer=%s", isOutbound, remotePeer.ShortString())

	if isOutbound && globalChatState != nil && globalChatState.Host != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		globalChatState.Host.Network().Peerstore().AddAddrs(
			remotePeer,
			[]ma.Multiaddr{injectMultiaddr},
			peerstore.PermanentAddrTTL,
		)

		err = globalChatState.Host.Connect(ctx, peer.AddrInfo{
			ID:    remotePeer,
			Addrs: []ma.Multiaddr{injectMultiaddr},
		})
		if err != nil {
			logError("JNI: Host.Connect failed: %v", err)
		} else {
			logInfo("JNI: Host.Connect success")
		}
	}

}
