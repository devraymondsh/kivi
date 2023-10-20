import fs from "node:fs";
import path from "path";
import json from "big-json";
import { fileURLToPath } from "url";
import { Kivi } from "../src/drivers/js/index.js";
import { isNotNodeJS, isBun } from "../src/drivers/js/runtime.js";

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
const dataJsonPath = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  "faker/data/data.json"
);
console.log("Loading the data. Please be patient.");
if (!isBun()) {
  if (!fs.existsSync(dataJsonPath)) {
    throw new Error("Failed to read the `bench/faker/data/data.json` file.");
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

const assert = (name, left, right) => {
  if (left !== right) {
    throw new Error(
      `Assertion '${name}' failed! Left was '${left}' and right was '${right}'.`
    );
  }
};

const bench = (random_indexes, obj) => {
  const o = obj.init();

  initData.forEach((element) => {
    obj.set(o, element.key, element.value);
  });

  let get_time = 0;
  let set_time = 0;
  let del_time = 0;
  const start = performance.now();
  runData.forEach((element, index) => {
    const set_start = performance.now();
    obj.set(o, element.key, element.value);
    assert(`${obj.name} set`, obj.get(o, element.key), element.value);
    set_time += performance.now() - set_start;

    const get_start = performance.now();
    for (let i = 0; i < 7; i++) {
      const value = obj.get(o, data[index + random_indexes[i]].key);
      // The value may have been deleted by the previous obj.del
      if (value) {
        assert(`${obj.name} get`, value, data[index + random_indexes[i]].value);
      }
    }
    get_time += performance.now() - get_start;

    const del_start = performance.now();
    assert(`${obj.name} del`, obj.del(o, element.key), element.value);
    del_time += performance.now() - del_start;
  });
  const end = performance.now();
  const duration = end - start;

  console.log(`${obj.name} get\t`, get_time, "ms");
  console.log(`${obj.name} set\t`, set_time, "ms");
  console.log(`${obj.name} del\t`, del_time, "ms");
  console.log(`${obj.name} overall\t`, duration, "ms");

  obj.destroy(o);

  return duration;
};

console.log(`Running the benchmark ${benchmarkRepeat} times.`);
const [jsMapResults, plainJsObjectReults, kiviNapiResults, kiviFFIResults] = [
  [],
  [],
  [],
  [],
];
const random_indexes = getRandomInts(1, 20);
for (let i = 0; i <= benchmarkRepeat; i++) {
  jsMapResults.push(
    bench(random_indexes, {
      name: "JsMap",
      init: () => new Map(),
      get: (o, k) => o.get(k),
      destroy: (o) => o.clear(),
      del: (o, k) => {
        const v = o.get(k);
        o.delete(k);
        return v;
      },
      set: (o, k, v) => o.set(k, v),
    })
  );
  plainJsObjectReults.push(
    bench(random_indexes, {
      name: "JsObject",
      init: () => {
        return {};
      },
      destroy: (o) => {},
      get: (o, k) => o[k],
      del: (o, k) => {
        const v = o[k];
        o[k] = undefined;
        return v;
      },
      set: (o, k, v) => {
        o[k] = v;
      },
    })
  );

  const kiviObj = {
    name: "Kivi with Napi",
    init: () => new Kivi(),
    get: (o, k) => o.get(k),
    del: (o, k) => o.del(k),
    destroy: (o) => o.destroy(),
    set: (o, k, v) => o.set(k, v),
  };
  kiviNapiResults.push(bench(random_indexes, kiviObj));
  if (isNotNodeJS()) {
    kiviFFIResults.push(
      bench(random_indexes, {
        ...kiviObj,
        name: "Kivi without Napi",
      })
    );
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
