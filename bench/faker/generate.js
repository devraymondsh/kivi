import fs from "node:fs";
import path from "path";
import json from "big-json";
import { fileURLToPath } from "url";
import { faker } from "@faker-js/faker";

const count = 1_000_000;

export const generateFakeData = () =>
  new Promise((resolve) => {
    console.log("Generating fake data for the benchmark...");

    const arr = [];
    for (let i = 0; i < count; i++) {
      arr.push({
        key: faker.string.uuid() + "_" + faker.person.fullName(),
        value: JSON.stringify({
          bio: faker.person.bio(),
          gender: faker.person.gender(),
          jobArea: faker.person.jobArea(),
          jobTitle: faker.person.jobTitle(),
          jobType: faker.person.jobType(),
          name: faker.person.fullName(),
        }),
      });
      if (i % (count / 10) == 0 && i != 0) {
        console.log((i / count) * 100 + "%");
      }
    }

    const dataJsonPath = path.resolve(
      path.dirname(fileURLToPath(import.meta.url)),
      "data/data.json"
    );
    console.log("Writing the data. Please be patient.");
    const writeStream = fs.createWriteStream(dataJsonPath);
    const stringifyStream = json.createStringifyStream({
      body: arr,
    });
    const pipe = stringifyStream.pipe(writeStream);
    pipe.on("finish", () => resolve());
  });
