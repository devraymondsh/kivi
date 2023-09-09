import fs from "node:fs";
import json from "big-json";
import { Kivi } from "../drivers/js/index.js";
import { isNodeJS, isBun } from "../drivers/js/runtime.js";

const benchmarkRepeat = 100;

const average = (arr) => arr.reduce((a, b) => a + b, 0) / arr.length;
const resolveOnEmit = (event) => {
  return new Promise(function (resolve, reject) {
    try {
      event.on("data", (data) => resolve(data));
    } catch (e) {
      reject(e);
    }
  });
};

let data;
const dataJsonPath = "faker/data/data.json";
console.log("Loading the data. Please be patient.");
if (!isBun()) {
  if (!fs.existsSync(dataJsonPath)) {
    throw new Error(
      "Failed to read the `data/data.json` file. Follow the instructions found in `data/readme.md` to generate it."
    );
  }
  const readStream = fs.createReadStream(dataJsonPath);
  const parseStream = json.createParseStream();
  readStream.pipe(parseStream);

  data = await resolveOnEmit(parseStream);
} else {
  const file = Bun.file(dataJsonPath);
  data = await file.json();
}

const initData = data.slice(0, data.length * 0.5);
const runData = data.slice(data.length * 0.5, data.length);

const plainJsObjectBench = () => {
  const o = {};

  initData.forEach((element) => {
    o[element.key] = element.value;
  });

  const start = performance.now();
  runData.forEach((element, index) => {
    o[data[index + 10]];
    o[data[index + 20]];
    o[element.key] = element.value;
    o[data[index]] = undefined;
  });
  const end = performance.now();
  const duration = end - start;

  console.log("JS object\t", duration, "ms");

  return duration;
};
const jsMapBench = () => {
  const m = new Map();

  initData.forEach((element) => {
    m.set(element.key, element.value);
  });

  const start = performance.now();
  runData.forEach((element, index) => {
    m.get(data[index + 10]);
    m.get(data[index + 20]);
    m.set(element.key, element.value);
    m.delete(data[index]);
  });
  const end = performance.now();
  const duration = end - start;

  console.log("JS Map\t", duration, "ms");

  return duration;
};
const kiviBench = (forceUseRuntimeFFI) => {
  const c = new Kivi({ forceUseRuntimeFFI: forceUseRuntimeFFI });

  initData.forEach((element) => {
    c.set(element.key, element.value);
  });

  const start = performance.now();
  runData.forEach((element, index) => {
    c.get(data[index + 10]);
    c.get(data[index + 20]);
    c.set(element.key, element.value);
    c.del(data[index]);
  });
  const end = performance.now();
  const duration = end - start;

  console.log(
    `Kivi ${forceUseRuntimeFFI ? "using runtime's FFI" : "using Napi"}\t`,
    duration,
    "ms"
  );
  c.destroy();

  return duration;
};

console.log(`Running the benchmark ${benchmarkRepeat} times.`);

const [jsMapResults, plainJsObjectReults, kiviNapiResults, kiviFFIResults] = [
  [],
  [],
  [],
  [],
];
for (let i = 0; i <= benchmarkRepeat; i++) {
  jsMapResults.push(jsMapBench());
  plainJsObjectReults.push(plainJsObjectBench());
  kiviNapiResults.push(kiviBench(false));
  if (!isNodeJS()) kiviFFIResults.push(kiviBench(true));
  console.log(
    "------------------------------------------------------------------------"
  );
}

const [
  jsMapResultsAverage,
  plainJsObjectReultsAverage,
  kiviNapiResultsAverage,
  kiviFFIResultsAverage,
] = [
  average(jsMapResults),
  average(plainJsObjectReults),
  average(kiviNapiResults),
  average(kiviFFIResults),
];

console.log(`JS Map average\t`, jsMapResultsAverage, "ms");
console.log(`JS Object average\t`, plainJsObjectReultsAverage, "ms");
console.log(`Kivi using Napi average\t`, kiviNapiResultsAverage, "ms");
if (!isNodeJS()) {
  console.log(
    `Kivi using runtime's FFI average\t`,
    kiviFFIResultsAverage,
    "ms"
  );
}
