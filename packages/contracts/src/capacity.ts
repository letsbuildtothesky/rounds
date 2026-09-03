export type CargoRequirement = {
  cargoClassCode: string;
  displayName: string;
  quantity: number;
  classificationStatus: "classified" | "unclassified";
};

export type VehicleCargoLimit = {
  cargoClassCode: string;
  displayName: string;
  allowed: boolean;
  maxQuantity?: number;
};

export type CapacityDimensionResult = {
  kind: "stops" | "cargo";
  code: string;
  displayName: string;
  used: number;
  limit?: number;
  remaining?: number;
  utilizationPercent?: number;
  status: "fits" | "blocked" | "review_required";
};

export type CapacityEvaluation = {
  status: "fits" | "blocked" | "review_required";
  dimensions: CapacityDimensionResult[];
  constrainingDimension?: {
    kind: "stops" | "cargo";
    code: string;
  };
  reasons: string[];
  warnings: string[];
};
