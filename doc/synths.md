# Supported Synths

In addition to the simple synth (implemented by `synthController`), there are
other custom implementations that support popular hardware synths:

### Korg Volca Keys

Example:
```haskell
import Sound.Tidal.MIDI.Context
import Sound.Tidal.VolcaKeys

keyStreams <- midiproxy 1 "VolcaKeys" [(keys, 1)]

[k1] <- sequence keyStreams
```

### Korg Volca Bass

Example:
```haskell
import Sound.Tidal.MIDI.Output
import Sound.Tidal.VolcaBass

bassStreams <- midiproxy 1 "VolcaBass" [(bass, 1)]

[k1] <- sequence bassStreams
```


### Korg Volca Beats

Example:
```haskell
import Sound.Tidal.MIDI.Output
import Sound.Tidal.VolcaBeats

beatStreams <- midiproxy 1 "VolcaBeats" [(beats, 1)]

[k1] <- sequence beatStreams
```

### Waldorf Blofeld

Example:

```haskell
import Sound.Tidal.MIDI.Output
import Sound.Tidal.Blofeld

keyStreams <- midiproxy 1 "Waldorf Blofeld" [(keys, 1)]

[k1] <- sequence keyStreams
```

### DSI Tetra

#### Example

assumes the following Tetra Global parameters:

* `Multi mode`: __On__
* `M Param Rec`: __NRPN__
* `MIDI Channel`: __1__

```haskell
import Sound.Tidal.MIDI.Output
import Sound.Tidal.Tetra

keyStreams <- midiproxy 1 "DSI Tetra" [(keys 1),(keys, 2),(keys, 3),(keys, 4)]

[k1,k2,k3,k4] <- sequence keyStreams
```
