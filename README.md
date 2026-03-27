# Manor OS

**Open-source iOS home energy assessment tool. Scan rooms with LiDAR, photograph equipment for OCR efficiency analysis, track appliances and utility bills, get prioritized upgrade recommendations with payback periods and battery synergy insights. Built on ACCA Manual J and ASHRAE standards.**

[manoros.com](https://manoros.com)

---

## What It Does

Manor OS turns your iPhone into a residential energy auditor. Walk through your home, scan each room with LiDAR, photograph your HVAC equipment labels, log appliances and lighting, upload utility bills, and get a comprehensive efficiency report with prioritized upgrades ranked by return on investment.

### Guided Audit Flow
- 6-step guided audit: Rooms → Equipment → Appliances & Lighting → Building Envelope → Bills → Review
- Progress bar tracks completion across all steps
- Address autocomplete with automatic climate zone detection

### Room Scanning
- Apple RoomPlan API detects floor area via LiDAR
- Configure windows (count, direction, size, pane type, frame material, condition)
- Ceiling height and insulation quality assessment
- ACCA Manual J simplified BTU load calculation
- Manual input fallback for non-LiDAR devices

### Equipment Assessment
- Photograph equipment rating plates (AC units, heat pumps, furnaces, water heaters, windows, thermostats, washers, dryers)
- On-device OCR extracts model numbers and efficiency ratings via Apple Vision
- Age-based efficiency estimation when labels are unreadable
- Compares current efficiency against code minimums and best-in-class

### Appliance & Lighting Tracking
- Camera-based appliance scanning with category classification
- Specialized lighting audit with OCR for bulb wattage detection
- Tracks phantom/standby loads across 25+ appliance categories
- Annual energy cost estimates per appliance

### Energy Bill Upload
- OCR-based utility bill scanning (kWh, cost, billing period)
- Manual bill entry with date and usage
- Computes actual electricity rates from uploaded bills
- Compares bill-based usage vs. audit-based estimates

### Building Envelope Assessment
- Attic and wall insulation quality rating
- Basement insulation status
- Air sealing and weatherstripping condition
- Scored envelope grade with improvement suggestions

### Home Energy Report
- Overall efficiency grade (A through F) based on weighted criteria
- Estimated annual energy costs with category breakdown
- Top energy consumers ranked
- Prioritized upgrade list sorted by payback period
- Federal tax credit eligibility (Section 25C & 25D)
- Battery synergy analysis: how much additional export capacity efficiency upgrades unlock for home battery systems (Pila Energy, Tesla Powerwall, Base Power, Enphase)
- Exportable PDF report

---

## The Battery Synergy Thesis

An inefficient building envelope directly cannibalizes the value of home battery systems. A poorly insulated home draws 5-6 kW on a summer afternoon, leaving a battery inverter exporting barely half its rated output during peak grid events when electricity prices spike to $2,000-$5,000/MWh.

Manor OS quantifies this: for each home, it calculates how much additional battery export capacity passive efficiency upgrades would unlock. Upgrading attic insulation to R-49 and sealing ducts to <4% leakage can liberate 1.5-2 kW of additional export capacity from the same battery hardware, translating to 30-40% more grid revenue with zero additional battery cost.

This insight is based on ASHRAE standards, ACCA Manual J methodology, and field audit data from LADWP Commercial Lighting Incentive Program (CLIP) assessments.

---

## BTU Calculation Methodology

Based on ACCA Manual J simplified method. See [CALCULATIONS.md](CALCULATIONS.md) for the complete formula reference.

| Parameter | Values |
|---|---|
| Climate factors | Hot: 30 BTU/sq ft, Moderate: 25, Cold: 35 |
| Ceiling height | 8ft: 1.0x, 9ft: 1.12x, 10ft: 1.25x, 12ft: 1.5x |
| Window solar gain | South: 150 BTU/sq ft, West: 120, East: 100, North: 40 |
| Insulation adjustment | Poor: +30%, Average: baseline, Good: -15% |
| Safety factor | 1.10 (10% ACCA standard) |

References: [ACCA Manual J](https://www.acca.org/bookstore/product/manual-j-residential-load-calculation-8th-edition), ASHRAE Handbook of Fundamentals, DOE 2023 efficiency standards.

---

## Equipment Efficiency Benchmarks

| Equipment | 20+ yr old | Current Code Min | Best in Class |
|---|---|---|---|
| Central AC | SEER 9 | SEER2 15.2 | SEER 24 |
| Heat Pump | SEER 9 / HSPF 6.5 | SEER2 15.2 / HSPF2 7.8 | SEER 25+ / HSPF 13+ |
| Furnace | 65% AFUE | 80-90% AFUE | 98.5% AFUE |
| Water Heater (tank) | UEF 0.50 | UEF 0.64 | HPWH UEF 3.5+ |
| Windows (single pane) | U-factor 1.1 | U-factor 0.30 | U-factor 0.15 |

---

## Requirements

- iPhone 12 Pro or later (LiDAR for room scanning)
- Manual input mode works on all iPhones
- iOS 17.0+
- No external dependencies. Apple frameworks only.
- No network calls. Everything runs on-device.

---

## Tech Stack

Swift, SwiftUI, SwiftData, RoomPlan, ARKit, AVFoundation, Vision (OCR), CoreLocation, PDFKit

---

## Project Structure

```
ManorOS/
  App/
    ManorOSApp.swift              App entry point, SwiftData container setup
    SchemaVersioning.swift        SwiftData schema version management
  Models/
    Home.swift                    Top-level model: rooms, equipment, appliances, bills
    Room.swift                    Room with BTU calculations and window data
    Equipment.swift               HVAC/water heater with efficiency tracking
    Appliance.swift               Appliance model with energy + phantom load calculations
    EnergyBill.swift              Utility bill with rate computation
    AuditProgress.swift           Audit step tracking and migration
    EquipmentType.swift           Enum: AC, heat pump, furnace, water heater, etc.
    AgeRange.swift                Enum: 0-5, 5-10, 10-15, 15-20, 20+ years
    WindowInfo.swift              Window properties with U-factor and heat gain
    ClimateZone.swift             Hot / Moderate / Cold
    InsulationQuality.swift       Poor / Average / Good
  Views/
    MainTabView.swift             Bottom tab bar (Home / Report / Settings)
    HomeDashboardView.swift       Single home overview with audit progress
    HomeListView.swift            Multi-home list
    RoomScan/
      ScanView.swift              RoomPlan LiDAR capture flow
      DetailsView.swift           Room configuration form
      ResultsView.swift           BTU results + recommendations
    EquipmentScan/
      EquipmentCameraView.swift   Camera + OCR capture
      EquipmentDetailsView.swift  Manual/OCR entry form
      EquipmentResultView.swift   Single equipment analysis
    ApplianceScan/
      ApplianceScanView.swift     Camera-based appliance scanning
      ApplianceDetailsView.swift  Appliance entry form
      ApplianceResultView.swift   Appliance energy analysis
      LightingCloseupView.swift   Lighting OCR for bulb wattage
    BillScan/
      BillUploadView.swift        Bill photo/library upload with OCR
      BillDetailsView.swift       Manual bill entry form
      BillSummaryView.swift       Bill overview and rate analysis
    AuditFlow/
      AuditFlowView.swift         6-step guided audit coordinator
      AuditProgressBar.swift      Visual progress indicator
      EnvelopeAssessmentView.swift Building envelope questionnaire
    WindowAssessment/
      WindowQuestionnaireView.swift Window properties form
    Onboarding/
      OnboardingView.swift        6-step onboarding flow
      OnboardingStepViews.swift   Individual step content
      OnboardingCard.swift        Reusable onboarding card
      OnboardingProgressBar.swift Progress indicator
    Report/
      HomeReportView.swift        Full home assessment report
      ReportTabView.swift         Report navigation
      ReportPDFGenerator.swift    PDF export with styled layout
    Settings/
      SettingsView.swift          Rates, notifications, data management
  Services/
    EnergyCalculator.swift        ACCA Manual J BTU calculation engine
    EnergyProfileService.swift    Aggregates costs into energy breakdown
    GradingEngine.swift           A-F weighted efficiency grading
    EfficiencyDatabase.swift      Equipment lookup tables by type and age
    RecommendationEngine.swift    Context-aware efficiency tips
    UpgradeEngine.swift           Upgrade costs, savings, payback periods
    RebateDatabase.swift          Federal + state rebate data (IRA, state programs)
    RebateService.swift           Rebate eligibility filtering
    RoomCaptureService.swift      RoomPlan + ARKit wrapper
    OCRService.swift              Apple Vision text recognition for equipment
    LightingOCRService.swift      Specialized OCR for light bulb specs
    BillParsingService.swift      Utility bill OCR parser
    ApplianceClassificationService.swift  Appliance category classification
    SharedCameraService.swift     Shared camera session across scan views
    AddressSearchService.swift    Geocoding + address autocomplete
    StateDetectionService.swift   Location-based state detection
    AppleSignInCoordinator.swift  Sign In with Apple handler
    NotificationPermissionService.swift  iOS notification permissions
    NotificationScheduler.swift   Engagement notification scheduling
    AnalyticsService.swift        Debug event tracking
  Utils/
    Constants.swift               Calculation constants, default rates
    ManorColors.swift             Centralized brand color system
```

---

## License

MIT License

---

Built by [Omer Bese](https://linkedin.com/in/omerbese) | Energy Systems Engineer | Columbia University MS Sustainability Management

Methodology informed by professional energy audit experience with the LADWP CLIP program, ASHRAE standards, and DOE residential efficiency guidelines.
