export type RouteCoordinate = { latitude: number; longitude: number };

export type RoutingRequest = {
  coordinates: RouteCoordinate[];
  departureAt?: string;
};

export type RoutingResult = {
  provider: "mapbox";
  profile: "driving-traffic";
  distanceMeters: number;
  durationSeconds: number;
  typicalDurationSeconds?: number;
  legs: Array<{ distanceMeters: number; durationSeconds: number }>;
  geometry: { type: "LineString"; coordinates: [number, number][] };
};

export interface RoutingProvider {
  calculate(request: RoutingRequest): Promise<RoutingResult>;
}

export class RoutingProviderError extends Error {
  constructor(message: string, readonly status?: number) {
    super(message);
  }
}

function mapboxDepartureAt(value: string): string {
  const parsed = new Date(value);
  if (!Number.isFinite(parsed.getTime())) {
    throw new RoutingProviderError("Routing departure time must be an ISO date-time");
  }
  // Mapbox's depart_at parser accepts RFC 3339 seconds, but rejects the
  // fractional seconds emitted by Date#toISOString in live requests.
  return parsed.toISOString().replace(/\.\d{3}Z$/, "Z");
}

type MapboxDirectionsBody = {
  code?: string;
  message?: string;
  routes?: Array<{
    distance?: number;
    duration?: number;
    duration_typical?: number;
    legs?: Array<{ distance?: number; duration?: number }>;
    geometry?: { type?: string; coordinates?: unknown };
  }>;
};

export class MapboxRoutingProvider implements RoutingProvider {
  constructor(
    private readonly accessToken: string,
    private readonly fetcher: typeof fetch = fetch,
    private readonly timeoutMs = 8_000,
  ) {}

  async calculate(request: RoutingRequest): Promise<RoutingResult> {
    if (request.coordinates.length < 2 || request.coordinates.length > 25) {
      throw new RoutingProviderError("Routing requires between 2 and 25 coordinates");
    }
    const coordinatePath = request.coordinates
      .map(({ longitude, latitude }) => `${longitude},${latitude}`)
      .join(";");
    const query = new URLSearchParams({
      access_token: this.accessToken,
      alternatives: "false",
      geometries: "geojson",
      overview: "simplified",
      steps: "false",
    });
    if (request.departureAt) query.set("depart_at", mapboxDepartureAt(request.departureAt));
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), this.timeoutMs);
    let response: Response;
    try {
      response = await this.fetcher(
        `https://api.mapbox.com/directions/v5/mapbox/driving-traffic/${coordinatePath}?${query}`,
        { signal: controller.signal, headers: { accept: "application/json" } },
      );
    } catch (error) {
      throw new RoutingProviderError(error instanceof Error && error.name === "AbortError"
        ? "Routing provider timed out"
        : "Routing provider could not be reached");
    } finally {
      clearTimeout(timeout);
    }
    const body = await response.json().catch(() => ({})) as MapboxDirectionsBody;
    if (!response.ok || body.code !== "Ok") {
      throw new RoutingProviderError(body.message || `Routing provider returned HTTP ${response.status}`, response.status);
    }
    const route = body.routes?.[0];
    const geometry = route?.geometry;
    const coordinates = geometry?.coordinates;
    if (!route || !Number.isFinite(route.distance) || !Number.isFinite(route.duration)
      || geometry?.type !== "LineString" || !Array.isArray(coordinates)
      || !Array.isArray(route.legs) || route.legs.length !== request.coordinates.length - 1) {
      throw new RoutingProviderError("Routing provider returned an incomplete route");
    }
    const normalizedCoordinates = coordinates.flatMap((coordinate): [number, number][] =>
      Array.isArray(coordinate) && coordinate.length >= 2
        && Number.isFinite(Number(coordinate[0])) && Number.isFinite(Number(coordinate[1]))
        ? [[Number(coordinate[0]), Number(coordinate[1])]] : []);
    if (normalizedCoordinates.length < 2) throw new RoutingProviderError("Routing provider returned invalid geometry");
    return {
      provider: "mapbox",
      profile: "driving-traffic",
      distanceMeters: Number(route.distance),
      durationSeconds: Number(route.duration),
      ...(Number.isFinite(route.duration_typical) ? { typicalDurationSeconds: Number(route.duration_typical) } : {}),
      legs: route.legs.map((leg) => ({
        distanceMeters: Number(leg.distance ?? 0),
        durationSeconds: Number(leg.duration ?? 0),
      })),
      geometry: { type: "LineString", coordinates: normalizedCoordinates },
    };
  }
}
