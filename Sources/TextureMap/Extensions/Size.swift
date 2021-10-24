//
//  File.swift
//  
//
//  Created by Anton Heestand on 2021-10-24.
//

import MetalKit
import CoreGraphics

extension MTLTexture {
    
    public var size: CGSize {
        CGSize(width: width, height: height)
    }
    
}


extension CGImage {

    public var size: CGSize {
        CGSize(width: width, height: height)
    }
    
}
