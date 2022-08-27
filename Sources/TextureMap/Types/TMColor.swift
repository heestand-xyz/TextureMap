//
//  Created by Anton Heestand on 2022-08-26.
//

#if os(macOS)
import AppKit
#else
import UIKit
#endif

#if os(macOS)
public typealias TMColor = NSColor
#else
public typealias TMColor = UIColor
#endif
