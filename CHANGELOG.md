## 1.0.1

* Live detection tolerates a card held a few degrees off (tilted edge search), a finger over one side and low contrast with the background; it prefers the outermost card edge over lines printed inside the card.
* Looser `DetectionConfig` defaults: `edgeTolerance` 0.10, `maxSkew` 0.08, `outerSearchBand` 0.14, `minEdgeCoverage` 0.6. A small card now reports `tooFar` instead of `notAligned`.
* Front verification matches the header at several scales, so both designs pass with a slightly imprecise crop.
* Back verification searches the MRZ over the whole lower half of the card when it is not in the template box.
* `DocumentCapture.template` (and `cropFields()`) follows the design the verification recognised (new `detectedType`).
* Legacy front field boxes recalibrated on a full-resolution card.
* `showDebugInfo` shows a non-personal summary of the last capture's checks (crop, screen/printout scores, header scores, masked MRZ attempts). New `DocumentVerification.diagnostics` and `IdDocumentScannerController.lastCheckDiagnostics`.

## 0.1.1

* Shorter package description.
* Fix an analyzer warning in the controller and format the code.

## 0.1.0

* Initial release.
* Camera scanner with a customizable, animated card guide that turns green when the card is aligned, sharp and well lit; auto or manual capture.
* Exact card crop: edge refinement and perspective rectification to the ID-1 aspect.
* Agnostic flow control: `CaptureValidator` callback (e.g. your backend) decides whether to move from the front to the back.
* Paraguayan identity card verification (current and legacy designs): front header matching and offline MRZ OCR (ICAO 9303 TD1) of the back.
* Rejection of photos of screens and colour printouts (moiré, sub-pixel stripes, halftone).
