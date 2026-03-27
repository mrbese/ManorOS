## ThermalScan (ManorOS) — QA checklist

### Smoke tests (every build)
- Launch app from cold start
- Complete onboarding with and without address
- Start audit → complete all steps → verify Home Dashboard shows “Audit Complete”
- Add at least 1 room, 1 equipment, 1 appliance, and 1 bill (edit + delete flows)
- Open Home Report → export PDF → share sheet appears
- Settings → Delete This Home / Delete All Data (verify navigation + selected home reset)

### Permission flows
- Camera: first time opening any scan screen (Equipment / Appliance / Bill)
- Photos: picking a bill from library
- Location (optional): climate detection via address / GPS (deny + allow)
- Notifications: onboarding “Enable Notifications” button (deny + allow)

### Device / OS matrix (minimum for launch)
- iPhone SE (small screen) — latest iOS
- iPhone Pro (modern screen) — latest iOS
- iPad (optional) — latest iPadOS

### Accessibility pass
- Dynamic Type at XL/XXL (no clipped text on onboarding, audit, report, settings)
- VoiceOver: verify key controls are discoverable (audit progress, share/export, delete confirmations)
- Contrast: verify primary buttons are readable in light/dark mode

### Build sanity
- `xcodebuild build` on simulator
- `xcodebuild test` on simulator (ManorOSTests)

