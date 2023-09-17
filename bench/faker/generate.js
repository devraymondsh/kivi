import fs from "node:fs";
import json from "big-json";
import { faker } from "@faker-js/faker";

const count = 2_000_000;

const arr = [];
for (let i = 0; i <= count; i++) {
  arr.push({
    key: faker.word.words({ min: 10 }).split(" ").join("_"),
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

console.log("Writing the data. Please be patient.");
const writeStream = fs.createWriteStream("./data/data.json");
const stringifyStream = json.createStringifyStream({
  body: arr,
});
stringifyStream.pipe(writeStream);
