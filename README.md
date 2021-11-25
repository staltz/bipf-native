# BIPF Native

Work in progress. Zig stuff for Node.js

## Contributing

1. Install Zig 0.8.1
1. `npm install`
1. `npm test`

Source code entry point is at `src/lib.zig`.

## TODO

- Support all APIs that `bipf` (JS) supports
- Pass all tests
- Compile for several targets and publish them under `dist/`, `index.js` should know how to pick the correct binary
- Use a Zig package manager, maybe
- Publish `varint.zig` as a separate Zig module
