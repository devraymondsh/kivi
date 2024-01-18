interface KiviConfig { }

export class KiviRuntime {
    constructor(config?: KiviConfig);
    destroy(): void;
    rm(key: Buffer): Buffer;
    del(key: Buffer): Buffer | null;
    get(key: Buffer): Buffer | null;
    set(key: Buffer, value: Buffer): boolean;
}

export class Kivi extends KiviRuntime { }
export class NodeKivi extends KiviRuntime { }
export class DenoKivi extends KiviRuntime { }
export class BunKivi extends KiviRuntime { }