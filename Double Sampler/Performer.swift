//
//  Performer.swift
//  Double Sampler
//
//  Created by Gene De Lisa on 4/25/17.
//  Copyright © 2017 Gene De Lisa. All rights reserved.
//

import Foundation
import AudioToolbox
import AVFoundation

class Performer {
    
    var midiSynth = MIDISynthUnit.sharedInstance
    
    open class func setSessionPlayback() {
        log.debug("\(#function)")
        
        #if os(iOS)
            let session:AVAudioSession = AVAudioSession.sharedInstance()
            
            do {
                try session.setCategory(AVAudioSessionCategoryPlayback,
                                        with: [.duckOthers, .defaultToSpeaker])
                let volume = session.outputVolume
                log.debug("session volume is \(volume)")
                kAudioSessionProperty_CurrentHardwareOutputVolume

                log.debug("session playback")
            } catch  {
                log.error("could not set session category")
                log.error(error.localizedDescription)
                return
            }
            
            do {
                try session.setActive(true)
                log.debug("session is active")
            } catch {
                log.error("could not make session active")
                log.error(error.localizedDescription)
            }
        #endif
    }
    
    //MARK: Messages
    
    open func setInstrument(_ channel:UInt32 = 0, program:UInt32) {
        log.debug("\(#function)")
        
        sendControlChange(channel, data1:0, data2: 0)
        sendControlChange(channel, data1:32, data2: 0)
        
        let bank = UInt32(0)
        sendProgramChange(channel, program: program, bank: bank)
    }
    
    open func sendControlChange(_ channel:UInt32 = 0, data1:UInt32, data2:UInt32)    {
        log.debug("\(#function)")
        
        var s = "channel 0x\(String(channel, radix: 16)) "
        s += "data1 0x\(String(data1, radix: 16)) "
        s += "data2 0x\(String(data2, radix: 16))"
        log.debug(s)
        
        self.midiSynth.controlChange(channel, controller: data1, value: data2)
    }
    
    func sendProgramChange(_ channel:UInt32 = 0, program:UInt32, bank:UInt32 = 0) {
        
        var s = "channel 0x\(String(channel, radix: 16)) "
        s += "program 0x\(String(program, radix: 16)) "
        s += "bank 0x\(String(bank, radix: 16))"
        log.debug(s)
        
        self.midiSynth.programChange(channel, program: program, bank:bank)
        
    }
    
    open func sendNoteOn(_ channel:UInt32 = 0, noteNum:UInt32, velocity:UInt32 = 64) {
        
        log.debug("note on \(noteNum) \(velocity)")
        var s = "noteNum 0x\(String(noteNum, radix: 16)) "
        s += "velocity 0x\(String(velocity, radix: 16))"
        log.debug(s)
        
        self.midiSynth.playNoteOn(channel, noteNum: noteNum, velocity: velocity)
    }
    
    
    open func sendNoteOff(_ channel:UInt32 = 0, noteNum:UInt32) {
        
        log.debug("note off \(noteNum)")
        let s = "noteNum 0x\(String(noteNum, radix: 16)) "
        log.debug(s)
        
        self.midiSynth.playNoteOff(channel, noteNum: noteNum)
    }
    
    open func changeVolume(_ volume:Float32) {
        self.midiSynth.changeVolume(volume: volume)
    }
    
    
}
