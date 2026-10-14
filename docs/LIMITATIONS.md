# Limitations (prioritized, living document)

| # | Priority | Limitation | Status |
|---|---|---|---|
| 1 | High | Home-laptop hosting has no redundancy (power, ISP, thermals, sleep). Dev and private pilot only. | Open until VPS migration |
| 2 | High | Windows has no first-class FCM push; strategy decided in Phase 6. | Open |
| 3 | High | A normal Android or Windows app cannot lock a personal device. Stronger enforcement is managed-device mode only. | By design |
| 4 | High | No end-to-end encryption in chat. | By design |
| 5 | Medium | Alarms cannot ring while the device is off; OEM battery managers can delay local alarms on budget phones. | By design |
| 6 | Medium | Free-tier quotas (R2, SMTP, FCM, Google APIs) are unverified and may change. | See COSTS.md (Phase 0.2) |
| 7 | Medium | Privacy and consent texts are drafts and need lawyer review (Sri Lanka PDPA No. 9 of 2022). | Open |
| 8 | Medium | Play Store policies (Accessibility, exact alarms, package visibility) may restrict features. Sideload first. | Open |
| 9 | Low | Sinhala and Tamil translations are not yet written; ARB structure only. | Planned |
| 10 | Low | iOS, macOS, Linux and web are out of scope until after Phase 9. | Deferred |