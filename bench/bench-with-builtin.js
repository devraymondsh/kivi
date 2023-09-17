import fs from "node:fs";
import json from "big-json";
import { Kivi } from "../drivers/js/index.js";
import { isNotNodeJS, isBun } from "../drivers/js/runtime.js";

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
const getRandomInts = (min, max) => {
  const all = [];

  for (let i = 0; i < 10; i++) {
    min = Math.ceil(min);
    max = Math.floor(max);
    all.push(Math.floor(Math.random() * (max - min) + min));
  }

  return all;
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

const plainJsObjectBench = (random_indexes) => {
  const o = {};

  initData.forEach((element) => {
    o[element.key] = element.value;
  });

  let get_time = 0;
  let set_time = 0;
  let del_time = 0;
  const start = performance.now();
  runData.forEach((element, index) => {
    const get_start = performance.now();
    o[data[index + random_indexes[0]]];
    o[data[index + random_indexes[1]]];
    o[data[index + random_indexes[2]]];
    o[data[index + random_indexes[3]]];
    o[data[index + random_indexes[4]]];
    o[data[index + random_indexes[5]]];
    o[data[index + random_indexes[6]]];
    o[data[index + random_indexes[7]]];
    get_time += performance.now() - get_start;

    const set_start = performance.now();
    o[element.key] = element.value;
    set_time += performance.now() - set_start;

    const del_start = performance.now();
    o[data[random_indexes[8]]] = undefined;
    del_time += performance.now() - del_start;
  });
  const end = performance.now();
  const duration = end - start;

  console.log("JS object get\t", get_time, "ms");
  console.log("JS object set\t", set_time, "ms");
  console.log("JS object del\t", del_time, "ms");
  console.log("JS object overall\t", duration, "ms");

  return duration;
};
const jsMapBench = (random_indexes) => {
  const c = new Map();

  initData.forEach((element) => {
    c.set(element.key, element.value);
  });

  let get_time = 0;
  let set_time = 0;
  let del_time = 0;
  const start = performance.now();
  runData.forEach((element, index) => {
    const get_start = performance.now();
    c.get(data[index + random_indexes[0]]);
    c.get(data[index + random_indexes[1]]);
    c.get(data[index + random_indexes[2]]);
    c.get(data[index + random_indexes[3]]);
    c.get(data[index + random_indexes[4]]);
    c.get(data[index + random_indexes[5]]);
    c.get(data[index + random_indexes[6]]);
    c.get(data[index + random_indexes[7]]);
    get_time += performance.now() - get_start;

    const set_start = performance.now();
    c.set(element.key, element.value);
    set_time += performance.now() - set_start;

    const del_start = performance.now();
    c.delete(data[random_indexes[8]]);
    del_time += performance.now() - del_start;
  });
  const end = performance.now();
  const duration = end - start;

  console.log("JS map get\t", get_time, "ms");
  console.log("JS map set\t", set_time, "ms");
  console.log("JS map del\t", del_time, "ms");
  console.log("JS map overall\t", duration, "ms");

  return duration;
};
const kiviBench = (forceUseRuntimeFFI, random_indexes) => {
  const c = new Kivi({ forceUseRuntimeFFI: forceUseRuntimeFFI });

  initData.forEach((element) => {
    c.set(element.key, element.value);
  });

  let get_time = 0;
  let set_time = 0;
  let del_time = 0;
  const start = performance.now();
  runData.forEach((element, index) => {
    const get_start = performance.now();
    c.get(data[index + random_indexes[0]]);
    c.get(data[index + random_indexes[1]]);
    c.get(data[index + random_indexes[2]]);
    c.get(data[index + random_indexes[3]]);
    c.get(data[index + random_indexes[4]]);
    c.get(data[index + random_indexes[5]]);
    c.get(data[index + random_indexes[6]]);
    c.get(data[index + random_indexes[7]]);
    get_time += performance.now() - get_start;

    const set_start = performance.now();
    c.set(element.key, element.value);
    set_time += performance.now() - set_start;

    const del_start = performance.now();
    c.del(data[random_indexes[8]]);
    del_time += performance.now() - del_start;
  });
  const end = performance.now();

  c.destroy();
  const duration = end - start;

  console.log(
    `Kivi ${forceUseRuntimeFFI ? "using runtime's FFI" : "using Napi"} get\t`,
    get_time,
    "ms"
  );
  console.log(
    `Kivi ${forceUseRuntimeFFI ? "using runtime's FFI" : "using Napi"} set\t`,
    set_time,
    "ms"
  );
  console.log(
    `Kivi ${forceUseRuntimeFFI ? "using runtime's FFI" : "using Napi"} del\t`,
    del_time,
    "ms"
  );
  console.log(
    `Kivi ${
      forceUseRuntimeFFI ? "using runtime's FFI" : "using Napi"
    } overal\t`,
    duration,
    "ms"
  );

  return duration;
};

console.log(`Running the benchmark ${benchmarkRepeat} times.`);

const [jsMapResults, plainJsObjectReults, kiviNapiResults, kiviFFIResults] = [
  [],
  [],
  [],
  [],
];
const random_indexes = getRandomInts(1, 200);
for (let i = 0; i <= benchmarkRepeat; i++) {
  jsMapResults.push(jsMapBench(random_indexes));
  plainJsObjectReults.push(plainJsObjectBench(random_indexes));
  kiviNapiResults.push(kiviBench(false, random_indexes));
  if (isNotNodeJS()) {
    kiviFFIResults.push(kiviBench(true, random_indexes));
  }
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
if (isNotNodeJS()) {
  console.log(
    `Kivi using runtime's FFI average\t`,
    kiviFFIResultsAverage,
    "ms"
  );
}
