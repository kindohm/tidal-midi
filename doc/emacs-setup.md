# Setup for Emacs

Within your `tidal.el` script, locate the function `tidal-start-haskell` and add:

```emacs
(tidal-send-string "import Sound.Tidal.MIDI.Output")
```

after

```emacs
(tidal-send-string "import Sound.Tidal.Context")
```

Additionally you will have to add lines to import the synth you want to control via MIDI, e.g. `(tidal-send-string "import Sound.Tidal.SimpleSynth")` as well as the initialization commands for streams:

```emacs
(tidal-send-string "keyStreams <- midiproxy 1 \"SimpleSynth virtual input\" [(keys, 1)]")
(tidal-send-string "[t1] <- sequence keyStreams")
```
For adding the MIDI device "SimpleSynth virtual input" and control it via MIDI channel 1. With this set up you will be able to use it via e.g. `t1 $ note "50"`

Synth specific usage instructions can be found below. Note that these are simply assuming you are running tidal-midi directly via ghci command line. If you want any of the other synths within emacs, you will have to edit your `tidal.el` accordingly.
