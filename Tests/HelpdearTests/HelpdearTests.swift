import Testing
@testable import Helpdear

@Test func hasVersion() {
    #expect(!Helpdear.version.isEmpty)
}
