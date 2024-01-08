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
    assert(
      `${o.name} deletion`,
      o.del(Buffer.from(item.key, "utf8")).toString(),
      Buffer.from(item.value, "utf8").toString()
    );
  }
  return performance.now() - startingTime;
};
const benchmarkLookup = (data, o) => {
  const startingTime = performance.now();
  for (const item of data) {
    assert(
      `${o.name} lookup`,
      o.get(Buffer.from(item.key, "utf8")).toString(),
      Buffer.from(item.value, "utf8").toString()
    );
  }
  return performance.now() - startingTime;
};
const benchmarkInsertion = (data, o) => {
  const startingTime = performance.now();
  for (const item of data) {
    o.set(Buffer.from(item.key, "utf8"), Buffer.from(item.value, "utf8"));
  }
  return performance.now() - startingTime;
};

let averageLogResult = [];
const wrapInHumanReadable = (value) => {
  return {
    totalLookupTime: roundToTwoDecimal(value.totalLookupTime) + " ms",
    totalInsertionTime: roundToTwoDecimal(value.totalInsertionTime) + " ms",
    totalDeletionTime: roundToTwoDecimal(value.totalDeletionTime) + " ms",
  };
};
const formatLogResult = (value) => {
  return {
    totalLookupTime: value.lookupDuration,
    totalInsertionTime: value.insertionDuration,
    totalDeletionTime: value.deletionDuration,
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
        return this.map.get(k.toString());
      },
      set: function (k, v) {
        return this.map.set(k.toString(), v);
      },
      del: function (k) {
        const v = this.map.get(k.toString());
        this.map.delete(k.toString());
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
    let o = {
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
