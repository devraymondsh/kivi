export class Collection {
    constructor();
    destroy(): void;

    rm(key: string): string | null;
    get(key: string): string | null;
    set(key: string, value: string): void;
};