package main

import (
	"io/ioutil"
	"os"
	"strings"

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

	files, err := ioutil.ReadDir(path)

	if err != nil {
		log.Fatal(err.Error())
	}

	for _, f := range files {

		if !f.IsDir() {
			continue
		}

		symbol := strings.Split(f.Name(), ".")
		mwml := path + "/" + f.Name() + "/Trade.mwml"

		context := log.WithField("Symbol", symbol[0])

		if _, err := os.Stat(mwml); os.IsNotExist(err) {
			context.Error("Missing Trade.mwml")
			continue
		}

		markup := motivewave.Markup{Symbol: symbol[0]}
		markup.CreateSymbol()

		if err := markup.ImportMWML(mwml); err != nil {
			context.Error(err.Error())
			continue
		}

		if err := markup.SaveSLTP(); err != nil {
			context.Error(err.Error())
			continue
		}
	}
}
