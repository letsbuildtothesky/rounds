import { createHash } from "node:crypto";

/** Canonical JSON for a validated command, not a permissive JSON converter.
 * Sorted UTF-16 object keys; array order and Unicode normalization preserved;
 * ECMAScript finite-number encoding (-0 becomes 0). Reject lossy inputs.
 */
export function canonicalCommandJson(value: unknown): string {
  const ancestors = new Set<object>();
  function encode(v: unknown, depth: number): string {
    if (depth > 64) throw new TypeError("Command nesting exceeds limit");
    if (v === null) return "null";
    if (typeof v === "boolean") return String(v);
    if (typeof v === "number") {
      if (!Number.isFinite(v)) throw new TypeError("Nonfinite JSON number");
      return JSON.stringify(v);
    }
    if (typeof v === "string") {
      for (const point of v) {
        const n = point.codePointAt(0)!;
        if (n >= 0xd800 && n <= 0xdfff) throw new TypeError("Unpaired Unicode surrogate");
      }
      return JSON.stringify(v);
    }
    if (typeof v !== "object" || ancestors.has(v)) throw new TypeError("Invalid/cyclic JSON value");
    ancestors.add(v);
    let result: string;
    if (Array.isArray(v)) {
      const fields = Object.getOwnPropertyDescriptors(v);
      if (Reflect.ownKeys(v).length !== v.length + 1) throw new TypeError("Sparse/extended array");
      result = `[${Array.from({ length: v.length }, (_, i) => {
        const field = fields[String(i)];
        if (!field || !field.enumerable || !('value' in field)) throw new TypeError("Non-data array item");
        return encode(field.value, depth + 1);
      }).join(",")}]`;
    } else {
      if (Object.getPrototypeOf(v) !== Object.prototype && Object.getPrototypeOf(v) !== null) throw new TypeError("Non-JSON object");
      if (Object.getOwnPropertySymbols(v).length) throw new TypeError("Symbol JSON property");
      const fields = Object.getOwnPropertyDescriptors(v);
      result = `{${Object.keys(fields).sort().map((key) => {
        const descriptor = fields[key]!;
        if (!descriptor.enumerable || !('value' in descriptor)) throw new TypeError("Non-data JSON property");
        return `${encode(key, depth + 1)}:${encode(descriptor.value, depth + 1)}`;
      }).join(",")}}`;
    }
    ancestors.delete(v);
    return result;
  }
  const text = encode(value, 0);
  if (Buffer.byteLength(text, "utf8") > 1_048_576) throw new TypeError("Command exceeds byte limit");
  return text;
}

export function commandRequestHash(commandType: string, request: unknown): string {
  return createHash("sha256").update(canonicalCommandJson({ protocol: "rounds-v23-r1", command_type: commandType, request }), "utf8").digest("hex");
}
