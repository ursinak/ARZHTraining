//
//  Dynamic.swift
//  AR Viewer
//
//  Created by Aldis Grauze on 18.02.20.
//  Copyright © 2020 esrimobile. All rights reserved.
//

import Foundation

class Dynamic<T> {
    
    typealias Listener = (T) -> Void
    var listener: Listener?

    func bind(listener: Listener?) {
        self.listener = listener
    }

    func bindAndFire(listener: Listener?) {
        self.listener = listener
        listener?(value)
    }

    var value: T {
        didSet {
            listener?(value)
        }
    }

    init(_ v: T) {
        value = v
    }
}
