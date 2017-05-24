//
//  PressureButton.swift
//  Double Sampler
//
//  Created by Gene De Lisa on 5/5/17.
//  Copyright © 2017 Gene De Lisa. All rights reserved.
//

import Foundation
import UIKit

public class PressureButton : UIButton {
    
    var midiPerformer:Performer!
    
    let generator = UIImpactFeedbackGenerator(style: .light)
    
    var volumeChangeEnabled = false
    
    //    open override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    //        super.touchesBegan(touches, with: event)
    //
    //        for touch in touches{
    //            // it seems these are 0 always
    //            let pressure = touch.force / touch.maximumPossibleForce
    //            log.debug("% Touch pressure: \(pressure) force \(touch.force) max \(touch.maximumPossibleForce)")
    //            if pressure > 0 {
    //                generator.impactOccurred()
    //            }
    //        }
    //    }
    open override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        
        for touch in touches{
            let pressure = touch.force / touch.maximumPossibleForce
            log.debug("% Touch pressure: \(pressure) force \(touch.force) max \(touch.maximumPossibleForce)")
            
            if volumeChangeEnabled {
                midiPerformer.changeVolume(Float32(pressure))
            }
            
            if pressure == 1 {
                generator.impactOccurred()
            }
        }
        
    }
}
