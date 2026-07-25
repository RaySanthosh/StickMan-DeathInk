# Death Ink - Play Store Asset Pack

Everything needed to create the Google Play listing. Status as of 25 Jul 2026.

## READY (in this folder)
- [x] Release AAB .................. Release/app-release.aab (51.5 MB, signed release)
- [x] App title .................... Store Listing/Title.txt ("Death Ink", 9/30 chars)
- [x] Short description ............ Store Listing/Short Description.txt (70/80 chars)
- [x] Full description ............. Store Listing/Full Description.txt
- [x] 512x512 icon ................. Graphics/Icon-512.png
- [x] 1024x500 feature graphic ..... Graphics/Feature-Graphic-1024x500.png
- [x] Privacy Policy (text) ........ Privacy Policy/privacy-policy.md + index.html
- [x] Contact email ................ Notes/Contact Email.txt
- [x] Release SHA-1/256 ............ Notes/Firebase-SHA.txt (already in Firebase)
- Category: Arcade

## YOU STILL NEED TO DO
- [ ] Phone screenshots (2-8) ...... see Graphics/SCREENSHOTS-GUIDE.md, save as Screenshot-1..8.png here
- [ ] Host the Privacy Policy ...... see Privacy Policy/HOW-TO-HOST-ON-GITHUB-PAGES.md, then put the URL in Notes/Website.txt
- [ ] Verify targetSdk >= 35 at build (Flutter default is fine, just confirm)
- [ ] Confirm the release SHA-1 in the Firebase console
- [ ] Review Firestore security rules (lock docs to request.auth.uid)

## OPTIONAL / RECOMMENDED
- [ ] Tablet screenshots (7" and 10")
- [ ] Promo video (YouTube URL)
- [ ] If you enable Play App Signing, also add Play's app-signing SHA-1 to Firebase (see Notes/Firebase-SHA.txt)
