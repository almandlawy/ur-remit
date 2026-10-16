import XCTest
@testable import URRemit

final class BankInvoiceOCRTests: XCTestCase {
    func testPolishProformaExtractsBankTransferDetailsWithoutJoiningIBANAndBIC() {
        let text = """
        Faktura Proforma numer / Proforma Invoice No. 28/2026
        Sprzedawca / Seller
        PROFIT PARTNER Rafał Sadowski
        Gryfa Pomorskiego 83E/12
        Rachunek bankowy / Bank Account:
        mBank
        PL63 1140 2004 0000 3812 1532 8230 BREXPLPWMBK | EUR
        Wartość brutto / Total gross price 417,00 EUR
        Uwagi / Notes: Numer BIC/BIC-Number: BREXPLPWMBK or BREXPLPWXXX
        Do zapłaty / Total due 417,00 EUR
        """

        let fields = BankInvoiceOCR.extract(text)
        XCTAssertEqual(fields.beneficiary, "PROFIT PARTNER Rafał Sadowski")
        XCTAssertEqual(fields.bank, "mBank")
        XCTAssertEqual(fields.account, "PL63114020040000381215328230")
        XCTAssertEqual(fields.iban, "PL63114020040000381215328230")
        XCTAssertEqual(fields.swift, "BREXPLPWMBK")
        XCTAssertEqual(fields.reference, "28/2026")
        XCTAssertEqual(fields.amount, "417.00")
        XCTAssertEqual(fields.currency, "EUR")
        XCTAssertTrue(fields.missing.isEmpty)
    }

    func testOrdinaryWordsAreNotAcceptedAsSwiftCodes() {
        let fields = BankInvoiceOCR.extract("PROFORMA INVOICE TRANSFER PAYMENT")
        XCTAssertEqual(fields.swift, "")
    }
}
