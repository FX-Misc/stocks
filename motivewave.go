package main

import (
	"os"

	"github.com/apex/log"
	"github.com/apex/log/handlers/text"
	"github.com/joho/godotenv"
	"github.com/santacruz123/stocks/motivewave"
)

func main() {
	godotenv.Load()

	log.SetHandler(text.New(os.Stdout))
	log.SetLevel(log.InfoLevel)

	path := os.Getenv("PATH_MWML")

	var mwml motivewave.Markup
	_ = mwml.ImportMWML(path)

	log.Debugf("Markup - %#v\n", mwml)
}
