import XCTest
@testable import ManorOS

final class ManorOSTests: XCTestCase {
    func testEnergyBillComputedRateIsNonNegative() {
        let bill = EnergyBill(totalKWh: 600, totalCost: 120)
        XCTAssertGreaterThanOrEqual(bill.computedRate, 0)
    }

    func testHomeActualRatesFallBackToDefaults() {
        let home = Home(name: "Test Home")
        XCTAssertGreaterThan(home.actualElectricityRate, 0)
        XCTAssertGreaterThan(home.actualGasRate, 0)
    }
}

