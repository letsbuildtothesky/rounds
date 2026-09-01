export type IngestDecision = {
  acceptedSequences: number[];
  duplicateSequences: number[];
  highestContiguousSequence: number;
};

export class SequenceWatermark {
  readonly #pending = new Set<number>();
  #highestContiguousSequence: number;

  constructor(initialWatermark = 0) {
    this.#highestContiguousSequence = initialWatermark;
  }

  get value(): number {
    return this.#highestContiguousSequence;
  }

  ingest(sequences: readonly number[]): IngestDecision {
    const acceptedSequences: number[] = [];
    const duplicateSequences: number[] = [];

    for (const sequence of sequences) {
      if (sequence <= this.#highestContiguousSequence || this.#pending.has(sequence)) {
        duplicateSequences.push(sequence);
      } else {
        this.#pending.add(sequence);
        acceptedSequences.push(sequence);
      }
    }

    while (this.#pending.delete(this.#highestContiguousSequence + 1)) {
      this.#highestContiguousSequence += 1;
    }

    return {
      acceptedSequences,
      duplicateSequences,
      highestContiguousSequence: this.#highestContiguousSequence,
    };
  }
}

