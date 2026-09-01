import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { CreateDeliveryCommand, CreateDeliveryResult } from "@rounds/contracts";
import type {
  ActorContext,
  DeliveryCommandGateway,
  IdentityGateway,
  OperationsRole,
} from "./types.js";

type MembershipRow = {
  person_id: string;
  role: OperationsRole;
};

export class SupabaseGateway implements IdentityGateway, DeliveryCommandGateway {
  private readonly admin: SupabaseClient;

  constructor(
    private readonly url: string,
    private readonly publishableKey: string,
    secretKey: string,
  ) {
    this.admin = createClient(url, secretKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
  }

  async authenticate(accessToken: string): Promise<{ authUserId: string } | null> {
    const client = createClient(this.url, this.publishableKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data, error } = await client.auth.getUser(accessToken);
    if (error || !data.user) return null;
    return { authUserId: data.user.id };
  }

  async authorizeTenant(authUserId: string, tenantId: string): Promise<ActorContext | null> {
    const { data: identity, error: identityError } = await this.admin
      .from("auth_identities")
      .select("person_id")
      .eq("auth_user_id", authUserId)
      .maybeSingle<{ person_id: string }>();
    if (identityError) throw identityError;
    if (!identity) return null;

    const { data: membership, error: membershipError } = await this.admin
      .from("tenant_memberships")
      .select("person_id, role")
      .eq("tenant_id", tenantId)
      .eq("person_id", identity.person_id)
      .eq("status", "active")
      .in("role", ["tenant_owner", "operations_admin", "dispatcher", "viewer"])
      .order("role")
      .limit(1)
      .maybeSingle<MembershipRow>();
    if (membershipError) throw membershipError;
    if (!membership) return null;
    return {
      authUserId,
      personId: membership.person_id,
      tenantId,
      role: membership.role,
    };
  }

  async createDelivery(
    command: CreateDeliveryCommand,
    actor: ActorContext,
  ): Promise<CreateDeliveryResult> {
    const { data, error } = await this.admin.rpc("create_delivery_command", {
      p_command: command,
      p_actor_person_id: actor.personId,
    });
    if (error) throw error;
    return data as CreateDeliveryResult;
  }

  async ready(): Promise<boolean> {
    const { error } = await this.admin.from("tenants").select("id", { head: true, count: "exact" }).limit(1);
    return !error;
  }
}
