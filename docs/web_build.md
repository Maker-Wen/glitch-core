# GlitchCore Web Build

This project ships a Godot Web export as a static HTML5 game package.

## Build

From the project root:

```sh
./tools/export_web.sh
```

The build output is written to:

```text
build/web/index.html
```

The full `build/web` directory must be shared or uploaded together. `index.html` depends on the adjacent `.js`, `.wasm`, `.pck`, and audio worklet files.

## Local Preview

From the project root:

```sh
./tools/serve_web.sh
```

Then open:

```text
http://127.0.0.1:8060/
```

Godot Web builds are not expected to run reliably from `file://` by double-clicking `index.html`. Use a local HTTP server or deploy the files to static hosting.

## Sharing

To send the game to another person, compress the whole `build/web` folder and ask them to serve it with any static HTTP server. For example, after unzipping inside `build/web`:

```sh
python3 -m http.server 8060 --bind 127.0.0.1
```

Then they can open `http://127.0.0.1:8060/` in a browser.

For public sharing, upload the full contents of `build/web` to static hosting such as itch.io, Netlify, Vercel, GitHub Pages, Nginx, or object-storage static website hosting.

Some hosts need explicit MIME types:

- `.wasm`: `application/wasm`
- `.pck`: `application/octet-stream`
- `.js`: `text/javascript`

