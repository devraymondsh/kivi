import { Buffer } from "node:buffer";

const count = 1_000_000;

const genRandomNum = (min, max) => {
  return Math.random() * (max - min) + min;
};
const genRandomStr = function (length) {
  let result = "";
  const characters =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  const charactersLength = characters.length;
  let counter = 0;
  while (counter < length) {
    result += characters.charAt(Math.floor(Math.random() * charactersLength));
    counter += 1;
  }
  return result;
};
function genUUID() {
  // Public Domain/MIT
  var d = new Date().getTime(); //Timestamp
  var d2 =
    (typeof performance !== "undefined" &&
      performance.now &&
      performance.now() * 1000) ||
    0; //Time in microseconds since page-load or 0 if unsupported
  return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function (c) {
    var r = Math.random() * 16; //random number between 0 and 16
    if (d > 0) {
      //Use timestamp until depleted
      r = (d + r) % 16 | 0;
      d = Math.floor(d / 16);
    } else {
      //Use microseconds since page-load if supported
      r = (d2 + r) % 16 | 0;
      d2 = Math.floor(d2 / 16);
    }
    return (c === "x" ? r : (r & 0x3) | 0x8).toString(16);
  });
}

export const generateFakeData = () => {
  console.log("Generating fake data for the benchmark...");

  const data = [];
  for (let i = 0; i <= count; i++) {
    const key = genRandomStr(genRandomNum(2, 150)) + genUUID();
    data.push({
      key,
      kyb: Buffer.from(key, "utf8"),
      value: Buffer.from(genRandomStr(genRandomNum(2, 500)), "utf8"),
    });
    if (i % (count / 10) == 0 && i != 0) {
      console.log((i / count) * 100 + "%");
    }
  }

  return data;
};
