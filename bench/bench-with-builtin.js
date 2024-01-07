import fs from "node:fs";
import path from "node:path";
import json from "big-json";
import { fileURLToPath } from "node:url";
import { Kivi } from "../src/drivers/js/index.js";
import { isBun } from "../src/drivers/js/runtime.js";
import { generateFakeData } from "./faker/generate.js";

const repeatBenchmark = 2;
const fakeDataJsonFile = "faker/data/data.json";
const dataJsonPath = path.resolve(
  path.dirname(fileURLToPath(import.meta.url)),
  fakeDataJsonFile
);

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

const benchmarkDeletion = (data, o) => {
  const startingTime = performance.now();
  for (const item of data) {
    assert(`${o.name} deletion`, o.del(item.key), item.value);
  }
  return performance.now() - startingTime;
};
const benchmarkBulkDeletion = (data, o) => {
  const startingTime = performance.now();
  o.bulkDel(dataKeys);
  return performance.now() - startingTime;
};
const benchmarkLookup = (data, o) => {
  const startingTime = performance.now();
  for (const item of data) {
    assert(`${o.name} lookup`, o.get(item.key), item.value);
  }
  return performance.now() - startingTime;
};
const benchmarkBulkLookup = (data, o) => {
  const startingTime = performance.now();
  o.bulkGet(dataKeys);
  return performance.now() - startingTime;
};
const benchmarkInsertion = (data, o) => {
  const startingTime = performance.now();
  for (const item of data) {
    o.set(item.key, item.value);
  }
  return performance.now() - startingTime;
};
const benchmarkBulkInsertion = (data, o) => {
  const startingTime = performance.now();
  o.bulkSet(data);
  return performance.now() - startingTime;
};

let averageLogResult = [];
const wrapInHumanReadable = (value) => {
  return {
    totalLookupTime: roundToTwoDecimal(value.totalLookupTime) + " ms",
    totalBulkLookupTime: roundToTwoDecimal(value.totalBulkLookupTime) + " ms",
    totalInsertionTime: roundToTwoDecimal(value.totalInsertionTime) + " ms",
    totalBulkInsertionTime:
      roundToTwoDecimal(value.totalBulkInsertionTime) + " ms",
    totalDeletionTime: roundToTwoDecimal(value.totalDeletionTime) + " ms",
    totalBulkDeletionTime:
      roundToTwoDecimal(value.totalBulkDeletionTime) + " ms",
  };
};
const formatLogResult = (value) => {
  return {
    totalLookupTime: value.lookupDuration,
    totalBulkLookupTime: value.bulkLookupDuration,
    totalInsertionTime: value.insertionDuration,
    totalBulkInsertionTime: value.bulkInsertionDuration,
    totalDeletionTime: value.deletionDuration,
    totalBulkDeletionTime: value.bulkDeletionDuration,
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
    totalBulkLookupTime: average.totalBulkLookupTime,
    totalInsertionTime: average.totalInsertionTime,
    totalBulkInsertionTime: average.totalBulkInsertionTime,
    totalDeletionTime: average.totalDeletionTime,
    totalBulkDeletionTime: average.totalBulkDeletionTime,
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
    bulkLookup:
      roundToTwoDecimal(
        averageLogResult[1].totalBulkLookupTime /
          averageLogResult[0].totalBulkLookupTime
      ) + "x",
    bulkInsertion:
      roundToTwoDecimal(
        averageLogResult[1].totalBulkInsertionTime /
          averageLogResult[0].totalBulkInsertionTime
      ) + "x",
    bulkDeletion:
      roundToTwoDecimal(
        averageLogResult[1].totalBulkDeletionTime /
          averageLogResult[0].totalBulkDeletionTime
      ) + "x",
  });
};

let data;
if (!fs.existsSync(dataJsonPath)) {
  await generateFakeData();
}
console.log("Loading the data. Please be patient...");
if (!isBun()) {
  const readStream = fs.createReadStream(dataJsonPath);
  const parseStream = json.createParseStream();
  readStream.pipe(parseStream);

  data = await resolveOnEmit(parseStream);
} else {
  const file = Bun.file(dataJsonPath);
  data = await file.json();
}
let dataKeys = data.map((el) => el.key);

const builtinMapBenchmark = () => {
  const durationArr = [];
  let average = {
    insertionDuration: 0,
    lookupDuration: 0,
    deletionDuration: 0,
  };
  for (let i = 0; i < repeatBenchmark; i++) {
    let o = {
      name: "JsMap",
      map: new Map(),
      get: function (k) {
        return this.map.get(k);
      },
      bulkGet: function (ks) {
        const res = [];
        for (const k of ks) {
          res.push(this.map.get(k));
        }
        return res;
      },
      set: function (k, v) {
        return this.map.set(k, v);
      },
      bulkSet: function (data) {
        const res = [];
        for (const kv of data) {
          res.push(this.map.set(kv.key, kv.value));
        }
        return res;
      },
      del: function (k) {
        const v = this.map.get(k);
        this.map.delete(k);
        return v;
      },
      bulkDel: function (ks) {
        const res = [];
        for (const k of ks) {
          res.push(this.map.get(k));
          this.map.delete(k);
        }
        return res;
      },
      destroy: function () {
        return this.map.clear();
      },
    };
    const bulkInsertionDuration = benchmarkBulkInsertion(data, o);
    const bulkLookupDuration = benchmarkBulkLookup(data, o);
    const bulkDeletionDuration = benchmarkBulkDeletion(data, o);
    o.destroy();

    o.map = new Map();

    const insertionDuration = benchmarkInsertion(data, o);
    const lookupDuration = benchmarkLookup(data, o);
    const deletionDuration = benchmarkDeletion(data, o);
    o.destroy();
    durationArr.push({
      iteration: i,
      insertionDuration,
      lookupDuration,
      deletionDuration,
      bulkInsertionDuration,
      bulkLookupDuration,
      bulkDeletionDuration,
    });
    if (average.insertionDuration === 0) {
      average = {
        insertionDuration,
        lookupDuration,
        deletionDuration,
        bulkInsertionDuration,
        bulkInsertionDuration,
        bulkLookupDuration,
        bulkDeletionDuration,
      };
    } else {
      average = {
        insertionDuration: (average.insertionDuration + insertionDuration) / 2,
        bulkInsertionDuration:
          (average.bulkInsertionDuration + bulkInsertionDuration) / 2,
        lookupDuration: (average.lookupDuration + lookupDuration) / 2,
        bulkLookupDuration:
          (average.bulkLookupDuration + bulkLookupDuration) / 2,
        deletionDuration: (average.deletionDuration + deletionDuration) / 2,
        bulkDeletionDuration:
          (average.bulkDeletionDuration + bulkDeletionDuration) / 2,
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
    let o = {
      name: "Kivi",
      map: new Kivi(),
      get: function (k) {
        return this.map.get(k);
      },
      bulkGet: function (ks) {
        return this.map.bulkGet(ks);
      },
      set: function (k, v) {
        return this.map.set(k, v);
      },
      bulkSet: function (data) {
        return this.map.bulkSet(data);
      },
      del: function (k) {
        return this.map.fetchDel(k);
      },
      bulkDel: function (ks) {
        return this.map.bulkFetchDel(ks);
      },
      destroy: function () {
        return this.map.destroy();
      },
    };
    const bulkInsertionDuration = benchmarkBulkInsertion(data, o);
    const bulkLookupDuration = benchmarkBulkLookup(data, o);
    const bulkDeletionDuration = benchmarkBulkDeletion(data, o);
    o.destroy();

    o.map = new Kivi();

    const insertionDuration = benchmarkInsertion(data, o);
    const lookupDuration = benchmarkLookup(data, o);
    const deletionDuration = benchmarkDeletion(data, o);
    o.destroy();
    durationArr.push({
      iteration: i,
      insertionDuration,
      lookupDuration,
      deletionDuration,
      bulkInsertionDuration,
      bulkLookupDuration,
      bulkDeletionDuration,
    });
    if (average.insertionDuration === 0) {
      average = {
        insertionDuration,
        lookupDuration,
        deletionDuration,
        bulkInsertionDuration,
        bulkLookupDuration,
        bulkDeletionDuration,
      };
    } else {
      average = {
        insertionDuration: (average.insertionDuration + insertionDuration) / 2,
        bulkInsertionDuration:
          (average.bulkInsertionDuration + bulkInsertionDuration) / 2,
        lookupDuration: (average.lookupDuration + lookupDuration) / 2,
        bulkLookupDuration:
          (average.bulkLookupDuration + bulkLookupDuration) / 2,
        deletionDuration: (average.deletionDuration + deletionDuration) / 2,
        bulkDeletionDuration:
          (average.bulkDeletionDuration + bulkDeletionDuration) / 2,
      };
    }
  }
  logResults("Kivi", durationArr, average);
};

builtinMapBenchmark();
kiviBenchmark();

logRatio();
