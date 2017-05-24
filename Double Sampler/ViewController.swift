//
//  ViewController.swift
//  Double Sampler
//
//  Created by Gene De Lisa on 4/16/17.
//  Copyright © 2017 Gene De Lisa. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    
    @IBOutlet var leftSlider: UISlider!
    
    @IBOutlet var rightSlider: UISlider!
    
    let midiPerformer = Performer()
    
    var leftVelocity:UInt32 = 127
    
    var rightVelocity:UInt32 = 127
    
    var buttonMap = [
        0 : 48,
        1 : 50,
        2 : 52,
        3 : 53,
        4 : 55,
        5 : 57,
        6 : 59, // b
        
        7 : 72,
        8 : 74,
        9 : 76,
        10 : 77,
        11 : 79,
        12 : 81,
        13 : 83,
        ]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Performer.setSessionPlayback()
        
        // stringEnsemble1 = 48
        // stringEnsemble2 = 49
        // synthStrings1   = 50
        // synthStrings2   = 51
        
        let patch1:UInt32 = 48
        let patch2:UInt32 = 48
        var channel:UInt32 = 0
        
        
        midiPerformer.setInstrument(channel, program: patch1)
        channel = 1
        midiPerformer.setInstrument(channel, program: patch2)
        
        
        // set the performer on each pressure button
        for c in view.subviews {
            if c is UIStackView {
                for b in c.subviews {
                    if let pb = b as? PressureButton {
                        pb.midiPerformer = self.midiPerformer
                    }
                }
            }
        }
        
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    
    //MARK: - Actions
    
    @IBAction func rightSliderAction(_ sender: UISlider) {
        log.debug("\(#function)")
        log.debug("value: \(sender.value)")
        rightVelocity = UInt32(sender.value)
    }
    
    @IBAction func leftSliderAction(_ sender: UISlider) {
        log.debug("\(#function)")
        log.debug("value: \(sender.value)")
        leftVelocity = UInt32(sender.value)
    }
    
    @IBAction func buttonTouchDown(_ sender: UIButton) {
        let pitchNumber = UInt32(buttonMap[sender.tag]!)
        var velocity:UInt32 = leftVelocity
        log.debug("pitchNumber \(pitchNumber)")
        var channel:UInt32 = 0
        if sender.tag > 5 {
            channel = 1
            velocity = rightVelocity
        }
        midiPerformer.sendNoteOn(channel, noteNum: pitchNumber, velocity: velocity)
    }
    
    @IBAction func buttonAction(_ sender: UIButton) {
        log.debug("\(#function)")
        
        let pitchNumber = UInt32(buttonMap[sender.tag]!)
        log.debug("pitchNumber \(pitchNumber)")
        var channel:UInt32 = 0
        if sender.tag > 5 {
            channel = 1
        }
        midiPerformer.sendNoteOff(channel, noteNum: pitchNumber)
        
        //        switch sender.tag {
        //        case 0:
        //            log.debug("tag \(sender.tag)")
        //
        //
        //        case 1:
        //            log.debug("tag \(sender.tag)")
        //        case 2:
        //            log.debug("tag \(sender.tag)")
        //        case 3:
        //            log.debug("tag \(sender.tag)")
        //        case 4:
        //            log.debug("tag \(sender.tag)")
        //        case 5:
        //            log.debug("tag \(sender.tag)")
        //        case 6:
        //            log.debug("tag \(sender.tag)")
        //        case 7:
        //            log.debug("tag \(sender.tag)")
        //        case 8:
        //            log.debug("tag \(sender.tag)")
        //        case 9:
        //            log.debug("tag \(sender.tag)")
        //        case 10:
        //            log.debug("tag \(sender.tag)")
        //        case 11:
        //            log.debug("tag \(sender.tag)")
        //            
        //        default: break
        //        }
        
    }
}




