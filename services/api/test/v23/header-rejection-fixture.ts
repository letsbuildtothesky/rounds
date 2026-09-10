import { request } from 'node:http';

/** Observe a real header-based admission rejection BEFORE sending a body.
 * fetch may report ECONNRESET while still writing a large refused body after
 * the server's deliberate Connection: close. That race isn't a missing 403.
 * This fixture requires an actual complete HTTP response, never treats a
 * network error as success, and fails if the server waits for/accepts the body.
 */
export function headerRejection(url: string, options: {method: string; headers: Record<string, string>}): Promise<Response> {
  const target = new URL(url);
  if (target.protocol !== 'http:' || target.hostname !== '127.0.0.1') throw new Error('Loopback fixture only');
  return new Promise((resolve, reject) => {
    const req = request(target, {...options, agent: false}, res => {
      const chunks: Buffer[] = []; let size = 0;
      res.on('data', (chunk: Buffer) => {
        size += chunk.length;
        if (size > 65536) req.destroy(new Error('Oversized fixture response'));
        else chunks.push(chunk);
      });
      res.once('error', reject);
      res.once('aborted', () => reject(new Error('Incomplete fixture response')));
      res.once('end', () => {
        const headers = new Headers();
        for (let i = 0; i < res.rawHeaders.length; i += 2) headers.append(res.rawHeaders[i]!, res.rawHeaders[i + 1]!);
        resolve(new Response(new Uint8Array(Buffer.concat(chunks)), {status: res.statusCode!, headers}));
        req.destroy();
      });
    });
    req.once('error', reject);
    req.setTimeout(5000, () => req.destroy(new Error('Header rejection waited for body')));
    req.flushHeaders();
  });
}
