# WIT Service Report PWA

Offline-first Progressive Web App for creating WIT service reports with:

- Mobile-friendly service report form
- Offline support via Service Worker
- IndexedDB local draft/report storage
- Photo attachments
- Customer / Service / Approve signatures
- PDF generation matching the original paper form layout
- Thai text support in PDF via embedded NotoSansThai font
- WIT company logo embedded in generated PDF

## Run locally

```bash
cd /c/Users/biwpo/wit-service-report
python -m http.server 8080
```

Open:

```text
http://localhost:8080/index.html
```

For phone/tablet on same WiFi, use the computer's LAN IP:

```text
http://<COMPUTER_IP>:8080/index.html
```

## Main files

- `index.html` — single-file PWA application
- `sw.js` — service worker cache/offline support
- `manifest.json` — PWA manifest
- `new-logo-wit-pdf.jpg` — optimized WIT logo for PDF output
