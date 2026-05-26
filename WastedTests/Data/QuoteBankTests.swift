import XCTest
@testable import Wasted

final class QuoteBankTests: XCTestCase {

    func test_quotesCount_isAtLeast30() {
        XCTAssertGreaterThanOrEqual(QuoteBank.quotes.count, 30)
    }

    func test_noQuoteIsEmpty() {
        for quote in QuoteBank.quotes {
            XCTAssertFalse(
                quote.trimmingCharacters(in: .whitespaces).isEmpty,
                "Found empty quote in bank"
            )
        }
    }

    func test_randomQuote_isNotEmpty() {
        XCTAssertFalse(QuoteBank.random.isEmpty)
    }
}
