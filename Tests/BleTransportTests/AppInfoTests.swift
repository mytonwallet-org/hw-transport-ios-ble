import XCTest
@testable import BleTransport

final class AppInfoTests: XCTestCase {
    func testAppCommandsIncludeEmptyDataLength() {
        XCTAssertEqual(APDUs.getAppAndVersion.data, Data([0xb0, 0x01, 0x00, 0x00, 0x00]))
        XCTAssertEqual(APDUs.closeApp.data, Data([0xb0, 0xa7, 0x00, 0x00, 0x00]))
    }

    func testParsesDashboardAndAppWithOptionalFlags() throws {
        let dashboard = try BleTransport.parseAppAndVersion("0105424f4c4f5305322e362e319000")
        XCTAssertEqual(dashboard.name, "BOLOS")
        XCTAssertEqual(dashboard.version, "2.6.1")

        let app = try BleTransport.parseAppAndVersion("0103544f4e05322e362e3101029000")
        XCTAssertEqual(app.name, "TON")
        XCTAssertEqual(app.version, "2.6.1")
    }

    func testDeviceErrorsAreNotParsedAsAppMetadata() {
        let cases: [(String, BleStatusError)] = [
            ("5515", .deviceLocked(status: "5515")),
            ("5501", .userRejected(status: "5501")),
            ("6985", .userRejected(status: "6985")),
            ("6807", .appNotAvailableInDevice(status: "6807")),
            ("6984", .appNotAvailableInDevice(status: "6984")),
            ("6700", .unknown(status: "6700")),
            ("6D00", .unknown(status: "6d00")),
        ]
        for (response, expected) in cases {
            XCTAssertThrowsError(try BleTransport.parseAppAndVersion(response)) { error in
                XCTAssertEqual(error as? BleStatusError, expected, response)
            }
        }
    }

    func testTruncatedFieldsCannotConsumeStatusBytes() {
        let payload = "0103544f4e05322e362e31"
        for length in stride(from: 0, to: payload.count, by: 2) {
            let response = String(payload.prefix(length)) + "9000"
            XCTAssertThrowsError(try BleTransport.parseAppAndVersion(response)) { error in
                XCTAssertEqual(error as? BleStatusError, .couldNotParseResponseData(status: "9000"), response)
            }
        }
    }

    func testRejectsInvalidFieldLengthsAndEncoding() {
        for response in ["01ff9000", "0100544f4e9000", "0103544f4e009000", "0103544fff05322e362e319000"] {
            XCTAssertThrowsError(try BleTransport.parseAppAndVersion(response)) { error in
                XCTAssertEqual(error as? BleStatusError, .couldNotParseResponseData(status: "9000"), response)
            }
        }
    }

    func testUnsupportedFormatIsDistinctFromDeviceErrors() {
        XCTAssertThrowsError(try BleTransport.parseAppAndVersion("029000")) { error in
            XCTAssertEqual(error as? BleStatusError, .formatNotSupported(status: "9000"))
        }
    }

    func testRejectsMissingStatusAndMalformedHex() {
        for response in ["", "90", "900", "xyz9000", "zz9000", "９０００"] {
            XCTAssertThrowsError(try BleTransport.parseAppAndVersion(response)) { error in
                XCTAssertEqual(error as? BleStatusError, .noStatus, response)
            }
        }
    }
}
