  import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
  };

  type GroupStatus = "pending" | "active" | "completed" | string;

  type MembershipRow = {
    group_id: number;
    groups?: {
      id: number;
      name: string;
      group_status: GroupStatus;
    } | null;
  };

  type MembershipSummary = {
    groupId: number;
    name: string;
    status: GroupStatus;
  };

  Deno.serve(async (req: Request) => {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }

    try {
      console.log("delete-account invoked");

      const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
      const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
      const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
      const authHeader = req.headers.get("Authorization") ?? "";

      if (!supabaseUrl || !anonKey || !serviceRoleKey) {
        console.error("Missing built-in Supabase environment variables");
        return jsonResponse(
          { error: "Supabase environment variables are not configured." },
          500,
        );
      }

      const userClient = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: authHeader } },
      });

      const adminClient = createClient(supabaseUrl, serviceRoleKey);

      const {
        data: { user },
        error: userError,
      } = await userClient.auth.getUser();

      if (userError || !user) {
        console.error("Unauthorized delete-account call", userError);
        return jsonResponse({ error: "Unauthorized." }, 401);
      }

      const userId = user.id;
      const deletedLabel = "Deleted User";
      console.log("Deleting account for user:", userId);

      const { data: membershipRows, error: membershipError } = await adminClient
        .from("group_members")
        .select("group_id, groups!inner(id, name, group_status)")
        .eq("user_id", userId);

      if (membershipError) {
        console.error("Failed to inspect memberships", membershipError);
        return jsonResponse(
          {
            error: "Failed to inspect account group memberships.",
            details: membershipError.message,
          },
          500,
        );
      }

      const memberships: MembershipSummary[] = (
        (membershipRows ?? []) as MembershipRow[]
      ).map((row) => ({
        groupId: row.group_id,
        name: row.groups?.name ?? "",
        status: row.groups?.group_status ?? "",
      }));

      const activeGroups = memberships.filter(
        (g: MembershipSummary) => g.status === "active",
      );
      if (activeGroups.length > 0) {
        return jsonResponse(
          {
            error:
              "You cannot delete your account while you are in active groups.",
            active_groups: activeGroups.map((g: MembershipSummary) => g.name),
          },
          409,
        );
      }

      const pendingGroups = memberships.filter(
        (g: MembershipSummary) => g.status === "pending",
      );
      if (pendingGroups.length > 0) {
        return jsonResponse(
          {
            error:
              "You cannot delete your account while you are still in pending groups.",
            pending_groups: pendingGroups.map((g: MembershipSummary) => g.name),
          },
          409,
        );
      }

      const completedGroupIds = memberships
        .filter((g: MembershipSummary) => g.status === "completed")
        .map((g: MembershipSummary) => g.groupId);

      console.log("Membership status summary", {
        active: activeGroups.length,
        pending: pendingGroups.length,
        completed: completedGroupIds.length,
      });

      const tombstoneEmail = `deleted+${userId}@example.com`;
      const randomPassword = `${crypto.randomUUID()}Aa1!`;

      // Step 1: release auth identity first
      const { error: authUpdateError } = await adminClient.auth.admin
        .updateUserById(userId, {
          email: tombstoneEmail,
          password: randomPassword,
          user_metadata: {
            full_name: deletedLabel,
            deleted: true,
          },
          ban_duration: "876000h",
        });

      if (authUpdateError) {
        console.error("Failed to update auth user", authUpdateError);
        return jsonResponse(
          {
            error: "Failed to release account email in auth.",
            details: authUpdateError.message,
          },
          500,
        );
      }

      // Step 2: anonymize completed-group history
      if (completedGroupIds.length > 0) {
        const { error: memberUpdateError } = await adminClient
          .from("group_members")
          .update({ user_name: deletedLabel })
          .eq("user_id", userId)
          .in("group_id", completedGroupIds);

        if (memberUpdateError) {
          return jsonResponse(
            {
              error:
                "Auth was released, but completed group member history update failed.",
              details: memberUpdateError.message,
            },
            500,
          );
        }

        const { error: chatUpdateError } = await adminClient
          .from("group_chat")
          .update({ user_name: deletedLabel, user_id: null })
          .eq("user_id", userId)
          .in("group_id", completedGroupIds);

        if (chatUpdateError) {
          return jsonResponse(
            {
              error:
                "Auth was released, but completed group chat update failed.",
              details: chatUpdateError.message,
            },
            500,
          );
        }

        const { error: senderProofError } = await adminClient
          .from("payment_proofs")
          .update({ sender_name: deletedLabel, sender_id: null })
          .eq("sender_id", userId)
          .in("group_id", completedGroupIds);

        if (senderProofError) {
          return jsonResponse(
            {
              error:
                "Auth was released, but payment proof sender history update failed.",
              details: senderProofError.message,
            },
            500,
          );
        }

        const { error: recipientProofError } = await adminClient
          .from("payment_proofs")
          .update({ recipient_name: deletedLabel, recipient_id: null })
          .eq("recipient_id", userId)
          .in("group_id", completedGroupIds);

        if (recipientProofError) {
          return jsonResponse(
            {
              error:
                "Auth was released, but payment proof recipient history update failed.",
              details: recipientProofError.message,
            },
            500,
          );
        }

        const { error: verifiedByError } = await adminClient
          .from("payment_proofs")
          .update({ verified_by_id: null })
          .eq("verified_by_id", userId)
          .in("group_id", completedGroupIds);

        if (verifiedByError) {
          return jsonResponse(
            {
              error:
                "Auth was released, but payment verification history update failed.",
              details: verifiedByError.message,
            },
            500,
          );
        }

        const { error: rotationError } = await adminClient
          .from("round_rotations")
          .update({ recipient_name: deletedLabel, recipient_id: null })
          .eq("recipient_id", userId)
          .in("group_id", completedGroupIds);

        if (rotationError) {
          return jsonResponse(
            {
              error:
                "Auth was released, but round recipient history update failed.",
              details: rotationError.message,
            },
            500,
          );
        }

        const { error: transactionError } = await adminClient
          .from("transactions")
          .update({ user_id: null })
          .eq("user_id", userId)
          .in("group_id", completedGroupIds);

        if (transactionError) {
          return jsonResponse(
            {
              error:
                "Auth was released, but transaction history update failed.",
              details: transactionError.message,
            },
            500,
          );
        }

        const { error: notificationError } = await adminClient
          .from("notifications")
          .update({ actor_user_id: null })
          .eq("actor_user_id", userId);

        if (notificationError) {
          return jsonResponse(
            {
              error:
                "Auth was released, but notification actor history update failed.",
              details: notificationError.message,
            },
            500,
          );
        }
      }

      // Step 3: anonymize profile last
      const { error: profileError } = await adminClient
        .from("profiles")
        .update({
          full_name: deletedLabel,
          address: null,
          age: null,
          email: tombstoneEmail,
          gcash_name: null,
          gcash_number: null,
          profile_picture: null,
          urcode_path: null,
          id_front_path: null,
          id_back_path: null,
          is_deleted: true,
          deleted_at: new Date().toISOString(),
        })
        .eq("id", userId);

      if (profileError) {
        console.error("Failed to anonymize profile", profileError);
        return jsonResponse(
          {
            error: "Auth was released, but profile anonymization failed.",
            details: profileError.message,
          },
          500,
        );
      }

      console.log("delete-account completed for user:", userId);
      return jsonResponse(
        {
          success: true,
          deleted_label: deletedLabel,
          completed_groups_preserved: completedGroupIds.length,
        },
        200,
      );
    } catch (error) {
      console.error("Unexpected delete-account failure", error);
      return jsonResponse(
        {
          error: "Unexpected delete-account failure.",
          details: error instanceof Error ? error.message : String(error),
        },
        500,
      );
    }
  });

  function jsonResponse(body: unknown, status: number) {
    return new Response(JSON.stringify(body), {
      status,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    });
  }