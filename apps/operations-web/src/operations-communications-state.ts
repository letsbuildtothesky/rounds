import type {
  CommunicationThreadReadState,
  OperationsCommunicationsProjection,
} from "@rounds/contracts";

export type RoundCommunicationUnreadState = {
  count: number;
  hasVoice: boolean;
  threadId: string;
};

export function applyCommunicationReadState(
  projection: OperationsCommunicationsProjection,
  state: CommunicationThreadReadState,
): OperationsCommunicationsProjection {
  const threads = projection.threads.map((thread) => thread.id !== state.threadId ? thread : {
    ...thread,
    unreadCount: state.unreadCount,
    firstUnreadMessageId: state.firstUnreadMessageId,
    hasUnreadVoice: state.hasUnreadVoice,
    lastReadMessageId: state.lastReadMessageId,
  });
  return {
    ...projection,
    totalUnreadCount: threads.reduce((total, thread) => total + thread.unreadCount, 0),
    threads,
  };
}

export function communicationUnreadByRound(
  projection: OperationsCommunicationsProjection | null,
): Record<string, RoundCommunicationUnreadState> {
  if (!projection) return {};
  return projection.threads.reduce<Record<string, RoundCommunicationUnreadState>>((byRound, thread) => {
    if (!thread.unreadCount) return byRound;
    const current = byRound[thread.roundId];
    byRound[thread.roundId] = {
      count: (current?.count ?? 0) + thread.unreadCount,
      hasVoice: Boolean(current?.hasVoice || thread.hasUnreadVoice),
      threadId: current?.threadId ?? thread.id,
    };
    return byRound;
  }, {});
}
