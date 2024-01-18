import { createRequire } from "node:module";
const createdRequire = createRequire(import.meta.url);

export const require = (...args) => createdRequire(...args);
