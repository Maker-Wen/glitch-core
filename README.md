# GlitchCore Web Build

This folder is a Godot Web export. Upload every file in this directory together, keeping the filenames unchanged.

## Local preview

```sh
python3 -m http.server 8080 --directory .
```

Then open http://localhost:8080/.

## Static hosting

Deploy the full contents of this folder to any static web host, for example Netlify, Vercel, GitHub Pages, Nginx, or object storage static website hosting.

Required runtime files:

- index.html
- index.js
- index.wasm
- index.pck
- index.audio.worklet.js
- index.audio.position.worklet.js
- index.icon.png
- index.apple-touch-icon.png
- index.png

Some hosts need correct MIME types:

- .wasm: application/wasm
- .pck: application/octet-stream
- .js: text/javascript
