interface KiviConfig {
    forceUseRuntimeFFI: ?boolean,
}

export class Kivi {
    constructor(config?: KiviConfig);
    destroy(): void;

    del(key: string): string | null;
    get(key: string): string | null;
    set(key: string, value: string): string;
}