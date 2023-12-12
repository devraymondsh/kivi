import fs from "node:fs";
import path from "node:path";
import json from "big-json";
import { fileURLToPath } from "node:url";
import { Kivi } from "../src/drivers/js/index.js";
import { isBun } from "../src/drivers/js/runtime.js";

const repeatBenchmark = 2;
const fakeDataJsonFile = "faker/data/data.json";

const assert = (name, left, right) => {
  if (left !== right) {
    throw new Error(
      `Assertion '${name}' failed! Left was '${left}' and right was '${right}'.`
    );
  }
};
const resolveOnEmit = (event) => {
  return new Promise(function (resolve, reject) {
    try {
      event.on("data", (data) => resolve(data));
    } catch (e) {
      reject(e);
    }
  });
};
const roundToTwoDecimal = (num) => +(Math.round(num + "e+2") + "e-2");
const numberWithCommas = (x) =>
  x.toString().replace(/\B(?<!\.\d*)(?=(\d{3})+(?!\d))/g, ",");

const benchmarkDeletion = (data, o) => {
  const startingTime = performance.now();
  for (const item of data) {
    assert(`${o.name} deletion`, o.del(item.key), item.value);
  }
  return performance.now() - startingTime;
};
const benchmarkLookup = (data, o) => {
  const startingTime = performance.now();
  for (const item of data) {
    assert(`${o.name} lookup`, o.get(item.key), item.value);
  }
  return performance.now() - startingTime;
};
const benchmarkInsertion = (data, o) => {
  const startingTime = performance.now();
  for (const item of data) {
    o.set(item.key, item.value);
  }
  return performance.now() - startingTime;
};

let averageLogResult = [];
const wrapInHumanReadable = (value) => {
  return {
    totalLookupTime: roundToTwoDecimal(value.totalLookupTime) + " ms",
    lookupPerSecond: numberWithCommas(Math.round(value.lookupPerSecond)),
    totalInsertionTime: roundToTwoDecimal(value.totalInsertionTime) + " ms",
    insertionPerSecond: numberWithCommas(Math.round(value.insertionPerSecond)),
    totalDeletionTime: roundToTwoDecimal(value.totalDeletionTime) + " ms",
    deletionPerSecond: numberWithCommas(Math.round(value.deletionPerSecond)),
  };
};
const formatLogResult = (value) => {
  return {
    totalLookupTime: value.lookupDuration,
    lookupPerSecond: data.length / (value.lookupDuration / 1000),
    totalInsertionTime: value.insertionDuration,
    insertionPerSecond: data.length / (value.insertionDuration / 1000),
    totalDeletionTime: value.deletionDuration,
    deletionPerSecond: data.length / (value.deletionDuration / 1000),
  };
};
const logResults = (name, durationArr, averageArg) => {
  let formattedDurationArr = [];
  const average = formatLogResult(averageArg);
  for (const duration of durationArr) {
    formattedDurationArr.push(wrapInHumanReadable(formatLogResult(duration)));
  }

  averageLogResult.push({
    name,
    totalLookupTime: average.totalLookupTime,
    totalInsertionTime: average.totalInsertionTime,
    totalDeletionTime: average.totalDeletionTime,
  });

  console.log(`\n${name}:`);
  console.table({
    ...formattedDurationArr,
    average: wrapInHumanReadable(average),
  });
};
const logRatio = () => {
  console.log(
    `\n This table shows how much ${averageLogResult[0].name} is faster than ${averageLogResult[1].name}:`
  );

  console.table({
    lookup:
      roundToTwoDecimal(
        averageLogResult[1].totalLookupTime /
          averageLogResult[0].totalLookupTime
      ) + "x",
    insertion:
      roundToTwoDecimal(
        averageLogResult[1].totalInsertionTime /
          averageLogResult[0].totalInsertionTime
      ) + "x",
    deletion:
      roundToTwoDecimal(
        averageLogResult[1].totalDeletionTime /
          averageLogResult[0].totalDeletionTime
      ) + "x",
  });
};

let data;
const dataJsonPath = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  fakeDataJsonFile
);
console.log("Loading the data. Please be patient...");
if (!isBun()) {
  if (!fs.existsSync(dataJsonPath)) {
    throw new Error(`Failed to read the '${fakeDataJsonFile}' file.`);
  }
  const readStream = fs.createReadStream(dataJsonPath);
  const parseStream = json.createParseStream();
  readStream.pipe(parseStream);

  data = await resolveOnEmit(parseStream);
} else {
  const file = Bun.file(dataJsonPath);
  data = await file.json();
}

const builtinMapBenchmark = () => {
  const durationArr = [];
  let average = {
    insertionDuration: 0,
    lookupDuration: 0,
    deletionDuration: 0,
  };
  for (let i = 0; i < repeatBenchmark; i++) {
    const o = {
      name: "JsMap",
      map: new Map(),
      get: function (k) {
        return this.map.get(k);
      },
      set: function (k, v) {
        return this.map.set(k, v);
      },
      del: function (k) {
        const v = this.map.get(k);
        this.map.delete(k);
        return v;
      },
      destroy: function () {
        return this.map.clear();
      },
    };
    const insertionDuration = benchmarkInsertion(data, o);
    const lookupDuration = benchmarkLookup(data, o);
    const deletionDuration = benchmarkDeletion(data, o);
    o.destroy();
    durationArr.push({
      iteration: i,
      insertionDuration,
      lookupDuration,
      deletionDuration,
    });
    if (average.insertionDuration === 0) {
      average = {
        insertionDuration,
        lookupDuration,
        deletionDuration,
      };
    } else {
      average = {
        insertionDuration: (average.insertionDuration + insertionDuration) / 2,
        lookupDuration: (average.lookupDuration + lookupDuration) / 2,
        deletionDuration: (average.deletionDuration + deletionDuration) / 2,
      };
    }
  }
  logResults("JsMap", durationArr, average);
};
const kiviBenchmark = () => {
  const durationArr = [];
  let average = {
    insertionDuration: 0,
    lookupDuration: 0,
    deletionDuration: 0,
  };
  for (let i = 0; i < repeatBenchmark; i++) {
    const o = {
      name: "Kivi",
      map: new Kivi(),
      get: function (k) {
        return this.map.get(k);
      },
      set: function (k, v) {
        return this.map.set(k, v);
      },
      del: function (k) {
        return this.map.del(k);
      },
      destroy: function () {
        return this.map.destroy();
      },
    };
    const insertionDuration = benchmarkInsertion(data, o);
    const lookupDuration = benchmarkLookup(data, o);
    const deletionDuration = benchmarkDeletion(data, o);
    o.destroy();
    durationArr.push({
      iteration: i,
      insertionDuration,
      lookupDuration,
      deletionDuration,
    });
    if (average.insertionDuration === 0) {
      average = {
        insertionDuration,
        lookupDuration,
        deletionDuration,
      };
    } else {
      average = {
        insertionDuration: (average.insertionDuration + insertionDuration) / 2,
        lookupDuration: (average.lookupDuration + lookupDuration) / 2,
        deletionDuration: (average.deletionDuration + deletionDuration) / 2,
      };
    }
  }
  logResults("Kivi", durationArr, average);
};

builtinMapBenchmark();
kiviBenchmark();

logRatio();
