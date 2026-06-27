import Foundation
import Testing

@Test("AppStoreScreenshot root is structural only")
func appStoreScreenshotRootIsStructuralOnly() throws {
    let root = repositoryRoot()
    let screenshotRoot = root.appendingPathComponent("docs/app-store/screenshots", isDirectory: true)
    let rootUploadableImages = try uploadableImageFiles(in: screenshotRoot)

    #expect(FileManager.default.fileExists(atPath: screenshotRoot.path))
    #expect(FileManager.default.fileExists(atPath: screenshotRoot.appendingPathComponent(".gitkeep").path))
    #expect(rootUploadableImages.isEmpty)
}

@Test("AppStoreScreenshot locale directories exist")
func appStoreScreenshotLocaleDirectoriesExist() throws {
    #expect(fileExists("docs/app-store/screenshots/en/.gitkeep"))
    #expect(fileExists("docs/app-store/screenshots/zh-Hans/.gitkeep"))
}

@Test("AppStoreScreenshot Chinese screenshots keep required names")
func appStoreScreenshotChineseScreenshotsKeepRequiredNames() throws {
    for name in expectedScreenshotNames {
        #expect(fileExists("docs/app-store/screenshots/zh-Hans/\(name)"))
        #expect(!fileExists("docs/app-store/screenshots/\(name)"))
    }
}

@Test("AppStoreScreenshot validator defaults to English locale subdirectory")
func appStoreScreenshotValidatorDefaultsToEnglishLocaleSubdirectory() throws {
    let script = try fixture("scripts/validate-app-store-screenshots.sh")

    #expect(script.contains(#"SCREENSHOT_LOCALE="${SCREENSHOT_LOCALE:-en}""#))
    #expect(script.contains(#"SCREENSHOT_DIR="${SCREENSHOT_DIR:-$ROOT_DIR/docs/app-store/screenshots/$SCREENSHOT_LOCALE}""#))
    #expect(!script.contains(#"SCREENSHOT_DIR="${SCREENSHOT_DIR:-$ROOT_DIR/docs/app-store/screenshots}""#))
}

@Test("AppStoreScreenshot validator preserves rules and overrides")
func appStoreScreenshotValidatorPreservesRulesAndOverrides() throws {
    let script = try fixture("scripts/validate-app-store-screenshots.sh")

    #expect(script.contains("sips -g pixelWidth -g pixelHeight"))
    #expect(script.contains("2880x1800"))
    #expect(script.contains("2560x1600"))
    #expect(script.contains("1440x900"))
    #expect(script.contains("1280x800"))
    #expect(script.contains("if (( count != ${#expected_files[@]} )); then"))
    #expect(script.contains("Missing expected screenshot: $expected_file"))
    #expect(script.contains("Unexpected screenshot file: $(basename \"$screenshot\")"))
    #expect(script.contains("Expected files: 01-overview.png, 02-cpu-memory.png, 03-network-storage.png, 04-widget-popover.png, 05-settings-history.png."))
    #expect(script.contains("Capture English screenshots in docs/app-store/screenshots/en for global release, or run SCREENSHOT_LOCALE=zh-Hans scripts/validate-app-store-screenshots.sh to validate the existing Chinese screenshots."))
    #expect(script.contains("SCREENSHOT_LOCALE"))
    #expect(script.contains("SCREENSHOT_DIR"))
}

@Test("AppStoreScreenshot audit doc references locale workflow")
func appStoreScreenshotAuditDocReferencesLocaleWorkflow() throws {
    let audit = try fixture("docs/data-capability-audit.md")

    #expect(audit.contains("docs/app-store/screenshots/en/"))
    #expect(audit.contains("docs/app-store/screenshots/zh-Hans/"))
    #expect(audit.contains("SCREENSHOT_LOCALE=en scripts/validate-app-store-screenshots.sh"))
    #expect(audit.contains("SCREENSHOT_LOCALE=zh-Hans scripts/validate-app-store-screenshots.sh"))
}

@Test("AppStoreScreenshot release checklist references locale workflow")
func appStoreScreenshotReleaseChecklistReferencesLocaleWorkflow() throws {
    let releaseChecklist = try fixture("docs/app-store-release-checklist.md")

    #expect(releaseChecklist.contains("docs/app-store/screenshots/en/"))
    #expect(releaseChecklist.contains("docs/app-store/screenshots/zh-Hans/"))
    #expect(releaseChecklist.contains("SCREENSHOT_LOCALE=en scripts/validate-app-store-screenshots.sh"))
    #expect(releaseChecklist.contains("SCREENSHOT_LOCALE=zh-Hans scripts/validate-app-store-screenshots.sh"))
}

private let expectedScreenshotNames = [
    "01-overview.png",
    "02-cpu-memory.png",
    "03-network-storage.png",
    "04-widget-popover.png",
    "05-settings-history.png"
]

private func repositoryRoot() -> URL {
    URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}

private func fixture(_ path: String) throws -> String {
    try String(contentsOf: repositoryRoot().appendingPathComponent(path), encoding: .utf8)
}

private func fileExists(_ path: String) -> Bool {
    FileManager.default.fileExists(atPath: repositoryRoot().appendingPathComponent(path).path)
}

private func uploadableImageFiles(in directory: URL) throws -> [String] {
    let allowedExtensions = Set(["png", "jpg", "jpeg"])
    let urls = try FileManager.default.contentsOfDirectory(
        at: directory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    )

    return urls
        .filter { allowedExtensions.contains($0.pathExtension.lowercased()) }
        .map(\.lastPathComponent)
        .sorted()
}
