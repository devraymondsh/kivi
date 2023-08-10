import { createRequire } from "node:module";
const require = createRequire(import.meta.url);

export const addon = require("../zig-out/lib/addon.node");
