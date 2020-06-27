# LSDJ-Tune

A script written by a user named abrasive on an old chiptune website in 2009. It finds and overwrites both the frequency table and the note name table in an LSDJ
ROM to enable LSDJ to run in old, new, and exotic tunings and non-standard scales.

With the help of the LSDJ developer, I have fixed the script so that it works on current versions of LSDJ. I am not the person who wrote the script, but I have
taken the liberty to license the script under the MIT License to preserve the copyright and encourage further modification to it. At this point, this is a maintenance version to preserve it and keep it working for current and future versions of LSDJ.

## How to use:

LSDJ-Tune is a Perl script. Run it using 'perl LSDJTune.perl ...' with Perl installed and your path set. Running 'perl LSDJTune.perl' will show you how to use it, but I'll try to explain it here:

### Possible options:

`--freq-table <filename>` takes a pre-generated list of 108 frequencies and maps it onto the LSDJ frequency bank. ("Pre-generated tuning")

`-b (--base) <note> <frequency>` defines the note by which the rest of the frequency table is generated. ("Generated tuning") Required for the following 4 arguments:

- `-e (--et) N` generates an N-tone equal tempered scale. `-e 12` would be your standard 12TET scale, while `-e 6` would divide the octave into 6 equal steps.

- `--cstep N` generates steps of N cents.

- `--cents X,Y,Z` uses Scala-type formatting to define each step in a scale in cents. Must start with 0 and ends with 1200 for an octave.

- `--ratio X,Y,Z` uses Scala-type formatting to define each step in a scale as a ratio. Must start with 1 and ends with 2 for an octave.
  
`--name-file <filename>` uses a pre-generated list of 108 names to overwrite the note name bank in LSDJ.

`--names AAA,BBB` generates new note names irrespective of frequency. See examples.

`-r (--rom) <romfile>` the input LSDJ ROM file.

`-o (--out) <outfile>` the output file.

`-q (--quiet)` By default, the script prints a tuning table before writing it to the ROM. This will tell the script not to print it.
  
 
### Examples:

`perl LSDJTune.perl -b A5 440 --cents 0,100,200,300,400,500,600,700,800,900,1000,1100,1200 --names C,C#,D,D#,E,F,F#,G,G#,A,A#,B -r lsdj.gb -o lsdj_12TET.gb` generates an LSDJ rom in 12TET using the standard (LSDJ) note names. Should be identical to the source ROM.

`perl LSDJTune.perl -b A5 440 --cents 0,240,480,720,960,1200 --names U,V,X,Y,Z -r lsdj.gb -o lsdj_5edo.gb` is an example from another site. Starting at 440 hz, the script will generate this pentatonic scale upward and downward, and overwrite the name bank so that the names match the newly generated frequencies.

An example of what "not" to do:

`perl LSDJTune.perl -b A5 440 --cents 0,100,200,300,400,500,600,700,800,900,1000,1100,1200 --names U,V,X,Y,Z -r lsdj.gb -o lsdj_wrong.gb` explicitly demonstrates that the frequency table and the note name table are independent from each other. Will generate a standard 12TET scale in the frequency table, but a pentatonic scale in the note names table. U4 will not be an octave under U5, for example, as it would be under the example above. You're free to do something like this, of course, but just be aware that your note names will have inconsistent frequencies and octaves as defined in the frequencies will not equal octaves as defined in the note names.


## Known Issues

- It seems that generating scales lesser than 12 steps causes the LSDJ ROM to fail initial checkups. Running the second example above breaks some soft-coded limitation LSDJ puts on the P1 and P2 channels, allowing them to "play" pitches lower than the GB is able to play. The pitch information in LSDJ here is useless until it becomes high enough for the GB to handle. More testing is needed to fully understand what is happening.

- There is a `--fstep` method which is not yet implemented. I assume that along with steps of cents, the script was also supposed to be able to generate steps of frequencies, too.


## Known Limitations (Copied from the LSDJ Wiki page)

- `-b` only takes one of the standard note names, and can't take any newly generated ones.

- `--cents` and `--ratio` start on the base note. 
