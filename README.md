# tidal-midi
Tidal module for sending patterns over MIDI.

__PortMIDI__ variant. Should work on OS X, Linux and Windows.

This _still_ is __experimental__ software.

## Installation

Simply do

```shell
~$ cabal update
~$ cabal install tidal-midi
```

__Note:__ On OS X with GHC 7.10 it is necessary to reinstall PortMidi again with
frameworks correctly linked:

```shell
cabal install portmidi --ghc-options="-optl-Wl,-framework,CoreMIDI,-framework,CoreAudio" --reinstall --jobs=1 --force-reinstalls
```

## Usage

_This guide assumes you are already familiar with Tidal and creating patterns
with samples._

### Get the names of MIDI devices on your system

In order to use `tidal-midi` you will need the _exact_ name of a MIDI
device on your system. You can get a list of MIDI devices on your system
depending on your operating system:

- Linux: `aconnect -o`
- Mac OS X: use *Audio MIDI Setup*
- Windows: no known methods. Use an application such as FL Studio to get a list

After listing MIDI devices on your system, take note of the device name you
will use. Devices names are case-sensitive.

For the purposes of this guide, we'll assume your device name is "USB MIDI Device".

### Basic tidal-midi code

Assuming you're using the Atom editor, create a new file and save it with
a `.tidal` extension (e.g. `midi-test.tidal`). Then, type the following in
the editor:

```haskell
import Sound.Tidal.MIDI.Context

devices <- midiDevices

m1 <- midiStream devices "USB MIDI Device" 1 synthController
```

Evaluate each of those lines (use `Shift+Enter` in the Atom
editor). Now Atom is ready to run MIDI patterns using `m1`:

```haskell
m1 $ note "0"
-- plays a middle-C note
```

Above, the `note` param indicate a MIDI note, where 0 equals middle-C. The following
pattern plays a major scale:

```haskell
m1 $ note "0 2 4 5 7 9 11 12"
```

Alternatively, you can use `midinote` to explicitly use a MIDI note from 0 to 127:

```haskell
m1 $ midinote "60 62 64 65 67 69 71 72"
```

You can use normal TidalCycles pattern transform functions to change `tidal-midi`
patterns:

```haskell
m1 $ every 3 (rev) $ every 2 (density 2) $ note "0 2 4 5 7 9 11 12"
```

The `synthController` has some params that support MIDI Change Control messages,
such as the mod wheel:

```haskell
m1 $ note "0 2 4 5 7 9 11 12" # modwheel "0.1 0.4 0.9"
```

MIDI CC params can have decimal values in the range *0 to 1*, which map to MIDI
CC values *0 to 127*.

_Custom synthesizer implementations implement additional MIDI CC parameters._

### Custom MIDI Channels

Let's review this line from the boilerplate code above:

```haskell
m1 <- midiStream devices "USB MIDI Device" 1 synthController
```

The 2nd to last parameter on that line indicates the channel number. Let's say
your device is running on channel 7. You can specify channel 7 by changing the
2nd to last parameter:

```haskell
m1 <- midiStream devices "USB MIDI Device" 7 synthController
```

### The default synthController (a.k.a "simple synth")

The simple synth comes with _simple_ MIDI parameters, that any device should understand:

* modwheel
* balance
* expression
* sustainpedal

All of these parameters map the given values from __0..1__ to MIDI values ranging from __0..127__.

You can use all of these parameters like the familiar synth parameters in
TidalCycles:

```haskell
m1 $ note "0*8" # modwheel "0.25 0.75" # balance "0.1 0.9" # expression (sine1)
```

## Known issues and limitations

- SysEx support is there but really limited to work with the Waldorf Blofeld
