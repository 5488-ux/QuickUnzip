import Foundation
import UIKit
import CoreGraphics

class SteganographyService {
    static let shared = SteganographyService()

    private let magicHeader: [UInt8] = [0x53, 0x54, 0x45, 0x47] // "STEG"

    enum SteganographyError: LocalizedError {
        case imageTooSmall
        case noMessageFound
        case encodingFailed
        case invalidImage

        var errorDescription: String? {
            switch self {
            case .imageTooSmall: return "图片太小，无法隐藏此消息"
            case .noMessageFound: return "未在图片中发现隐藏消息"
            case .encodingFailed: return "编码失败"
            case .invalidImage: return "无效的图片格式"
            }
        }
    }

    // MARK: - Encode Message into Image

    func hideMessage(_ message: String, in image: UIImage) throws -> UIImage {
        guard let cgImage = image.cgImage else { throw SteganographyError.invalidImage }

        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = width * height

        guard let messageData = message.data(using: .utf8) else {
            throw SteganographyError.encodingFailed
        }

        // Build payload: magic + length(4 bytes) + data
        var payload = magicHeader
        let length = UInt32(messageData.count)
        payload.append(UInt8((length >> 24) & 0xFF))
        payload.append(UInt8((length >> 16) & 0xFF))
        payload.append(UInt8((length >> 8) & 0xFF))
        payload.append(UInt8(length & 0xFF))
        payload.append(contentsOf: messageData)

        let totalBits = payload.count * 8
        // Each pixel has 4 channels (RGBA), we use 2 LSBs of RGB = 6 bits per pixel
        let bitsPerPixel = 3 // 1 bit per R, G, B channel
        let pixelsNeeded = (totalBits + bitsPerPixel - 1) / bitsPerPixel

        guard pixelsNeeded <= totalPixels else {
            throw SteganographyError.imageTooSmall
        }

        let bitsPerComponent = 8
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw SteganographyError.encodingFailed
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let pixelData = context.data else {
            throw SteganographyError.encodingFailed
        }

        let pixels = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)

        var bitIndex = 0
        for byte in payload {
            for bit in (0..<8).reversed() {
                let bitValue = (byte >> bit) & 1
                let pixelIndex = bitIndex / 3
                let channelOffset = bitIndex % 3 // 0=R, 1=G, 2=B

                let baseOffset = pixelIndex * 4 + channelOffset
                pixels[baseOffset] = (pixels[baseOffset] & 0xFE) | bitValue

                bitIndex += 1
            }
        }

        guard let outputImage = context.makeImage() else {
            throw SteganographyError.encodingFailed
        }

        return UIImage(cgImage: outputImage, scale: image.scale, orientation: image.imageOrientation)
    }

    // MARK: - Decode Message from Image

    func extractMessage(from image: UIImage) throws -> String {
        guard let cgImage = image.cgImage else { throw SteganographyError.invalidImage }

        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            throw SteganographyError.invalidImage
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let pixelData = context.data else {
            throw SteganographyError.invalidImage
        }

        let pixels = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)

        // Read bits from image
        func readByte(at byteOffset: Int) -> UInt8 {
            var result: UInt8 = 0
            for bit in 0..<8 {
                let bitIndex = byteOffset * 8 + bit
                let pixelIndex = bitIndex / 3
                let channelOffset = bitIndex % 3
                let baseOffset = pixelIndex * 4 + channelOffset
                let bitValue = pixels[baseOffset] & 1
                result = (result << 1) | bitValue
            }
            return result
        }

        // Verify magic header
        for i in 0..<magicHeader.count {
            guard readByte(at: i) == magicHeader[i] else {
                throw SteganographyError.noMessageFound
            }
        }

        // Read length
        let lengthBytes = (0..<4).map { readByte(at: magicHeader.count + $0) }
        let length = Int(lengthBytes[0]) << 24 | Int(lengthBytes[1]) << 16 | Int(lengthBytes[2]) << 8 | Int(lengthBytes[3])

        guard length > 0 && length < width * height else {
            throw SteganographyError.noMessageFound
        }

        // Read message
        let headerSize = magicHeader.count + 4
        let messageBytes = (0..<length).map { readByte(at: headerSize + $0) }
        let messageData = Data(messageBytes)

        guard let message = String(data: messageData, encoding: .utf8) else {
            throw SteganographyError.noMessageFound
        }

        return message
    }

    // MARK: - Capacity

    func maxMessageLength(for image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        let totalPixels = cgImage.width * cgImage.height
        let totalBits = totalPixels * 3  // 3 bits per pixel (R, G, B)
        let totalBytes = totalBits / 8
        let headerSize = magicHeader.count + 4 // magic + length
        return max(0, totalBytes - headerSize)
    }
}
