import Foundation
import Testing

@Test func displayScreenSnapshotIsCapturedBeforeSamplerLockToAvoidMainThreadDeadlock() throws {
    let sampler = try fixture("Sources/SharedMetrics/SystemSampler.swift")
    let sampleStart = try #require(sampler.range(of: "public func sample(now: Date = Date()) -> MetricSnapshot {"))
    let sampleLock = try #require(
        sampler.range(
            of: "sampleLock.lock()",
            range: sampleStart.upperBound..<sampler.endIndex
        )
    )
    let prelockSampleBody = sampler[sampleStart.upperBound..<sampleLock.lowerBound]

    #expect(prelockSampleBody.contains("let displayScreenSnapshot = screenDisplaySnapshot()"))
    #expect(sampler.contains("private func sampleDisplays(screenSnapshot: ScreenDisplaySnapshot) -> [DisplayMetric]"))
    #expect(!sampler.contains("private func sampleDisplays() -> [DisplayMetric] {\n        let screenSnapshot = screenDisplaySnapshot()"))
}

private func fixture(_ relativePath: String) throws -> String {
    let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
}
