package main

import (
	"fmt"
	"net"
)

func getBroadcastAddresses(port int) []string {
	var broadcasts []string
	ifaces, err := net.Interfaces()
	if err != nil {
		return []string{fmt.Sprintf("255.255.255.255:%d", port)}
	}
	for _, i := range ifaces {
		if i.Flags&net.FlagLoopback != 0 || i.Flags&net.FlagUp == 0 || i.Flags&net.FlagBroadcast == 0 {
			continue
		}
		addrs, err := i.Addrs()
		if err != nil {
			continue
		}
		for _, a := range addrs {
			ipNet, ok := a.(*net.IPNet)
			if !ok {
				continue
			}
			ip4 := ipNet.IP.To4()
			if ip4 == nil {
				continue
			}
			mask := ipNet.Mask
			bcast := make(net.IP, len(ip4))

			for j := 0; j < len(ip4); j++ {
				bcast[j] = ip4[j] | ^mask[j]
			}
			broadcasts = append(broadcasts, fmt.Sprintf("%s:%d", bcast.String(), port))
		}
	}
	// Добавляем глобальный на всякий случай
	broadcasts = append(broadcasts, fmt.Sprintf("255.255.255.255:%d", port))
	return broadcasts
}
