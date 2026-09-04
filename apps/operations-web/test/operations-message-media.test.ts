import assert from "node:assert/strict";
import test from "node:test";
import { classifyMessageFile, formatAttachmentSize, validateMessageFile } from "../src/operations-message-media";

test("message media classifies photos separately from ordinary files", () => {
  assert.equal(classifyMessageFile({ type: "image/jpeg" } as File), "image");
  assert.equal(classifyMessageFile({ type: "application/pdf" } as File), "file");
  assert.equal(classifyMessageFile({ type: "image/gif" } as File), "file");
});

test("message media rejects empty and oversized files", () => {
  assert.match(validateMessageFile({ size: 0 } as File) ?? "", /empty/);
  assert.match(validateMessageFile({ size: 15 * 1024 * 1024 + 1 } as File) ?? "", /15 MB/);
  assert.equal(validateMessageFile({ size: 1024 } as File), null);
});

test("message attachment sizes use readable labels", () => {
  assert.equal(formatAttachmentSize(1024), "1 KB");
  assert.equal(formatAttachmentSize(1572864), "1.5 MB");
});
