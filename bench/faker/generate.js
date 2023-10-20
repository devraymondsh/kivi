import fs from "node:fs";
import path from "path";
import json from "big-json";
import { fileURLToPath } from "url";
import { faker } from "@faker-js/faker";

const count = 2_000_000;

const arr = [];
for (let i = 0; i <= count; i++) {
  arr.push({
    key: faker.string.uuid(),
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
stringifyStream.pipe(writeStream);
