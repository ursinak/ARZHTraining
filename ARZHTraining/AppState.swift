//
//  AppState.swift
//  ARZH
//
//  Created by esrimobile on 27.03.19.
//  Copyright © 2019 esrimobile. All rights reserved.
//

import UIKit

enum DeviceViewState: Int {
    
    case unknown = 0
    case vertical = 1
    case horizontal = 2
}

class AppState: NSObject {
    var currentPitch: DeviceViewState = .unknown
    var orientationLandscape: Bool = false
    
}
