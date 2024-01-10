import { Kivi } from "../src/drivers/js/index.js";
import { isBun, isDeno } from "../src/drivers/js/runtime.js";
import { generateFakeData } from "./faker/generate.js";
import { Buffer } from "node:buffer";

const repeatBenchmark = 2;
const data = generateFakeData();

const assert = (name, left, right) => {
  if (
    Buffer.from(left, "utf8").subarray(0, right.length).toString() !==
    right.toString()
  ) {
    throw new Error(
      `Assertion '${name}' failed! Left was '${left.toString()}' and right was '${right.toString()}'.`
    );
  }
};
const roundToTwoDecimal = (num) => +(Math.round(num + "e+2") + "e-2");

const benchmarkDeletion = (data, o, keyidx) => {
  const startingTime = performance.now();
  for (const item of data) {
    assert(`${o.name} deletion`, o.del(item[keyidx]), item.value);
  }
  return performance.now() - startingTime;
};
const benchmarkLookup = (data, o, keyidx) => {
  const startingTime = performance.now();
  for (const item of data) {
    assert(`${o.name} lookup`, o.get(item[keyidx]), item.value);
  }
  return performance.now() - startingTime;
};
const benchmarkInsertion = (data, o, keyidx) => {
  const startingTime = performance.now();
  for (const item of data) {
    o.set(item[keyidx], item.value);
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
const logRatio = (index1, index2) => {
  console.log(
    `\n This table shows how much ${averageLogResult[index1].name} is faster than ${averageLogResult[index2].name}:`
  );

  console.table({
    lookup:
      roundToTwoDecimal(
        averageLogResult[index2].totalLookupTime /
          averageLogResult[index1].totalLookupTime
      ) + "x",
    insertion:
      roundToTwoDecimal(
        averageLogResult[index2].totalInsertionTime /
          averageLogResult[index1].totalInsertionTime
      ) + "x",
    deletion:
      roundToTwoDecimal(
        averageLogResult[index2].totalDeletionTime /
          averageLogResult[index1].totalDeletionTime
      ) + "x",
  });
};

const builtinMapBenchmark = () => {
  const name = "JsMap";
  const durationArr = [];
  let average = {
    insertionDuration: 0,
    lookupDuration: 0,
    deletionDuration: 0,
  };
  for (let i = 0; i < repeatBenchmark; i++) {
    let o = {
      name,
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
    const insertionDuration = benchmarkInsertion(data, o, "key");
    const lookupDuration = benchmarkLookup(data, o, "key");
    const deletionDuration = benchmarkDeletion(data, o, "key");
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
  logResults(name, durationArr, average);
};
const kiviBenchmark = (config) => {
  const name = "Kivi " + (config.forceUseRuntimeFFI ? "FFI" : "Napi");
  const durationArr = [];
  let average = {
    insertionDuration: 0,
    lookupDuration: 0,
    deletionDuration: 0,
  };
  for (let i = 0; i < repeatBenchmark; i++) {
    let o = {
      name,
      map: new Kivi(config),
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
    const insertionDuration = benchmarkInsertion(data, o, "kyb");
    const lookupDuration = benchmarkLookup(data, o, "kyb");
    const deletionDuration = benchmarkDeletion(data, o, "kyb");
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
  logResults(name, durationArr, average);
};

builtinMapBenchmark();

kiviBenchmark({ forceUseRuntimeFFI: false });
if (isDeno() || isBun()) {
  kiviBenchmark({ forceUseRuntimeFFI: true });
  logRatio(0, 1);
  logRatio(0, 2);
} else {
  logRatio(0, 1);
}
