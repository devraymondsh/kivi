import { Kivi } from "../index.js";

{
  // Plain JS object
  const o = {};
  const start = performance.now();
  for (let i = 0; i < 1_000_000; i++) {
    const key = `foo_${i}`;
    o[key];
    o[key] = "bar";
    o[key];
  }
  const end = performance.now();
  console.log("Plain JS object\t", end - start, "ms");
}

{
  // JS Map
  const m = new Map();
  const start = performance.now();
  for (let i = 0; i < 1_000_000; i++) {
    const key = `foo_${i}`;
    m.get(key);
    m.set(key, "bar");
    m.get(key);
  }
  const end = performance.now();
  console.log("JS Map\t\t", end - start, "ms");
}

{
  // kivi
  const c = new Kivi();
  const start = performance.now();
  for (let i = 0; i < 1_000_000; i++) {
    const key = `foo_${i}`;
    c.get(key);
    c.set(key, "bar");
    c.get(key);
  }
  const end = performance.now();
  c.destroy();
  console.log("kivi\t\t", end - start, "ms");
}
