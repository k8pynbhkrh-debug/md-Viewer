import Testing
import CoreGraphics
@testable import md_Viewer

/// Contract of `documentTabWidth`: tabs share the bar evenly, never narrower
/// than the minimum (then the bar scrolls).
struct DocumentTabWidthTests {
    @Test func tabsFillTheBarEvenly() {
        let width = documentTabWidth(available: 900, count: 4, minWidth: 140)
        #expect(width == 225)
        #expect(width * 4 == 900)
    }

    @Test func exactlyAtMinimumStillFills() {
        #expect(documentTabWidth(available: 560, count: 4, minWidth: 140) == 140)
    }

    @Test func manyTabsKeepTheMinimumWidth() {
        let width = documentTabWidth(available: 900, count: 15, minWidth: 140)
        #expect(width == 140)
        #expect(width * 15 > 900) // the bar scrolls
    }

    @Test func singleTabTakesTheWholeBar() {
        #expect(documentTabWidth(available: 1080, count: 1, minWidth: 140) == 1080)
    }

    @Test func edgeCasesStayAtTheMinimum() {
        #expect(documentTabWidth(available: 0, count: 3, minWidth: 140) == 140)
        #expect(documentTabWidth(available: 900, count: 0, minWidth: 140) == 140)
    }

    @Test func defaultMinimumIsUsed() {
        #expect(documentTabWidth(available: 100, count: 2) == documentTabMinWidth)
    }
}
