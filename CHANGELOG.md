## 0.1.0

* Initial release.
* Camera scanner with a customizable, animated card guide that turns green when the card is aligned, sharp and well lit; auto or manual capture.
* Exact card crop: edge refinement and perspective rectification to the ID-1 aspect.
* Agnostic flow control: `CaptureValidator` callback (e.g. your backend) decides whether to move from the front to the back.
* Paraguayan identity card verification (current and legacy designs): front header matching and offline MRZ OCR (ICAO 9303 TD1) of the back.
* Rejection of photos of screens and colour printouts (moiré, sub-pixel stripes, halftone).
