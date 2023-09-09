export const isBun = () => "Bun" in globalThis;
export const isDeno = () => "Deno" in globalThis;
export const isNodeJS = () =>
  typeof global !== "undefined" && globalThis === global;
export const isNotNodeJS = () => isBun() || isDeno();

export const getRuntimeKind = () => {
  if (isBun()) return "bun";
  else if (isDeno()) return "deno";
  else if (isNodeJS()) return "node";
  else return undefined;
};
