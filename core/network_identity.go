package main

import (
	"crypto/sha1"
	"encoding/hex"
	"net"
	"sort"
	"strconv"
	"strings"
)

func inferLocalNetworkIdentity() (ssid string, bssid string) {
	ifaces, err := net.Interfaces()
	if err != nil {
		return "desktop-network", "desktop-bssid"
	}

	parts := make([]string, 0, len(ifaces))
	for _, iface := range ifaces {
		if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
			continue
		}

		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}

		hasIPv4 := false
		for _, a := range addrs {
			ipNet, ok := a.(*net.IPNet)
			if !ok || ipNet.IP.To4() == nil {
				continue
			}
			hasIPv4 = true
			ones, _ := ipNet.Mask.Size()
			parts = append(parts, iface.Name+"|"+iface.HardwareAddr.String()+"|"+ipNet.IP.Mask(ipNet.Mask).String()+"/"+strconv.Itoa(ones))
		}

		if hasIPv4 && iface.HardwareAddr.String() != "" {
			parts = append(parts, iface.Name+"|"+iface.HardwareAddr.String())
		}
	}

	if len(parts) == 0 {
		return "desktop-network", "desktop-bssid"
	}

	sort.Strings(parts)
	joined := strings.Join(parts, ";")
	sum := sha1.Sum([]byte(joined))
	hexHash := hex.EncodeToString(sum[:])

	ssid = hexHash[:8]
	bssid = hexHash[8:20]
	return ssid, bssid
}
