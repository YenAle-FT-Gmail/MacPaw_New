import XCTest
import ImageIO
import CoreLocation
@testable import BlackBox

final class MetadataTests: XCTestCase {
    
    let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("BlackBoxMetadataTests")
    
    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: testDir)
        super.tearDown()
    }
    
    // MARK: - Helper: Create JPEG with GPS metadata
    
    private func createJPEGWithGPS(name: String, lat: Double, lon: Double) -> URL? {
        let url = testDir.appendingPathComponent(name)
        
        // Create a minimal 1x1 JPEG with GPS metadata
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil) else {
            return nil
        }
        
        // Create a 1x1 pixel image
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = context.makeImage() else {
            return nil
        }
        
        // Build GPS metadata dictionary
        let gpsDict: [String: Any] = [
            kCGImagePropertyGPSLatitude as String: abs(lat),
            kCGImagePropertyGPSLatitudeRef as String: lat >= 0 ? "N" : "S",
            kCGImagePropertyGPSLongitude as String: abs(lon),
            kCGImagePropertyGPSLongitudeRef as String: lon >= 0 ? "E" : "W",
        ]
        
        let exifDict: [String: Any] = [
            kCGImagePropertyExifDateTimeOriginal as String: "2025:06:15 14:30:00",
            kCGImagePropertyExifUserComment as String: "Test photo",
        ]
        
        let properties: [String: Any] = [
            kCGImagePropertyGPSDictionary as String: gpsDict,
            kCGImagePropertyExifDictionary as String: exifDict,
        ]
        
        CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
        
        guard CGImageDestinationFinalize(destination) else { return nil }
        return url
    }
    
    private func createJPEGWithoutGPS(name: String) -> URL? {
        let url = testDir.appendingPathComponent(name)
        
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.jpeg" as CFString, 1, nil) else {
            return nil
        }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil, width: 1, height: 1,
            bitsPerComponent: 8, bytesPerRow: 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let cgImage = context.makeImage() else {
            return nil
        }
        
        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }
        return url
    }
    
    // MARK: - Helper: Read GPS from image
    
    private func readGPSFromImage(at url: URL) -> (lat: Double, lon: Double)? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any],
              let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
              let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double else {
            return nil
        }
        let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String ?? "N"
        let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String ?? "E"
        return (latRef == "S" ? -lat : lat, lonRef == "W" ? -lon : lon)
    }
    
    // MARK: - Test: GPS Extracted Correctly from Image
    
    func testGPSExtractionFromJPEG() {
        guard let url = createJPEGWithGPS(name: "gps_test.jpg", lat: 37.7749, lon: -122.4194) else {
            XCTFail("Failed to create test JPEG with GPS")
            return
        }
        
        let coords = readGPSFromImage(at: url)
        XCTAssertNotNil(coords, "Should extract GPS from JPEG with embedded coordinates")
        
        if let coords = coords {
            XCTAssertEqual(coords.lat, 37.7749, accuracy: 0.001)
            XCTAssertEqual(coords.lon, -122.4194, accuracy: 0.001)
        }
    }
    
    func testGPSExtractionSouthernHemisphere() {
        guard let url = createJPEGWithGPS(name: "gps_south.jpg", lat: -33.8688, lon: 151.2093) else {
            XCTFail("Failed to create test JPEG")
            return
        }
        
        let coords = readGPSFromImage(at: url)
        XCTAssertNotNil(coords)
        if let coords = coords {
            XCTAssertEqual(coords.lat, -33.8688, accuracy: 0.001)
            XCTAssertEqual(coords.lon, 151.2093, accuracy: 0.001)
        }
    }
    
    func testNoGPSReturnsNil() {
        guard let url = createJPEGWithoutGPS(name: "no_gps.jpg") else {
            XCTFail("Failed to create test JPEG without GPS")
            return
        }
        
        let coords = readGPSFromImage(at: url)
        XCTAssertNil(coords, "Image without GPS should return nil")
    }
    
    // MARK: - Test: Metadata Strip Removes GPS
    
    func testMetadataStripRemovesGPS() async throws {
        guard let url = createJPEGWithGPS(name: "strip_test.jpg", lat: 40.7128, lon: -74.0060) else {
            XCTFail("Failed to create test JPEG")
            return
        }
        
        // Verify GPS exists before strip
        let beforeCoords = readGPSFromImage(at: url)
        XCTAssertNotNil(beforeCoords, "GPS should exist before stripping")
        
        // Strip metadata
        let engine = NeutralizeEngine()
        let success = await engine.stripMetadata(filePath: url.path)
        XCTAssertTrue(success, "Metadata stripping should succeed")
        
        // Verify GPS is gone after strip
        let afterCoords = readGPSFromImage(at: url)
        XCTAssertNil(afterCoords, "GPS should be removed after stripping")
        
        // Verify image file still exists and is valid
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        let source = CGImageSourceCreateWithURL(url as CFURL, nil)
        XCTAssertNotNil(source, "Stripped image should still be a valid image file")
    }
    
    func testMetadataStripPreservesImage() async throws {
        guard let url = createJPEGWithGPS(name: "preserve_test.jpg", lat: 51.5074, lon: -0.1278) else {
            XCTFail("Failed to create test JPEG")
            return
        }
        
        let originalSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        
        let engine = NeutralizeEngine()
        let success = await engine.stripMetadata(filePath: url.path)
        XCTAssertTrue(success)
        
        // Image should still exist with reasonable size
        let newSize = try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int ?? 0
        XCTAssertGreaterThan(newSize, 0, "Stripped image should have non-zero size")
        // Size might differ slightly due to metadata removal, but should be in same ballpark
    }
    
    func testMetadataStripOnNonImageFails() async {
        let textFile = testDir.appendingPathComponent("not_an_image.txt")
        try! "Hello world".write(to: textFile, atomically: true, encoding: .utf8)
        
        let engine = NeutralizeEngine()
        let success = await engine.stripMetadata(filePath: textFile.path)
        XCTAssertFalse(success, "Stripping metadata from a text file should fail gracefully")
    }
    
    func testMetadataStripOnNonExistentFile() async {
        let engine = NeutralizeEngine()
        let success = await engine.stripMetadata(filePath: "/tmp/nonexistent_blackbox_test.jpg")
        XCTAssertFalse(success, "Stripping metadata from nonexistent file should fail")
    }
    
    func testStripCreatesVaultBackup() async throws {
        guard let url = createJPEGWithGPS(name: "vault_backup_test.jpg", lat: 35.6762, lon: 139.6503) else {
            XCTFail("Failed to create test JPEG")
            return
        }
        
        let engine = NeutralizeEngine()
        let _ = await engine.stripMetadata(filePath: url.path)
        
        // Check vault has a backup
        let vaultPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".BlackBox/Vault")
        
        if FileManager.default.fileExists(atPath: vaultPath.path) {
            let contents = try FileManager.default.contentsOfDirectory(
                at: vaultPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
            )
            let backup = contents.first { $0.lastPathComponent.contains("vault_backup_test.jpg") }
            XCTAssertNotNil(backup, "Vault should contain backup of stripped image")
            
            // The backup is encrypted — decrypt it first, then check GPS
            if let backup = backup {
                if let decryptedData = await engine.decryptVaultFile(at: backup) {
                    // Write decrypted data to a temp file to read EXIF
                    let tempDecryptedURL = testDir.appendingPathComponent("decrypted_backup.jpg")
                    try decryptedData.write(to: tempDecryptedURL)
                    let backupCoords = readGPSFromImage(at: tempDecryptedURL)
                    XCTAssertNotNil(backupCoords, "Vault backup should preserve original GPS metadata")
                    try? FileManager.default.removeItem(at: tempDecryptedURL)
                } else {
                    // File may not be encrypted (fallback)
                    let backupCoords = readGPSFromImage(at: backup)
                    XCTAssertNotNil(backupCoords, "Vault backup should preserve original GPS metadata")
                }
                try? FileManager.default.removeItem(at: backup)
            }
        }
    }
}
