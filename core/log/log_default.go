//go:build !android
// +build !android

package log

func Info(format string, args ...interface{})  {}
func Error(format string, args ...interface{}) {}
