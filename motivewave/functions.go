package motivewave

import (
	"database/sql"
	"encoding/xml"
	"io/ioutil"
	"os"

	// DB
	_ "github.com/lib/pq"

	"github.com/apex/log"
)

//NewMarkup factory
func NewMarkup(symbol string) *Markup {
	return &Markup{Symbol: symbol}
}

//ImportMWML from file
func (m *Markup) ImportMWML(path string) error {
	log.Debug("Importing " + path + "\n")

	data, err := ioutil.ReadFile(path)

	if err != nil {
		return err
	}

	defer log.Debugf("Markup - %#v\n", m)

	return xml.Unmarshal(data, m)
}

//SaveWaves in db
func (m *Markup) SaveWaves() error {
	db, err := sql.Open("postgres", "")
	if err != nil {
		return err
	}

	defer db.Close()

	var symbolID int64

	db.QueryRow("SELECT id FROM symbols WHERE title = $1::TEXT", m.Symbol).Scan(&symbolID)

	if symbolID == 0 {
		db.Exec("INSERT INTO symbols(title) VALUES($1::TEXT)", m.Symbol)
	}

	_, err = db.Exec("DELETE FROM waves WHERE symbol = $1", symbolID)
	if err != nil {
		return err
	}

	dir, err := os.Getwd()
	if err != nil {
		return err
	}

	wavesSQL, err := ioutil.ReadFile(dir + "/../sql/stmts/waves.sql")
	if err != nil {
		return err
	}

	wavesStmt, err := db.Prepare(string(wavesSQL))
	if err != nil {
		return err
	}
	defer wavesStmt.Close()

	subwavesSQL, err := ioutil.ReadFile(dir + "/../sql/stmts/subwaves.sql")
	if err != nil {
		return err
	}

	subwavesStmt, err := db.Prepare(string(subwavesSQL))
	if err != nil {
		return err
	}
	defer subwavesStmt.Close()

	//TODO Notify if zero waves in Markup

	for _, i := range m.Impulses {

		// Itself
		_, err = wavesStmt.Exec(
			symbolID,
			i.ID,
			i.ParentID,
			i.Degree,
			"impulse",
			nil,
			i.Origin.T,
			i.Origin.P,
			i.Wave5.T,
			i.Wave5.P,
		)

		if err != nil {
			return err
		}

		// Subwaves

		// W1
		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"impulse",
			"w1",
			i.Origin.T,
			i.Origin.P,
			i.Wave1.T,
			i.Wave1.P,
		)

		if err != nil {
			return err
		}

		// W2
		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"w2",
			i.Wave1.T,
			i.Wave1.P,
			i.Wave2.T,
			i.Wave2.P,
		)

		if err != nil {
			return err
		}

		// W3
		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"impulse",
			"w3",
			i.Wave2.T,
			i.Wave2.P,
			i.Wave3.T,
			i.Wave3.P,
		)

		if err != nil {
			return err
		}

		// W4
		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"w4",
			i.Wave3.T,
			i.Wave3.P,
			i.Wave4.T,
			i.Wave4.P,
		)

		if err != nil {
			return err
		}

		// W5
		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"impulse",
			"w5",
			i.Wave4.T,
			i.Wave4.P,
			i.Wave5.T,
			i.Wave5.P,
		)

		if err != nil {
			return err
		}
	}

	for _, i := range m.ImpulsesLeading {

		// Itself
		_, err = wavesStmt.Exec(
			symbolID,
			i.ID,
			i.ParentID,
			i.Degree,
			"leading",
			nil,
			i.Origin.T,
			i.Origin.P,
			i.Wave5.T,
			i.Wave5.P,
		)

		if err != nil {
			return err
		}

		// Subwaves

		// W1
		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"impulse",
			"w1",
			i.Origin.T,
			i.Origin.P,
			i.Wave1.T,
			i.Wave1.P,
		)

		if err != nil {
			return err
		}

		// W2
		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"w2",
			i.Wave1.T,
			i.Wave1.P,
			i.Wave2.T,
			i.Wave2.P,
		)

		if err != nil {
			return err
		}

		// W3
		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"impulse",
			"w3",
			i.Wave2.T,
			i.Wave2.P,
			i.Wave3.T,
			i.Wave3.P,
		)

		if err != nil {
			return err
		}

		// W4
		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"w4",
			i.Wave3.T,
			i.Wave3.P,
			i.Wave4.T,
			i.Wave4.P,
		)

		if err != nil {
			return err
		}

		// W5
		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"impulse",
			"w5",
			i.Wave4.T,
			i.Wave4.P,
			i.Wave5.T,
			i.Wave5.P,
		)

		if err != nil {
			return err
		}

	}

	for _, i := range m.ImpulsesEnding {

		// Itself
		_, err = wavesStmt.Exec(
			symbolID,
			i.ID,
			i.ParentID,
			i.Degree,
			"ending",
			nil,
			i.Origin.T,
			i.Origin.P,
			i.Wave5.T,
			i.Wave5.P,
		)

		if err != nil {
			return err
		}

		// Subwaves

		// W1
		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"w1",
			i.Origin.T,
			i.Origin.P,
			i.Wave1.T,
			i.Wave1.P,
		)

		if err != nil {
			return err
		}

		// W2
		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"w2",
			i.Wave1.T,
			i.Wave1.P,
			i.Wave2.T,
			i.Wave2.P,
		)

		if err != nil {
			return err
		}

		// W3
		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"w3",
			i.Wave2.T,
			i.Wave2.P,
			i.Wave3.T,
			i.Wave3.P,
		)

		if err != nil {
			return err
		}

		// W4
		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"w4",
			i.Wave3.T,
			i.Wave3.P,
			i.Wave4.T,
			i.Wave4.P,
		)

		if err != nil {
			return err
		}

		// W5
		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"w5",
			i.Wave4.T,
			i.Wave4.P,
			i.Wave5.T,
			i.Wave5.P,
		)

		if err != nil {
			return err
		}

	}

	// Corrections

	for _, i := range m.Corrections {

		// Itself
		_, err = wavesStmt.Exec(
			symbolID,
			i.ID,
			i.ParentID,
			i.Degree,
			"correction",
			nil,
			i.Origin.T,
			i.Origin.P,
			i.WaveC.T,
			i.WaveC.P,
		)

		if err != nil {
			return err
		}

		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"impulse",
			"a",
			i.Origin.T,
			i.Origin.P,
			i.WaveA.T,
			i.WaveA.P,
		)

		if err != nil {
			return err
		}

		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"b",
			i.WaveA.T,
			i.WaveA.P,
			i.WaveB.T,
			i.WaveB.P,
		)

		if err != nil {
			return err
		}

		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"impulse",
			"c",
			i.WaveB.T,
			i.WaveB.P,
			i.WaveC.T,
			i.WaveC.P,
		)

		if err != nil {
			return err
		}
	}

	// Triangle

	for _, i := range m.Triangles {

		// Itself
		_, err = wavesStmt.Exec(
			symbolID,
			i.ID,
			i.ParentID,
			i.Degree,
			"triangle",
			"w4",
			i.Origin.T,
			i.Origin.P,
			i.WaveE.T,
			i.WaveE.P,
		)

		if err != nil {
			return err
		}

		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"a",
			i.Origin.T,
			i.Origin.P,
			i.WaveA.T,
			i.WaveA.P,
		)

		if err != nil {
			return err
		}

		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"b",
			i.WaveA.T,
			i.WaveA.P,
			i.WaveB.T,
			i.WaveB.P,
		)

		if err != nil {
			return err
		}

		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"c",
			i.WaveB.T,
			i.WaveB.P,
			i.WaveC.T,
			i.WaveC.P,
		)

		if err != nil {
			return err
		}

		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"d",
			i.WaveC.T,
			i.WaveC.P,
			i.WaveD.T,
			i.WaveD.P,
		)

		if err != nil {
			return err
		}

		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"e",
			i.WaveD.T,
			i.WaveD.P,
			i.WaveE.T,
			i.WaveE.P,
		)

		if err != nil {
			return err
		}
	}

	// Combo

	for _, i := range m.Combo {

		// Itself
		_, err = wavesStmt.Exec(
			symbolID,
			i.ID,
			i.ParentID,
			i.Degree,
			"combo",
			"w4",
			i.Origin.T,
			i.Origin.P,
			i.WaveY.T,
			i.WaveY.P,
		)

		if err != nil {
			return err
		}

		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"w",
			i.Origin.T,
			i.Origin.P,
			i.WaveW.T,
			i.WaveW.P,
		)

		if err != nil {
			return err
		}

		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"x",
			i.WaveW.T,
			i.WaveW.P,
			i.WaveX.T,
			i.WaveX.P,
		)

		if err != nil {
			return err
		}

		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"y",
			i.WaveX.T,
			i.WaveX.P,
			i.WaveY.T,
			i.WaveY.P,
		)

		if err != nil {
			return err
		}
	}

	// TripleCombo

	for _, i := range m.TripleCombo {

		finishT := i.WaveY.T
		finishP := i.WaveY.P
		wave := "combo"

		if i.WaveX2.T != 0 {
			finishT = i.WaveZ.T
			finishP = i.WaveZ.P
			wave = "triple"
		}

		// Itself
		_, err = wavesStmt.Exec(
			symbolID,
			i.ID,
			i.ParentID,
			i.Degree,
			wave,
			"w4",
			i.Origin.T,
			i.Origin.P,
			finishT,
			finishP,
		)

		if err != nil {
			return err
		}

		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"w",
			i.Origin.T,
			i.Origin.P,
			i.WaveW.T,
			i.WaveW.P,
		)

		if err != nil {
			return err
		}

		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"x",
			i.WaveW.T,
			i.WaveW.P,
			i.WaveX.T,
			i.WaveX.P,
		)

		if err != nil {
			return err
		}

		_, err = subwavesStmt.Exec(
			symbolID,
			0,
			i.ID,
			i.Degree,
			"correction",
			"y",
			i.WaveX.T,
			i.WaveX.P,
			i.WaveY.T,
			i.WaveY.P,
		)

		if err != nil {
			return err
		}

		if i.WaveX2.T != 0 {

			_, err = subwavesStmt.Exec(
				symbolID,
				0,
				i.ID,
				i.Degree,
				"correction",
				"x2",
				i.WaveY.T,
				i.WaveY.P,
				i.WaveX2.T,
				i.WaveX2.P,
			)

			if err != nil {
				return err
			}

			_, err = subwavesStmt.Exec(
				symbolID,
				0,
				i.ID,
				i.Degree,
				"correction",
				"z",
				i.WaveX2.T,
				i.WaveX2.P,
				i.WaveZ.T,
				i.WaveZ.P,
			)

			if err != nil {
				return err
			}
		}
	}

	_, err = db.Exec("SELECT f_corrections()")
	if err != nil {
		return err
	}

	return nil
}
