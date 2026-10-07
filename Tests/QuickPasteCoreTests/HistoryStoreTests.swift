import XCTest
@testable import QuickPasteCore

final class HistoryStoreTests: XCTestCase {
    private var tempURL: URL!

    override func setUp() {
        super.setUp()
        tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempURL.deletingLastPathComponent())
        super.tearDown()
    }

    func testAddInsertsNewestFirst() {
        let store = HistoryStore(fileURL: nil)
        store.add("a")
        store.add("b")
        XCTAssertEqual(store.items.map(\.text), ["b", "a"])
    }

    func testAddIgnoresEmptyAndWhitespaceOnly() {
        let store = HistoryStore(fileURL: nil)
        store.add("")
        store.add("  \n\t")
        XCTAssertTrue(store.items.isEmpty)
    }

    func testDuplicateMovesToFront() {
        let store = HistoryStore(fileURL: nil)
        store.add("a")
        store.add("b")
        store.add("a")
        XCTAssertEqual(store.items.map(\.text), ["a", "b"])
    }

    func testLimitDropsOldest() {
        let store = HistoryStore(fileURL: nil, limit: 3)
        ["1", "2", "3", "4"].forEach(store.add)
        XCTAssertEqual(store.items.map(\.text), ["4", "3", "2"])
    }

    func testRemoveAndClear() {
        let store = HistoryStore(fileURL: nil)
        store.add("a")
        store.add("b")
        store.remove(id: store.items[0].id)
        XCTAssertEqual(store.items.map(\.text), ["a"])
        store.clear()
        XCTAssertTrue(store.items.isEmpty)
    }

    func testSearchIsCaseInsensitive() {
        let store = HistoryStore(fileURL: nil)
        ["Hello World", "foo", "say hello"].forEach(store.add)
        XCTAssertEqual(store.search("HELLO").map(\.text), ["say hello", "Hello World"])
        XCTAssertEqual(store.search("  ").count, 3)
    }

    func testPersistsAcrossInstances() {
        let store = HistoryStore(fileURL: tempURL)
        store.add("a")
        store.add("b")
        let reloaded = HistoryStore(fileURL: tempURL)
        XCTAssertEqual(reloaded.items.map(\.text), ["b", "a"])
    }

    func testCorruptFileStartsEmpty() throws {
        try FileManager.default.createDirectory(
            at: tempURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: tempURL)
        XCTAssertTrue(HistoryStore(fileURL: tempURL).items.isEmpty)
    }
}
