//
//  main.swift
//  sceneitcameraextension
//
//  Created by Danny Francken on 8/1/25.
//  Copyright © 2025 dannyfrancken. All rights reserved.
//

import Foundation
import CoreMediaIO

let providerSource = sceneitcameraextensionProviderSource(clientQueue: nil)
CMIOExtensionProvider.startService(provider: providerSource.provider)

CFRunLoopRun()
