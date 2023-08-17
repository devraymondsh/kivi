export class Kivi {
    constructor();
    destroy(): void;

    del(key: string): string | null;
    get(key: string): string | null;
    set(key: string, value: string): string;
}