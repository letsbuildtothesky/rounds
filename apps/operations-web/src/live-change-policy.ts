export type LiveChangePinChoice = {
  originalAddress: string;
  draftAddress: string;
  keepCurrentPin: boolean;
  pinSelectionMade: boolean;
};

export function liveChangePinError(choice: LiveChangePinChoice): string | undefined {
  const addressChanged = choice.draftAddress.trim() !== choice.originalAddress;
  if (addressChanged && !choice.keepCurrentPin && !choice.pinSelectionMade) {
    return "Set the new physical pin on the map, or explicitly keep the current pin";
  }
  return undefined;
}
