import XCTest
@testable import TextureMap

final class TextureMapTests: XCTestCase {

    func testEmptyTexture() async throws {
        
        let size = CGSize(width: 200, height: 100)
        
        let emptyTexture: MTLTexture = try await TextureMap.emptyTexture(size: size, bits: ._8)
        
        XCTAssertEqual(emptyTexture.width, Int(size.width))
        XCTAssertEqual(emptyTexture.height, Int(size.height))
    }
}
