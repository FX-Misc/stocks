package motivewave

//Markup MW
type Markup struct {
	Symbol          string
	Impulses        []Impulse     `xml:"graph>impulse"`
	ImpulsesLeading []Impulse     `xml:"graph>leading_diagonal"`
	ImpulsesEnding  []Impulse     `xml:"graph>ending_diagonal"`
	Corrections     []Correction  `xml:"graph>correction"`
	Triangles       []Triangle    `xml:"graph>triangle"`
	Combo           []Combo       `xml:"graph>combination"`
	TripleCombo     []ComboTriple `xml:"graph>triple_combo"`
}

//Point MW
type Point struct {
	T int64   `xml:"time,attr"`
	P float64 `xml:"value,attr"`
}

//Impulse MW
type Impulse struct {
	ID       int64  `xml:"id,attr"`
	ParentID int64  `xml:"parentId,attr"`
	Degree   string `xml:"degree,attr"`

	Origin Point `xml:"origin"`
	Wave1  Point `xml:"wave1"`
	Wave2  Point `xml:"wave2"`
	Wave3  Point `xml:"wave3"`
	Wave4  Point `xml:"wave4"`
	Wave5  Point `xml:"wave5"`
}

//Correction MW
type Correction struct {
	ID       int64  `xml:"id,attr"`
	ParentID int64  `xml:"parentId,attr"`
	Degree   string `xml:"degree,attr"`

	Origin Point `xml:"origin"`
	WaveA  Point `xml:"waveA"`
	WaveB  Point `xml:"waveB"`
	WaveC  Point `xml:"waveC"`
}

//ComboTriple MW
type ComboTriple struct {
	ID       int64  `xml:"id,attr"`
	ParentID int64  `xml:"parentId,attr"`
	Degree   string `xml:"degree,attr"`

	Origin Point `xml:"origin"`
	WaveW  Point `xml:"waveW"`
	WaveX  Point `xml:"waveX"`
	WaveY  Point `xml:"waveY"`
	WaveX2 Point `xml:"waveX2"`
	WaveZ  Point `xml:"waveZ"`
}

//Combo MW
type Combo struct {
	ID       int64  `xml:"id,attr"`
	ParentID int64  `xml:"parentId,attr"`
	Degree   string `xml:"degree,attr"`

	Origin Point `xml:"origin"`
	WaveW  Point `xml:"waveW"`
	WaveX  Point `xml:"waveX"`
	WaveY  Point `xml:"waveY"`
}

//Triangle MW
type Triangle struct {
	ID       int64  `xml:"id,attr"`
	ParentID int64  `xml:"parentId,attr"`
	Degree   string `xml:"degree,attr"`

	Origin Point `xml:"origin"`
	WaveA  Point `xml:"waveA"`
	WaveB  Point `xml:"waveB"`
	WaveC  Point `xml:"waveC"`
	WaveD  Point `xml:"waveD"`
	WaveE  Point `xml:"waveE"`
	WaveF  Point `xml:"waveF"`
	WaveG  Point `xml:"waveG"`
	WaveH  Point `xml:"waveH"`
	WaveI  Point `xml:"waveI"`
}
