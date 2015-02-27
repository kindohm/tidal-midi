
module Sound.Tidal.Tetra where

import qualified Sound.PortMidi as PM
import GHC.Word
import GHC.Int

import Sound.OSC.FD
import qualified Data.Map as Map
import Control.Applicative

import Control.Concurrent.MVar
--import Visual
import Data.Hashable
import Data.Bits
import Data.Maybe
import System.Process
import Control.Concurrent
import Foreign.C
import Sound.Tidal.Stream
import Sound.Tidal.Pattern
import Sound.Tidal.Parse

import System.Environment
import System.IO.Error
import System.IO.Unsafe
import Control.Exception

keys :: OscShape
keys = OscShape {path = "/note",
                 params = [ I "note" Nothing,
                            F "dur" (Just (0.05)),
                            F "kcutoff" (Just (164)),
                            F "kresonance" (Just (-1)),
                            F "atk" (Just (-1)),
                            F "dcy" (Just (-1)),
                            F "sus" (Just (-1)),
                            F "rel" (Just (-1)),
                            F "fgain" (Just (-1)),
                            F "fvol" (Just (-1)),
                            F "audiomod" (Just (-1)),
                            F "kamt" (Just (-1)),
                            F "oscmix" (Just (-1)),
                            F "sub1vol" (Just (-1)),
                            F "sub2vol" (Just (-1)),
                            F "noise" (Just (-1)),
                            F "fpoles" (Just (-1)),
                            F "kmode" (Just (-1)),
                            F "ksplitpoint" (Just (-1))
                          ],
                 timestamp = NoStamp,
                 latency = 0,
                 namedParams = False,
                 preamble = []
                }

keyStream = stream "127.0.0.1" 7303 keys

note         = makeI keys "note"

dur = makeF keys "dur"

kcutoff      =  makeF keys "kcutoff"
kresonance      =  makeF keys "kresonance"
atk       = makeF keys "atk"
dcy        = makeF keys "dcy"
sus      = makeF keys "sus"
rel      = makeF keys "rel"
fgain        = makeF keys "fgain"
fvol        = makeF keys "fvol"

audiomod    = makeF keys "audiomod"
kamt      = makeF keys "kamt"

oscmix    = makeF keys "oscmix"
sub1vol   = makeF keys "sub1vol"
sub2vol   = makeF keys "sub2vol"
noise     = makeF keys "noise"


fpoles    = makeF keys "fpoles"
twopole = fpoles (p "0")
fourpole = fpoles (p "1")

kmode     = makeF keys "kmode"
knormal   = kmode (p "0")
kstack   = kmode (p "1")
ksplit   = kmode (p "2")

ksplitpoint   = makeF keys "ksplitpoint"

-- dur          = makeF keys "dur"
-- portamento   = makeF keys "portamento"
-- expression   = makeF keys "expression"
-- octave       = makeF keys "octave"
-- voice        = makeF keys "voice"
-- detune       = makeF keys "detune"
-- vcoegint     = makeF keys "vcoegint"
-- kcutoff      = makeF keys "kcutoff"
-- vcfegint     = makeF keys "vcfegint"
-- lforate      = makeF keys "lforate"
-- lfopitchint  = makeF keys "lfopitchint"
-- lfocutoffint = makeF keys "lfocutoffint"

-- dtime        = makeF keys "dtime"
-- dfeedback    = makeF keys "dfeedback"

paramRanges = [
              164, -- Cutoff, in semitones
              127, -- resonance
              127, -- attack
              127, -- decay
              127, -- sustain
              127, -- release
              127, -- fgain
              127, -- fvol
              127, -- audiomod
              127, -- kamt
              127, -- oscmix
              127, -- sub1vol
              127, -- sub2vol
              127, -- noise
              1, -- fpoles
              2, -- kmode
              127 -- ksplitpoint
              ]

keynames = map name (tail $ tail $ params keys)

test :: IO (Maybe a) -> IO a
test = (>>= maybe (ioError $ userError "oops") return)

readCtrl :: PM.PMStream -> IO (Maybe (CLong, CLong))
readCtrl dev = do
  ee <- PM.readEvents dev
  case ee of
    Right PM.NoError -> return Nothing
    Left evts ->
      do
        case evts of
          [] -> return Nothing
          (x:xs) -> do
            let m = PM.message x
            return (Just (PM.data1 m, PM.data2 m))

handleKey :: MVar (CLong) -> Maybe (CLong, CLong) -> IO ()
handleKey knob1 v = do
  case v of
    Nothing -> return ()
    Just (cc, val) -> do
      case cc of
        28 -> do
          forkIO $ f knob1 val

          return ()
            where f knob1 val = do
                                  swapMVar knob1 val
                                  return ()

        x -> putStrLn ("Received a MIDI CC Val of: " ++ show v)

readKnobM :: MVar (CLong) -> IO (Maybe CLong)
readKnobM m = tryReadMVar m

readKnob :: MVar (CLong) -> Maybe CLong
readKnob m = unsafePerformIO $ readKnobM m

normMIDIRange :: (Integral a, Floating b) => a -> b
normMIDIRange a = (fromIntegral a) / 127

knobPattern :: MVar (CLong) -> Pattern Double
knobPattern m = maybeListToPat [normMIDIRange <$> readKnob m]

kr = knobPattern


inputproxy :: Int -> PM.DeviceID -> IO (MVar (CLong))
inputproxy latency deviceID = do
  PM.initialize
  do
    result <- PM.openInput deviceID
    knob1 <- newMVar (0 :: CLong)
    case result of
      Right err ->
        do
          putStrLn ("Failed opening Midi Input Port: " ++ show deviceID ++ " - " ++ show err)
          return knob1
      Left conn ->
        do
          forkIO $ loop conn knob1
          return knob1
            where loop conn knob1 = do v <- readCtrl conn
                                       handleKey knob1 v
                                       threadDelay latency
                                       loop conn knob1


keyproxy latency deviceID = do
  PM.initialize
  do
    result <- PM.openOutput deviceID 0
    case result of
      Right err -> putStrLn ("Failed opening Midi Output Port: " ++ show err)
      Left conn ->
        do
          x <- udpServer "127.0.0.1" 7303
          forkIO $ loop conn x
          return ()
            where loop conn x = do m <- recvMessage x
                                   act conn m
                                   loop conn x
                  act conn (Just (Message "/note" (note:dur:ctrls))) =
                      do
                        let note' = (fromJust $ d_get note) :: Int
                            dur' = (fromJust $ d_get dur) :: Float
                            ctrls' = (map (fromJust . d_get) ctrls) :: [Float]
                        -- putStrLn ("Message received")
                        sendmidi latency conn (fromIntegral note', dur') ctrls'
                        return()

sendmidi latency stream (note,dur) ctrls =
  do forkIO $ do threadDelay latency
                 noteOn stream note 60
                 --  putStrLn ("Send On Msg: " ++ show result)
                 threadDelay (floor $ 1000000 * dur)
                 noteOff stream note
                 --  putStrLn ("Send Off Msg: " ++ show result)
                 return ()
     let ctrls' = map floor (zipWith (*) paramRanges ctrls)
         ctrls'' = filter ((>=0) . snd) (zip keynames ctrls')
         --ctrls''' = map (\x -> (x, fromJust $ lookup x ctrls'')) usectrls
     --putStrLn $ show ctrls''
     sequence_ $ map (\(name, ctrl) -> makeCtrl stream (ctrlN name ctrl)) ctrls''
     return ()


ctrlN "kcutoff" v         = (15, v)
ctrlN "kresonance" v         = (16, v)

-- filter envelope
ctrlN "atk" v         = (23, v)
ctrlN "dcy" v         = (24, v)
ctrlN "sus" v         = (25, v)
ctrlN "rel" v         = (26, v)

ctrlN "fgain" v         = (110, v)
ctrlN "fvol" v         = (116, v)

ctrlN "audiomod" v         = (18, v)
ctrlN "kamt" v         = (17, v)

ctrlN "oscmix" v         = (13, v)
ctrlN "sub1vol" v         = (114, v)
ctrlN "sub2vol" v         = (115, v)
ctrlN "noise" v         = (14, v)

ctrlN "fpoles" v         = (19, v)

ctrlN "kmode" v         = (119, v)

ctrlN "ksplitpoint" v         = (118, v)

ctrlN s _             = error $ "no match for " ++ s




noteOn :: PM.PMStream -> CLong -> CLong -> IO PM.PMError
noteOn conn val vel = PM.writeShort conn evt
    where msg = PM.PMMsg 0x90 val vel
          evt = PM.PMEvent msg 0

noteOff :: PM.PMStream -> CLong -> IO PM.PMError
noteOff conn val = PM.writeShort conn evt
    where msg = PM.PMMsg 0x80 val 60
          evt = PM.PMEvent msg 0



makeCtrl :: PM.PMStream -> (CLong, CLong) -> IO PM.PMError
makeCtrl conn (c, n) = do
  PM.writeShort conn evtMSBCC
  PM.writeShort conn evtLSBCC
  PM.writeShort conn evtMSBVal
  PM.writeShort conn evtLSBVal
    where msgMSBCC = PM.PMMsg 0xB0 0x63 (shift (c .&. 0x3F80) (-7))
          evtMSBCC = PM.PMEvent msgMSBCC 0
          msgLSBCC = PM.PMMsg 0xB0 0x62 (c .&. 0x7F)
          evtLSBCC = PM.PMEvent msgLSBCC 0
          msgMSBVal = PM.PMMsg 0xB0 0x06 (shift (n .&. 0x3F80) (-7))
          evtMSBVal = PM.PMEvent msgMSBVal 0
          msgLSBVal = PM.PMMsg 0xB0 0x26 (n .&. 0x7F)
          evtLSBVal = PM.PMEvent msgLSBVal 0
