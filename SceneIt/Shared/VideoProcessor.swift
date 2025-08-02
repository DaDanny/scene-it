//
//  VideoProcessor.swift
//  SceneIt
//
//  Created by Claude on 8/2/25.
//  Copyright © 2025 dannyfrancken. All rights reserved.
//

import Foundation
import CoreVideo
import CoreImage
import os.log

// MARK: - Video Effect Enum

enum VideoEffect: String, CaseIterable {
    case none = "none"
    case blur = "blur"
    case monochrome = "monochrome"
    case vintage = "vintage"
    case overlay = "overlay"
}

// MARK: - Video Processor

class VideoProcessor {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.dannyfrancken.sceneit", category: "VideoProcessor")
    private let ciContext: CIContext
    
    // Core Image filters
    private var blurFilter: CIFilter?
    private var monochromeFilter: CIFilter?
    private var vintageFilter: CIFilter?
    
    // MARK: - Initialization
    
    init() {
        // Create CI context with GPU acceleration
        let options: [CIContextOption: Any] = [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
            .useSoftwareRenderer: false
        ]
        
        self.ciContext = CIContext(options: options)
        
        // Setup filters
        setupFilters()
        
        logger.info("[SceneIt] VideoProcessor initialized")
    }
    
    // MARK: - Public Processing Methods
    
    func processFrame(_ pixelBuffer: CVPixelBuffer, effect: VideoEffect, overlayEnabled: Bool) -> CVPixelBuffer {
        
        // For high performance, we'll apply effects selectively
        switch effect {
        case .none:
            return pixelBuffer
            
        case .blur:
            return applyBackgroundBlur(to: pixelBuffer)
            
        case .monochrome:
            return applyMonochrome(to: pixelBuffer)
            
        case .vintage:
            return applyVintage(to: pixelBuffer)
            
        case .overlay:
            return pixelBuffer // Just return original for now
        }
    }
    
    // MARK: - Private Processing Methods
    
    private func applyBackgroundBlur(to pixelBuffer: CVPixelBuffer) -> CVPixelBuffer {
        
        // Create CIImage from pixel buffer
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Apply Gaussian blur
        guard let blurFilter = blurFilter else { return pixelBuffer }
        blurFilter.setValue(ciImage, forKey: kCIInputImageKey)
        blurFilter.setValue(15.0, forKey: kCIInputRadiusKey)
        
        guard let outputImage = blurFilter.outputImage else { return pixelBuffer }
        
        // Render back to pixel buffer
        return renderCIImageToPixelBuffer(outputImage) ?? pixelBuffer
    }
    
    private func applyMonochrome(to pixelBuffer: CVPixelBuffer) -> CVPixelBuffer {
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        guard let monochromeFilter = monochromeFilter else { return pixelBuffer }
        monochromeFilter.setValue(ciImage, forKey: kCIInputImageKey)
        monochromeFilter.setValue(1.0, forKey: kCIInputIntensityKey)
        
        guard let outputImage = monochromeFilter.outputImage else { return pixelBuffer }
        
        return renderCIImageToPixelBuffer(outputImage) ?? pixelBuffer
    }
    
    private func applyVintage(to pixelBuffer: CVPixelBuffer) -> CVPixelBuffer {
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        
        // Apply sepia effect
        guard let vintageFilter = vintageFilter else { return pixelBuffer }
        vintageFilter.setValue(ciImage, forKey: kCIInputImageKey)
        vintageFilter.setValue(0.8, forKey: kCIInputIntensityKey)
        
        guard let outputImage = vintageFilter.outputImage else { return pixelBuffer }
        
        return renderCIImageToPixelBuffer(outputImage) ?? pixelBuffer
    }
    
    // MARK: - Filter Setup
    
    private func setupFilters() {
        // Setup reusable Core Image filters
        blurFilter = CIFilter(name: "CIGaussianBlur")
        monochromeFilter = CIFilter(name: "CIColorMonochrome")
        vintageFilter = CIFilter(name: "CISepiaTone")
        
        logger.info("[SceneIt] Filters initialized")
    }
    
    // MARK: - Buffer Management
    
    private func renderCIImageToPixelBuffer(_ image: CIImage) -> CVPixelBuffer? {
        
        let width = Int(image.extent.width)
        let height = Int(image.extent.height)
        
        var pixelBuffer: CVPixelBuffer?
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        let result = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            pixelBufferAttributes as CFDictionary,
            &pixelBuffer
        )
        
        guard result == kCVReturnSuccess, let buffer = pixelBuffer else {
            logger.error("[SceneIt] Failed to create pixel buffer")
            return nil
        }
        
        ciContext.render(image, to: buffer)
        return buffer
    }
}