function partsAt(value: Date, timezone: string) {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: timezone,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    hourCycle: "h23",
  }).formatToParts(value);
  const number = (type: Intl.DateTimeFormatPartTypes) => Number(parts.find((part) => part.type === type)?.value);
  return { year: number("year"), month: number("month"), day: number("day"), hour: number("hour"), minute: number("minute"), second: number("second") };
}

export function tenantLocalDateTimeInput(value: string, timezone: string): string {
  const part = partsAt(new Date(value), timezone);
  return `${String(part.year).padStart(4, "0")}-${String(part.month).padStart(2, "0")}-${String(part.day).padStart(2, "0")}T${String(part.hour).padStart(2, "0")}:${String(part.minute).padStart(2, "0")}`;
}

export function tenantLocalDateTimeToIso(value: string, timezone: string): string {
  const match = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})$/.exec(value);
  if (!match) throw new Error("Enter a valid local date and time.");
  const target = Date.UTC(Number(match[1]), Number(match[2]) - 1, Number(match[3]), Number(match[4]), Number(match[5]), 0, 0);
  let instant = target;
  for (let attempt = 0; attempt < 2; attempt += 1) {
    const observed = partsAt(new Date(instant), timezone);
    const observedAsUtc = Date.UTC(observed.year, observed.month - 1, observed.day, observed.hour, observed.minute, observed.second, 0);
    instant -= observedAsUtc - target;
  }
  const result = new Date(instant);
  const roundTrip = tenantLocalDateTimeInput(result.toISOString(), timezone);
  if (roundTrip !== value) throw new Error("That local time does not exist in the selected timezone.");
  return result.toISOString();
}
