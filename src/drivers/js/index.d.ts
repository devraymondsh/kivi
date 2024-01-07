interface KiviConfig {
    forceUseRuntimeFFI: boolean | undefined,
}

export class Kivi {
    constructor(config?: KiviConfig);
    destroy(): void;

    del(key: string): boolean;
    bulkDel(keys: string[]): boolean[];
    fetchDel(key: string): string | null;
    bulkFetchDel(keys: string[]): (string | null)[];
    get(key: string): string | null;
    bulkGet(keys: string[]): (string | null)[];
    set(key: string, value: string): boolean;
    bulkSet(keys: string[], values: string[]): boolean[];
}