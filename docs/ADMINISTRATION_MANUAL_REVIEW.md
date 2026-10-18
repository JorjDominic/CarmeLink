# Administration UI manual review

Work is in the original CarmeLink repository on `main`. These administration improvements were completed alongside Phase 3 and are being committed separately at the user's request. Phase 4 presentation edits are excluded from these administration commits and remain in the working tree.

Run the original project with `flutter run -d chrome -t lib/main_web.dart`; use `flutter run` for native mobile. A Git push does not itself confirm that the deployed website has rebuilt.

| Screen | Changes and checks |
|---|---|
| Accounts | Compact identity/verification cards and six accounts per numbered page. Check desktop search/role filtering, last/next/previous pages, open account, Create account, and refresh after record changes. Existing platform-specific filter visibility is preserved. |
| Guardian links | Separate guardian/tenant identities, relationship and Primary indicator; six links per page. Check existing edit/add link sheets and their actions. |
| Dormitory configuration | Card rows replace plain list tiles. Existing six-choice pagination and filters remain unchanged. Verify protected system choices remain locked and Edit/Archive/Restore still open their original actions. |
| Security & retention | Responsive cards with proposed retention/enforcement facts, Configure/History actions and six groups per page. Enforcement remains disabled exactly as before. |

Use 320, 390, 768px and desktop widths, plus enlarged text. Test the existing account/link actions with appropriate test records; opening and canceling forms is sufficient for a visual check.

Automated validation: 42 presentation/filter/account/retention checks passed at 320/390/768/1280px with normal and 1.6x text. A separate narrow-screen test passed for pagination clearance above the floating Create action. Flutter analysis and whitespace checks passed. No authenticated browser/device manual testing was performed.

Changed files: `lib/core/widgets/management_record_list.dart`, `lib/views/shared/account_management_page.dart`, `lib/views/owner/guardian_link_management_page.dart`, `lib/views/owner/dormitory_configuration_page.dart`, `lib/views/shared/retention_settings_page.dart`, `test/ui/administration_presentation_test.dart`, and this checklist.
