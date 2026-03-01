import XCTest
@testable import BlackBox

final class VaultTests: XCTestCase {
    
    let testDir = FileManager.default.temporaryDirectory.appendingPathComponent("BlackBoxVaultTests")
    let vaultPath = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".BlackBox/Vault")
    
    override func setUp() {
        super.setUp()
        try? FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: testDir)
        // Clean up only test vault entries (contain "VaultTest" in name)
        cleanupTestVaultEntries()
        super.tearDown()
    }
    
    private func cleanupTestVaultEntries() {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: vaultPath, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]
        ) else { return }
        
        for file in contents where file.lastPathComponent.contains("VaultTest") {
            try? FileManager.default.removeItem(at: file)
        }
    }
    
    private func createTestFile(name: String, content: String) -> URL {
        let url = testDir.appendingPathComponent(name)
        try! content.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    // MARK: - Vault File Tests
    
    func testVaultFileCreatesBackup() async throws {
        let fileURL = createTestFile(name: "VaultTest_backup.txt", content: "Important data to preserve")
        
        let engine = NeutralizeEngine()
        await engine.vaultFile(filePath: fileURL.path)
        
        let vaultedFiles = await engine.listVaultedFiles()
        let testEntry = vaultedFiles.first { $0.lastPathComponent.contains("VaultTest_backup.txt") }
        XCTAssertNotNil(testEntry, "Vaulted file should appear in vault listing")
        
        // Verify content matches original (vault files are encrypted, so decrypt first)
        if let entry = testEntry {
            guard let decryptedData = await engine.decryptVaultFile(at: entry) else {
                XCTFail("Should be able to decrypt vault file")
                return
            }
            let vaultedContent = String(data: decryptedData, encoding: .utf8)
            XCTAssertEqual(vaultedContent, "Important data to preserve", "Vault backup should preserve original content")
        }
    }
    
    func testVaultFileDoesNotModifyOriginal() async throws {
        let content = "This should stay untouched"
        let fileURL = createTestFile(name: "VaultTest_nomod.txt", content: content)
        
        let engine = NeutralizeEngine()
        await engine.vaultFile(filePath: fileURL.path)
        
        // Original file should still exist and be unchanged
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
        let afterContent = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(afterContent, content)
    }
    
    // MARK: - Vault Restore Tests
    
    func testRestoreFromVault() async throws {
        let originalContent = "Content to restore"
        let fileURL = createTestFile(name: "VaultTest_restore.txt", content: originalContent)
        let originalPath = fileURL.path
        
        let engine = NeutralizeEngine()
        await engine.vaultFile(filePath: originalPath)
        
        // Simulate the file being deleted/modified
        try FileManager.default.removeItem(at: fileURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: originalPath))
        
        // Restore from vault
        let vaultedFiles = await engine.listVaultedFiles()
        let vaultEntry = vaultedFiles.first { $0.lastPathComponent.contains("VaultTest_restore.txt") }
        XCTAssertNotNil(vaultEntry)
        
        if let entry = vaultEntry {
            let success = await engine.restoreFromVault(vaultedFileURL: entry, originalPath: originalPath)
            XCTAssertTrue(success, "Restore should succeed")
            
            XCTAssertTrue(FileManager.default.fileExists(atPath: originalPath), "File should exist after restore")
            let restoredContent = try String(contentsOf: URL(fileURLWithPath: originalPath), encoding: .utf8)
            XCTAssertEqual(restoredContent, originalContent, "Restored content should match original")
        }
    }
    
    func testRestoreOverwritesExistingFile() async throws {
        let originalContent = "Original version"
        let fileURL = createTestFile(name: "VaultTest_overwrite.txt", content: originalContent)
        
        let engine = NeutralizeEngine()
        await engine.vaultFile(filePath: fileURL.path)
        
        // Overwrite the file with new content
        try "Modified version".write(to: fileURL, atomically: true, encoding: .utf8)
        let modifiedContent = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertEqual(modifiedContent, "Modified version")
        
        // Restore should overwrite with original
        let vaultedFiles = await engine.listVaultedFiles()
        let vaultEntry = vaultedFiles.first { $0.lastPathComponent.contains("VaultTest_overwrite.txt") }
        
        if let entry = vaultEntry {
            let success = await engine.restoreFromVault(vaultedFileURL: entry, originalPath: fileURL.path)
            XCTAssertTrue(success)
            
            let restoredContent = try String(contentsOf: fileURL, encoding: .utf8)
            XCTAssertEqual(restoredContent, "Original version", "Restore should revert to original content")
        }
    }
    
    // MARK: - Vault List Tests
    
    func testListVaultedFilesReturnsFiles() async throws {
        let file1 = createTestFile(name: "VaultTest_list1.txt", content: "File 1")
        let file2 = createTestFile(name: "VaultTest_list2.txt", content: "File 2")
        
        let engine = NeutralizeEngine()
        await engine.vaultFile(filePath: file1.path)
        await engine.vaultFile(filePath: file2.path)
        
        let listed = await engine.listVaultedFiles()
        let testEntries = listed.filter { $0.lastPathComponent.contains("VaultTest_list") }
        XCTAssertEqual(testEntries.count, 2, "Should list both vaulted test files")
    }
    
    func testListVaultedFilesIsSortedByDate() async throws {
        let file1 = createTestFile(name: "VaultTest_sort1.txt", content: "First")
        
        let engine = NeutralizeEngine()
        await engine.vaultFile(filePath: file1.path)
        
        // Small delay to ensure different timestamps
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        
        let file2 = createTestFile(name: "VaultTest_sort2.txt", content: "Second")
        await engine.vaultFile(filePath: file2.path)
        
        let listed = await engine.listVaultedFiles()
        let testEntries = listed.filter { $0.lastPathComponent.contains("VaultTest_sort") }
        
        XCTAssertEqual(testEntries.count, 2)
        if testEntries.count == 2 {
            // Most recent should come first (sorted descending by date)
            XCTAssertTrue(
                testEntries[0].lastPathComponent.contains("sort2"),
                "Most recent vault entry should be listed first"
            )
        }
    }
    
    // MARK: - Edge Cases
    
    func testVaultNonExistentFile() async {
        let engine = NeutralizeEngine()
        // Should not crash — just log an error
        await engine.vaultFile(filePath: "/tmp/does_not_exist_blackbox_vault_test.txt")
        // If we get here without crashing, the test passes
    }
    
    func testRestoreToInvalidPath() async {
        let fileURL = createTestFile(name: "VaultTest_invalid.txt", content: "Data")
        let engine = NeutralizeEngine()
        await engine.vaultFile(filePath: fileURL.path)
        
        let vaultedFiles = await engine.listVaultedFiles()
        let entry = vaultedFiles.first { $0.lastPathComponent.contains("VaultTest_invalid.txt") }
        
        if let entry = entry {
            // Try restoring to an impossible path
            let success = await engine.restoreFromVault(
                vaultedFileURL: entry,
                originalPath: "/nonexistent_dir/impossible_path/file.txt"
            )
            XCTAssertFalse(success, "Restore to invalid path should fail gracefully")
        }
    }
}
