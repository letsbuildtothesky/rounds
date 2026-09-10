import { createHash } from 'node:crypto';
import sharp from 'sharp';
import { CommandRejection } from './transaction-runner.js';
import { podMaxBytes } from './pickup-validation.js';
/** No URL or metadata from the phone is fetched. Storage supplies a bounded
 * stream for the server-owned key; full decoding is separate from hash checks.
 * Raster validation is NOT a malware scan or a claim about what is depicted. */
export async function readPodBytes(stream: AsyncIterable<Uint8Array>, expectedSize: number): Promise<Buffer> {
    if (!Number.isSafeInteger(expectedSize) || expectedSize < 1 || expectedSize > podMaxBytes)
        throw new CommandRejection('ASSET_NOT_VERIFIED');
    const parts: Buffer[] = [];
    let count = 0;
    for await (const chunk of stream) {
        count += chunk.byteLength;
        if (count > expectedSize)
            throw new CommandRejection('ASSET_NOT_VERIFIED');
        parts.push(Buffer.from(chunk));
    }
    if (count !== expectedSize)
        throw new CommandRejection('ASSET_NOT_VERIFIED');
    return Buffer.concat(parts);
}
export const podHash = (bytes: Uint8Array): string => createHash('sha256').update(bytes).digest('hex');
export async function verifyPodImage(bytes: Buffer, mime: string, expectedHash: string): Promise<void> {
    if (podHash(bytes) !== expectedHash)
        throw new CommandRejection('ASSET_NOT_VERIFIED');
    try {
        const image = sharp(bytes, { failOn: 'warning', limitInputPixels: 16000000, sequentialRead: true });
        const metadata = await image.metadata();
        if ((mime === 'image/jpeg' ? metadata.format !== 'jpeg' : mime !== 'image/png' || metadata.format !== 'png') ||
            (metadata.pages ?? 1) !== 1)
            throw new Error('Unsupported raster');
        // metadata() alone accepts truncated images. Decode every pixel with bounds.
        await image.timeout({ seconds: 5 }).raw().toBuffer();
    }
    catch {
        throw new CommandRejection('ASSET_NOT_VERIFIED');
    }
}
