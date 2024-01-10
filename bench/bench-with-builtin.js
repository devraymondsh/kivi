import { Kivi } from "../src/drivers/js/index.js";
import { generateFakeData } from "./faker/generate.js";

const repeatBenchmark = 2;
const data = generateFakeData();

const assert = (name, left, right) => {
  if (!left.equals(right)) {
    throw new Error(
      `Assertion '${name}' failed! Left was '${left.toString()}' and right was '${right.toString()}'.`
    );
  }
};
const roundToTwoDecimal = (num) => +(Math.round(num + "e+2") + "e-2");

const benchmarkRemove = (data, o, keyidx) => {
  const startingTime = performance.now();
  for (const item of data) {
    o.rm(item[keyidx]);
  }
  return performance.now() - startingTime;
};
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
    totalRemoveTime: roundToTwoDecimal(value.totalRemoveTime) + " ms",
  };
};
const formatLogResult = (value) => {
  return {
    totalLookupTime: value.lookupDuration,
    totalInsertionTime: value.insertionDuration,
    totalDeletionTime: value.deletionDuration,
    totalRemoveTime: value.removeDuration,
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
    totalRemoveTime: average.totalRemoveTime,
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
    remove:
      roundToTwoDecimal(
        averageLogResult[1].totalRemoveTime /
          averageLogResult[0].totalRemoveTime
      ) + "x",
  });
};

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
      set: function (k, v) {
        return this.map.set(k, v);
      },
      rm: function (k) {
        this.map.delete(k);
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
    const removeDuration = benchmarkRemove(data, o, "key");
    o.destroy();
    durationArr.push({
      iteration: i,
      insertionDuration,
      lookupDuration,
      deletionDuration,
      removeDuration,
    });
    if (average.insertionDuration === 0) {
      average = {
        insertionDuration,
        lookupDuration,
        deletionDuration,
        removeDuration,
      };
    } else {
      average = {
        insertionDuration: (average.insertionDuration + insertionDuration) / 2,
        lookupDuration: (average.lookupDuration + lookupDuration) / 2,
        deletionDuration: (average.deletionDuration + deletionDuration) / 2,
        removeDuration: (average.removeDuration + removeDuration) / 2,
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
      rm: function (k) {
        this.map.rm(k);
      },
      destroy: function () {
        return this.map.destroy();
      },
    };
    const insertionDuration = benchmarkInsertion(data, o, "kyb");
    const lookupDuration = benchmarkLookup(data, o, "kyb");
    const deletionDuration = benchmarkDeletion(data, o, "kyb");
    const removeDuration = benchmarkRemove(data, o, "kyb");
    o.destroy();
    durationArr.push({
      iteration: i,
      insertionDuration,
      lookupDuration,
      deletionDuration,
      removeDuration,
    });
    if (average.insertionDuration === 0) {
      average = {
        insertionDuration,
        lookupDuration,
        deletionDuration,
        removeDuration,
      };
    } else {
      average = {
        insertionDuration: (average.insertionDuration + insertionDuration) / 2,
        lookupDuration: (average.lookupDuration + lookupDuration) / 2,
        deletionDuration: (average.deletionDuration + deletionDuration) / 2,
        removeDuration: (average.removeDuration + removeDuration) / 2,
      };
    }
  }
  logResults("Kivi", durationArr, average);
};

builtinMapBenchmark();
kiviBenchmark();

logRatio();
