# Contributing to Kivi

> **Important:** All implementations need test coverage. If you are adding a new feature, please add a test.

## Kivi's codebase

The core is mostly written in Zig, though we have tests written in C in order to ensure our correct ABI implementation.
Drivers mostly contain the language they're being written for, though if we need any kind of C/Cpp development for the drivers they'll be using the Zig toolchain for compilation and more on.
The server and Client used for the network implementation are mostly written in Zig but they may use libraries written in other languages like C.

## Contributing to the core
Check out the [core's readme](https://github.com/devraymondsh/kivi/tree/main/core/readme.md) for instructions.

## Contributing to language drivers
Check out the readme of the corresponding language or ask us to create one by creating an issue if you're writing a whole new driver for a language.
