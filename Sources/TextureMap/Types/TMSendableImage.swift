//
//  TMSendableImage.swift
//  TextureMap
//
//  Created by Anton on 2024-12-24.
//

public struct TMSendableImage: @unchecked Sendable {
    
    private let image: TMImage
    
    fileprivate init(image: TMImage) {
        self.image = image
    }
}

extension TMSendableImage {
    public func receive() -> TMImage {
        image
    }
}

extension TMImage {
    public func send() -> TMSendableImage {
        TMSendableImage(image: self)
    }
}
