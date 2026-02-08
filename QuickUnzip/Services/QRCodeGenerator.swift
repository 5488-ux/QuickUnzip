import UIKit
import CoreImage

// MARK: - QR Code Generator Service

class QRCodeGenerator {

    // MARK: - Generate QR Code from Archive Info

    static func generateArchiveInfoQR(archiveURL: URL, password: String? = nil) -> UIImage? {
        let fm = FileManager.default
        guard let attributes = try? fm.attributesOfItem(atPath: archiveURL.path),
              let fileSize = attributes[.size] as? Int64 else {
            return nil
        }

        let fileName = archiveURL.lastPathComponent
        let format = ArchiveFormat.detect(from: archiveURL)?.displayName ?? "未知"
        let sizeStr = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)

        var info = """
        📦 压缩包信息
        ━━━━━━━━━━━━━━
        📝 文件名: \(fileName)
        📊 格式: \(format)
        💾 大小: \(sizeStr)
        """

        if let pwd = password, !pwd.isEmpty {
            info += "\n🔐 密码: \(pwd)"
        }

        info += "\n━━━━━━━━━━━━━━\n⚡ QuickUnzip 生成"

        return generateQRCode(from: info)
    }

    // MARK: - Generate QR Code from File List

    static func generateFileListQR(files: [String]) -> UIImage? {
        var info = "📋 文件列表 (\(files.count) 个)\n━━━━━━━━━━━━━━\n"

        for (index, file) in files.prefix(10).enumerated() {
            info += "\(index + 1). \(file)\n"
        }

        if files.count > 10 {
            info += "... 还有 \(files.count - 10) 个文件\n"
        }

        info += "━━━━━━━━━━━━━━\n⚡ QuickUnzip"

        return generateQRCode(from: info)
    }

    // MARK: - Generate QR Code from Compression Report

    static func generateReportQR(report: CompressionReport) -> UIImage? {
        let info = """
        📊 压缩报告
        ━━━━━━━━━━━━━━
        📦 \(report.archiveName)
        📁 文件数: \(report.totalFiles)
        💾 原始: \(report.formattedTotalUncompressed)
        📦 压缩: \(report.formattedTotalCompressed)
        💹 压缩率: \(String(format: "%.1f", report.overallSavedPercentage))%
        💰 节省: \(report.formattedSpaceSaved)
        ━━━━━━━━━━━━━━
        ⚡ QuickUnzip 分析
        """

        return generateQRCode(from: info)
    }

    // MARK: - Generate QR Code from Text

    static func generateQRCode(from text: String, size: CGSize = CGSize(width: 512, height: 512)) -> UIImage? {
        guard let data = text.data(using: .utf8) else { return nil }

        let filter = CIFilter(name: "CIQRCodeGenerator")
        filter?.setValue(data, forKey: "inputMessage")
        filter?.setValue("M", forKey: "inputCorrectionLevel") // Medium error correction

        guard let outputImage = filter?.outputImage else { return nil }

        // Scale the QR code
        let scaleX = size.width / outputImage.extent.width
        let scaleY = size.height / outputImage.extent.height
        let scale = min(scaleX, scaleY)

        let transform = CGAffineTransform(scaleX: scale, y: scale)
        let scaledImage = outputImage.transformed(by: transform)

        // Convert to UIImage with better quality
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    // MARK: - Generate QR Code with Logo

    static func generateQRCodeWithLogo(from text: String, logo: UIImage? = nil, size: CGSize = CGSize(width: 512, height: 512)) -> UIImage? {
        guard let qrImage = generateQRCode(from: text, size: size) else { return nil }

        guard let logo = logo else { return qrImage }

        // Draw QR code with logo overlay
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            qrImage.draw(in: CGRect(origin: .zero, size: size))

            // Draw white background for logo
            let logoSize = CGSize(width: size.width * 0.25, height: size.height * 0.25)
            let logoOrigin = CGPoint(
                x: (size.width - logoSize.width) / 2,
                y: (size.height - logoSize.height) / 2
            )
            let logoRect = CGRect(origin: logoOrigin, size: logoSize)

            // White circle background
            let padding: CGFloat = 8
            let bgRect = logoRect.insetBy(dx: -padding, dy: -padding)
            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fillEllipse(in: bgRect)

            // Draw logo
            logo.draw(in: logoRect)
        }
    }

    // MARK: - Create Shareable Image with Info

    static func createShareableImage(archiveURL: URL, password: String? = nil) -> UIImage? {
        guard let qrImage = generateArchiveInfoQR(archiveURL: archiveURL, password: password) else {
            return nil
        }

        let canvasSize = CGSize(width: 800, height: 1000)
        let renderer = UIGraphicsImageRenderer(size: canvasSize)

        return renderer.image { context in
            // Background gradient
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    UIColor(red: 0.4, green: 0.49, blue: 0.92, alpha: 1.0).cgColor,
                    UIColor(red: 0.46, green: 0.29, blue: 0.64, alpha: 1.0).cgColor
                ] as CFArray,
                locations: [0, 1]
            )!

            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: canvasSize.height),
                options: []
            )

            // Title
            let titleText = "QuickUnzip 分享"
            let titleFont = UIFont.systemFont(ofSize: 40, weight: .bold)
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.white
            ]
            let titleSize = titleText.size(withAttributes: titleAttributes)
            let titleRect = CGRect(
                x: (canvasSize.width - titleSize.width) / 2,
                y: 60,
                width: titleSize.width,
                height: titleSize.height
            )
            titleText.draw(in: titleRect, withAttributes: titleAttributes)

            // QR Code background
            let qrSize: CGFloat = 500
            let qrPadding: CGFloat = 40
            let qrBgRect = CGRect(
                x: (canvasSize.width - qrSize - qrPadding * 2) / 2,
                y: 150,
                width: qrSize + qrPadding * 2,
                height: qrSize + qrPadding * 2
            )

            context.cgContext.setFillColor(UIColor.white.cgColor)
            context.cgContext.fillPath()
            let roundedPath = UIBezierPath(roundedRect: qrBgRect, cornerRadius: 24)
            context.cgContext.addPath(roundedPath.cgPath)
            context.cgContext.fillPath()

            // QR Code
            let qrRect = CGRect(
                x: (canvasSize.width - qrSize) / 2,
                y: 150 + qrPadding,
                width: qrSize,
                height: qrSize
            )
            qrImage.draw(in: qrRect)

            // Footer
            let footerText = "扫描查看压缩包信息"
            let footerFont = UIFont.systemFont(ofSize: 24, weight: .medium)
            let footerAttributes: [NSAttributedString.Key: Any] = [
                .font: footerFont,
                .foregroundColor: UIColor.white.withAlphaComponent(0.9)
            ]
            let footerSize = footerText.size(withAttributes: footerAttributes)
            let footerRect = CGRect(
                x: (canvasSize.width - footerSize.width) / 2,
                y: canvasSize.height - 120,
                width: footerSize.width,
                height: footerSize.height
            )
            footerText.draw(in: footerRect, withAttributes: footerAttributes)
        }
    }
}
