import XCTest
@testable import BlackBox

/// Tests for the ExclusionList safety guardrail.
final class ExclusionListTests: XCTestCase {
    
    // MARK: - Blocked Paths
    
    func testSystemPathIsBlocked() {
        XCTAssertFalse(ExclusionList.isSafePath("/System/Library/anything"))
        XCTAssertFalse(ExclusionList.isSafePath("/System"))
    }
    
    func testLibraryReceiptsIsBlocked() {
        XCTAssertFalse(ExclusionList.isSafePath("/Library/Receipts/com.apple.something.plist"))
    }
    
    func testBinIsBlocked() {
        XCTAssertFalse(ExclusionList.isSafePath("/bin/bash"))
        XCTAssertFalse(ExclusionList.isSafePath("/bin/ls"))
    }
    
    func testSbinIsBlocked() {
        XCTAssertFalse(ExclusionList.isSafePath("/sbin/mount"))
    }
    
    func testUsrBinIsBlocked() {
        XCTAssertFalse(ExclusionList.isSafePath("/usr/bin/grep"))
    }
    
    func testUsrLibIsBlocked() {
        XCTAssertFalse(ExclusionList.isSafePath("/usr/lib/libSystem.dylib"))
    }
    
    // MARK: - Safe Paths
    
    func testUserHomeIsSafe() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertTrue(ExclusionList.isSafePath(home + "/Documents/test.txt"))
    }
    
    func testDownloadsIsSafe() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertTrue(ExclusionList.isSafePath(home + "/Downloads/file.pdf"))
    }
    
    func testPicturesIsSafe() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertTrue(ExclusionList.isSafePath(home + "/Pictures/photo.jpg"))
    }
    
    func testTmpIsSafe() {
        XCTAssertTrue(ExclusionList.isSafePath("/tmp/somefile.txt"))
    }
    
    func testTrashIsSafe() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        XCTAssertTrue(ExclusionList.isSafePath(home + "/.Trash/deleted.txt"))
    }
    
    // MARK: - Protected File Names
    
    func testDSStoreIsBlocked() {
        XCTAssertFalse(ExclusionList.isSafePath("/tmp/.DS_Store"))
    }
    
    // MARK: - URL Filtering
    
    func testFilterSafeRemovesBlockedURLs() {
        let urls = [
            URL(fileURLWithPath: "/System/Library/test"),
            URL(fileURLWithPath: "/tmp/safe.txt"),
            URL(fileURLWithPath: "/bin/blocked"),
            URL(fileURLWithPath: "/Users/test/Documents/ok.txt"),
        ]
        let safe = ExclusionList.filterSafe(urls)
        XCTAssertEqual(safe.count, 2)
        XCTAssertTrue(safe.contains { $0.path == "/tmp/safe.txt" })
        XCTAssertTrue(safe.contains { $0.path == "/Users/test/Documents/ok.txt" })
    }
}
