//
//  MIDISynth.swift
//  Double Sampler
//
//  Created by Gene De Lisa on 4/25/17.
//  Copyright © 2017 Gene De Lisa. All rights reserved.
//


import Foundation
import CoreAudio
import AudioToolbox



/// A MIDISynth AudioUnit

open class MIDISynthUnit {
    
    open static let sharedInstance = MIDISynthUnit()
    public static var soundFontName = "FluidR3 GM2-2"
    public static var soundFontExt = "SF2"
    
    public var processingGraph : AUGraph?
    var midisynthNode = AUNode()
    var ioNode        = AUNode()
    var mixerNode     = AUNode()
    var midisynthUnit   : AudioUnit?
    var ioUnit          : AudioUnit?
    var mixerUnit       : AudioUnit?
    
    
    
    public init() {
        initGraph()
    }
    
    public func initGraph() {
        log.debug("\(#function)")
        setupMIDISynth()
        CAShow(UnsafeMutableRawPointer(self.processingGraph!))
    }
    
    func setupMIDISynth() {
        log.debug("\(#function)")
        
        augraphSetup()
        
        self.loadMIDISynthSoundFont()
        
        // stringEnsemble1 = 48
        loadPatches(patches: [48,48], channels: [0,1])
        
        graphStart()
        
    }
    
    
    /// Create the `AUGraph`, the nodes and units, then wire them together.
    func augraphSetup() {
        log.debug("\(#function)")
        var status = noErr
        
        if self.processingGraph != nil {
            status = DisposeAUGraph(self.processingGraph!)
            AudioUtils.checkError(status)
        }
        
        status = NewAUGraph(&self.processingGraph)
        if status != noErr {
            log.error("error creating augraph")
            AudioUtils.checkError(status)
        } else {
            log.debug("created new augraph \(self.processingGraph!)")
        }
        
        guard self.processingGraph != nil else {
            log.error("Could not create graph")
            return
        }
        
        createIONode()
        
        createSynthNode()
        
        //-----------------------------------
        // Add a Mixer unit node to the graph
        //-----------------------------------
        
        var cd = AudioComponentDescription(
            componentType: OSType(kAudioUnitType_Mixer),
            componentSubType: OSType(kAudioUnitSubType_MultiChannelMixer),
            componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
            componentFlags: 0,
            componentFlagsMask: 0)
        status = AUGraphAddNode(self.processingGraph!, &cd, &mixerNode)
        
        //---------------
        // Open the graph
        //---------------
        log.debug("opening graph")
        // now do the wiring. The graph needs to be open before you call AUGraphNodeInfo
        status = AUGraphOpen(self.processingGraph!)
        if status != noErr {
            log.error("error opening graph")
            AudioUtils.checkError(status)
        }
        
        // needs to be open to initialize. counter-intuitive naming.
        initializeGraph()
        
        log.debug("opening io")
        status = AUGraphNodeInfo(self.processingGraph!, self.ioNode, nil, &ioUnit)
        if status != noErr {
            log.error("error opening io")
            AudioUtils.checkError(status)
        }
        
        log.debug("opening midi synth")
        status = AUGraphNodeInfo(self.processingGraph!, self.midisynthNode, nil, &self.midisynthUnit)
        if status != noErr {
            log.error("error opening midi synth")
            AudioUtils.checkError(status)
        }
        
        log.debug("opening mixer")
        
        //-----------------------------------------------------------
        // Obtain the mixer unit instance from its corresponding node
        //-----------------------------------------------------------
        
        AUGraphNodeInfo (
            self.processingGraph!,
            mixerNode,
            nil,
            &mixerUnit
        )
        
        //--------------------------------
        // Set the bus count for the mixer
        //--------------------------------
        var numBuses:UInt32 = 2
        status = AudioUnitSetProperty(
            mixerUnit!,
            UInt32(kAudioUnitProperty_ElementCount),
            UInt32(kAudioUnitScope_Input),
            0,
            &numBuses,
            UInt32(MemoryLayout<UInt32>.size))
        AudioUtils.checkError(status)
        
        
        let synthOutputElement:AudioUnitElement = 0
        let ioUnitInputElement:AudioUnitElement = 0
        
        // without the mixer
        //        status = AUGraphConnectNodeInput(self.processingGraph!,
        //                                         self.midisynthNode, synthOutputElement, // srcnode, SourceOutputNumber
        //            self.ioNode, ioUnitInputElement) // destnode, DestInputNumber
        //
        //        if status != noErr {
        //            log.error("error connecting synth to io")
        //            AudioUtils.checkError(status)
        //        }
        
        // connect the synth to the mixer
        status = AUGraphConnectNodeInput(self.processingGraph!,
                                         self.midisynthNode, synthOutputElement,
                                         mixerNode, ioUnitInputElement)
        if status != noErr {
            log.error("error connecting synth to mixer")
            AudioUtils.checkError(status)
        }
        
        // Connect the mixer unit to the output unit
        status = AUGraphConnectNodeInput(self.processingGraph!, mixerNode, 0, ioNode, 0)
        if status != noErr {
            log.error("error connecting mixer to io")
            AudioUtils.checkError(status)
        }
        
        changeVolume(0, volume: 1.0)
        setGain()
        
        

    }
    
    // volume is typaliased to Float32
    func changeVolume(_ busId:AudioUnitElement = 0, volume:AudioUnitParameterValue) {
        // volume: Global, Linear Gain, 0->1, 1.
        // (the volume value can actually be any finite number, including negative.)
        
        log.debug("\(#function)")

        var status = AudioUnitSetParameter( mixerUnit!,
                                            kMultiChannelMixerParam_Volume,
                                            kAudioUnitScope_Input,
                                            busId,
                                            volume,
                                            0 )
        if status != noErr {
            log.error("error setting mixer input volume")
            AudioUtils.checkError(status)
        }
        
        status = AudioUnitSetParameter( mixerUnit!,
                                            kMultiChannelMixerParam_Volume,
                                            kAudioUnitScope_Output,
                                            busId,
                                            volume,
                                            0 )
        if status != noErr {
            log.error("error setting mixer output volume")
            AudioUtils.checkError(status)
        }

    }
    
    /// Create the Output Node and add it to the `AUGraph`.
    /// - precondition: processingGraph has been created.
    /// - postcondition: self.ioNode is initialized.
    /// - seealso:
    /// [AudioComponentDescription]
    /// (https://developer.apple.com/reference/audiounit/1653552-audio_component_services#//apple_ref/swift/struct/AudioComponentDescription)
    
    func createIONode() {
        
        #if os(iOS)
            var cd = AudioComponentDescription(
                componentType:         OSType(kAudioUnitType_Output),
                componentSubType:      OSType(kAudioUnitSubType_RemoteIO),
                componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
                componentFlags:        0,
                componentFlagsMask:    0)
            let status = AUGraphAddNode(self.processingGraph!, &cd, &self.ioNode)
            AudioUtils.checkError(status)
            log.debug("added remoteio to graph \(self.ioNode)")
            
        #elseif os(OSX)
            
            var cd = AudioComponentDescription(
                componentType:         OSType(kAudioUnitType_Output),
                componentSubType:      OSType(kAudioUnitSubType_GenericOutput),
                componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
                componentFlags:        0,
                componentFlagsMask:    0)
            let status = AUGraphAddNode(self.processingGraph!, &cd, &self.ioNode)
            AudioUtils.checkError(status)
        #endif
    }
    
    /// Create the Synth Node and add it to the `AUGraph`.
    /// - Precondition: processingGraph has been created.
    /// - Postcondition: self.midisynthNode is initialized.
    /// - see: [AudioComponentDescription](https://developer.apple.com/reference/audiotoolbox/audiocomponentdescription)
    func createSynthNode() {
        log.debug("\(#function)")
        
        var cd = AudioComponentDescription(
            componentType:         OSType(kAudioUnitType_MusicDevice),
            componentSubType:      OSType(kAudioUnitSubType_MIDISynth),
            componentManufacturer: OSType(kAudioUnitManufacturer_Apple),
            componentFlags:        0,
            componentFlagsMask:    0)
        let status = AUGraphAddNode(self.processingGraph!, &cd, &midisynthNode)
        AudioUtils.checkError(status)
    }
    
    
    class func defaultSoundFontURL() -> URL? {
        if let bundle = Bundle(identifier: "com.apple.audio.units.Components") {
            let sfu = bundle.url(forResource: "gs_instruments", withExtension: "dls")
            return sfu
        }
        return nil
    }
    
    /// This will load the default sound font and set the synth unit's property.
    /// - postcondition: `self.midisynthUnit` will have it's sound font url set.
    func loadMIDISynthSoundFont()  {
        log.debug("\(#function)")
        
        precondition(self.midisynthUnit != nil, "midi synth unit cannot be nil")
        
        guard self.midisynthUnit != nil else {
            fatalError("midi synth unit cannot be nil")
        }
        
        if var bankURL = Bundle.main.url(forResource: MIDISynthUnit.soundFontName, withExtension: MIDISynthUnit.soundFontExt)  {
            
            let status = AudioUnitSetProperty(
                self.midisynthUnit!,
                AudioUnitPropertyID(kMusicDeviceProperty_SoundBankURL),
                AudioUnitScope(kAudioUnitScope_Global),
                0,
                &bankURL,
                UInt32(MemoryLayout<URL>.stride))
            
            
            AudioUtils.checkError(status)
        } else {
            log.error("Could not load sound font \(MIDISynthUnit.soundFontName).\(MIDISynthUnit.soundFontExt)")
            return
        }
        
        log.debug("loaded sound font \(MIDISynthUnit.soundFontName).\(MIDISynthUnit.soundFontExt)")
    }
    
    func setGain(gain:AudioUnitParameterValue = 0) {
        log.debug("\(#function)")

        let status = AudioUnitSetParameter(midisynthUnit!,
                                           AudioUnitPropertyID(kAUSamplerParam_Gain),
                                           AudioUnitScope(kAudioUnitScope_Global),
                                           0,
                                           gain,
                                           0)
        AudioUtils.checkError(status)
    }
    
    func enableMixerInput(enable:AudioUnitParameterValue = 1) {
        log.debug("\(#function)")
        
        let status = AudioUnitSetParameter(mixerUnit!,
                                           AudioUnitPropertyID(kMultiChannelMixerParam_Enable),
                                           AudioUnitScope(kAudioUnitScope_Input),
                                           0,
                                           enable,
                                           0)
        AudioUtils.checkError(status)
    }

    
    /// Pre-load the patches you will use.
    ///
    /// Turn on `kAUMIDISynthProperty_EnablePreload` so the midisynth will load the patch data from the file into memory.
    /// You load the patches first before playing a sequence or sending messages.
    /// Then you turn `kAUMIDISynthProperty_EnablePreload` off. It is now in a state where it will respond to MIDI program
    /// change messages and switch to the already cached instrument data.
    ///
    /// - precondition: the graph must be initialized
    ///
    /// [Doug's post](http://prod.lists.apple.com/archives/coreaudio-api/2016/Jan/msg00018.html)
    
    //// Global, dB, -90->12, 0

    
    func loadPatches(patches:[UInt32], channels:[UInt8]) {
        log.debug("\(#function)")
        
        precondition(isGraphInitialized(), "initialize graph first")
        
        
        if !isGraphInitialized() {
            fatalError("initialize graph first")
        }
        
        //let channel = UInt32(0)
        var enabled = UInt32(1)
        
        var status = AudioUnitSetProperty(
            self.midisynthUnit!,
            AudioUnitPropertyID(kAUMIDISynthProperty_EnablePreload),
            AudioUnitScope(kAudioUnitScope_Global),
            0,
            &enabled,
            UInt32(MemoryLayout<UInt32>.size))
        AudioUtils.checkError(status)
        
        
        for (index,p) in patches.enumerated() {
            let bankSelectCommand = UInt32(0xB0 | channels[index])
            status = MusicDeviceMIDIEvent(self.midisynthUnit!, bankSelectCommand, 0, 0, 0)
            
            let pcCommand = UInt32(0xC0 | channels[index])
            log.debug("setting patch. command: \(pcCommand) on channel \(channels[index])")
            status = MusicDeviceMIDIEvent(self.midisynthUnit!, pcCommand, p, 0, 0)
            AudioUtils.checkError(status)
        }
        
        enabled = UInt32(0)
        status = AudioUnitSetProperty(
            self.midisynthUnit!,
            AudioUnitPropertyID(kAUMIDISynthProperty_EnablePreload),
            AudioUnitScope(kAudioUnitScope_Global),
            0,
            &enabled,
            UInt32(MemoryLayout<UInt32>.size))
        AudioUtils.checkError(status)
        
        // at this point the patches are loaded. You still have to send a program change at "play time" for the synth
        // to switch to that patch
    }
    
    
    
    
    /// Check to see if the `AUGraph` is Initialized.
    ///
    /// - see: [AUGraphIsInitialized](https://developer.apple.com/reference/audiotoolbox/1502424-augraphisinitialized/)
    
    /// - returns: `true` if it's running, `false` if not
    func isGraphInitialized() -> Bool {
        log.debug("\(#function)")
        
        if processingGraph == nil {
            return false
        }
        
        var outIsInitialized = DarwinBoolean(false)
        let status = AUGraphIsInitialized(self.processingGraph!, &outIsInitialized)
        AudioUtils.checkError(status)
        return outIsInitialized.boolValue
        
    }
    
    /// Check to see if the `AUGraph` is running.
    ///
    /// - returns: `true` if it's running, `false` if not
    
    func isGraphRunning() -> Bool {
        log.debug("\(#function)")
        
        //precondition(self.processingGraph != nil)
        
        if  processingGraph == nil {
            return false
        }
        var isRunning = DarwinBoolean(false)
        let status = AUGraphIsRunning(self.processingGraph!, &isRunning)
        AudioUtils.checkError(status)
        return isRunning.boolValue
    }
    
    
    // Initializes the `AUGraph.
    
    /**
     An example of using the seealso field
     
     - see: [The Swift Standard Library Reference](https://developer.apple.com/library/prerelease/ios//documentation/General/Reference/SwiftStandardLibraryReference/index.html)
     */
    func initializeGraph() {
        log.debug("\(#function)")
        
        precondition(self.processingGraph != nil)
        
        let status = AUGraphInitialize(self.processingGraph!)
        if status != noErr {
            log.error("error initializing graph")
            AudioUtils.checkError(status)
        }
    }
    
    /// Starts the `AUGraph`
    fileprivate func startGraph() {
        log.debug("\(#function)")
        let status = AUGraphStart(self.processingGraph!)
        if status != noErr {
            log.error("error starting graph")
            AudioUtils.checkError(status)
        }
    }
    
    public func graphStart() {
        log.debug("\(#function)")
        
        //https://developer.apple.com/library/prerelease/ios/documentation/AudioToolbox/Reference/AUGraphServicesReference/index.html#//apple_ref/c/func/AUGraphIsInitialized
        
        guard self.processingGraph != nil else {
            fatalError("graph cannot be nil")
        }
        
        if !isGraphInitialized() {
            initializeGraph()
        }
        
        if !isGraphRunning() {
            startGraph()
        }
        
    }
    
    
    
    
    //MARK: -
    //MARK: MIDI messages
    
    //MusicDeviceMIDIEvent wants UInt32s instead of UInt8s. Go figure.
    
    func playNoteOn(_ channel:UInt32, noteNum:UInt32, velocity:UInt32) {
        precondition(self.midisynthUnit != nil)
        
        let noteCommand = UInt32(0x90 | channel)
        
        if let midisynthUnit = self.midisynthUnit {
            let status = MusicDeviceMIDIEvent(midisynthUnit, noteCommand, noteNum, velocity, 0)
            AudioUtils.checkError(status)
            var s = "noteCommand 0x\(String(noteCommand, radix: 16)) "
            s += "noteNum 0x\(String(noteNum, radix: 16)) "
            s += "velocity 0x\(String(velocity, radix: 16))"
            log.debug(s)
        }
    }
    
    
    func playNoteOff(_ channel:UInt32, noteNum:UInt32)    {
        precondition(self.midisynthUnit != nil)
        
        let noteCommand = UInt32(0x80 | channel)
        
        if let midisynthUnit = self.midisynthUnit {
            let status = MusicDeviceMIDIEvent(midisynthUnit, noteCommand, noteNum, 0, 0)
            AudioUtils.checkError(status)
            var s = "noteCommand 0x\(String(noteCommand, radix: 16)) "
            s += "noteNum 0x\(String(noteNum, radix: 16)) "
            log.debug(s)
        }
    }
    
    func controlChange(_ channel:UInt32 = 0, controller:UInt32, value:UInt32) {
        precondition(self.midisynthUnit != nil)
        
        let command = UInt32(0xB0 | channel)
        if let midisynthUnit = self.midisynthUnit {
            let status = MusicDeviceMIDIEvent(midisynthUnit, command, controller, value, 0)
            AudioUtils.checkError(status)
        }
    }
    
    
    func programChange(_ channel:UInt32 = 0, program:UInt32, bank:UInt32 = 0) {
        precondition(self.midisynthUnit != nil)
        
        let command = UInt32(0xC0 | channel)
        
        // load?
        // loadSF2Preset(preset:UInt8(program))
        if let midisynthUnit = self.midisynthUnit {
            let status = MusicDeviceMIDIEvent(midisynthUnit, command, program, bank, 0)
            AudioUtils.checkError(status)
        }
        
    }
    
}
