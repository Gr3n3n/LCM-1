//
//  AudioUtils.swift
//  Double Sampler
//
//  Created by Gene De Lisa on 4/25/17.
//  Copyright © 2017 Gene De Lisa. All rights reserved.
//

import Foundation

class AudioUtils {
    
    static func checkError(_ status:OSStatus) {
        if status != noErr {
            print("Error \(status)")
        }
    }
    

}
