// @ts-nocheck
import { serve } from "https://deno.land/std@0.201.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.45.2";

const validRoles = new Set(["admin", "collector"]);
const validStatuses = new Set(["active", "inactive"]);

const wait = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms));

serve(async (req) => {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceKey = Deno.env.get("SERVICE_ROLE_KEY");
  if (!serviceKey) {
    console.error("Missing SERVICE_ROLE_KEY");
    return new Response("Server not configured", { status: 500 });
  }

  const authHeader = req.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return new Response("Missing token", { status: 401 });
  }
  const token = authHeader.slice("Bearer ".length).trim();

  const adminClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
  });

  const {
    data: { user },
    error: userError,
  } = await adminClient.auth.getUser(token);
  if (userError || !user) {
    return new Response("Invalid token", { status: 401 });
  }

  const authedClient = createClient(supabaseUrl, serviceKey, {
    auth: { persistSession: false },
    global: {
      headers: { Authorization: `Bearer ${token}` },
    },
  });

  const { data: profile, error: profileError } = await authedClient
    .from("profiles")
    .select("role,status")
    .eq("id", user.id)
    .single();

  if (profileError) {
    console.error("Profile fetch error", profileError);
    return new Response("Profile lookup failed", { status: 500 });
  }

  if (profile?.role !== "admin" || profile?.status !== "active") {
    return new Response("Forbidden", { status: 403 });
  }

  const body = await req.json().catch(() => ({}));
  const action = typeof body.action === "string" ? body.action : "update";

  if (action === "create") {
    const email =
      typeof body.email === "string" ? body.email.trim().toLowerCase() : "";
    const fullName =
      typeof body.full_name === "string" ? body.full_name.trim() : "";
    const requestedRole = validRoles.has(body.role)
      ? body.role
      : "collector";
    const requestedStatus = validStatuses.has(body.status)
      ? body.status
      : "inactive";
    const sendInvite = body.send_invite !== false;
    const password =
      typeof body.password === "string" ? body.password.trim() : "";

    if (!email) {
      return new Response("Email is required", { status: 400 });
    }

    if (password && password.length < 8) {
      return new Response("Password must be at least 8 characters", {
        status: 400,
      });
    }

    const metadata = fullName ? { full_name: fullName } : undefined;
    let targetUserId: string | null = null;
    let userAlreadyExisted = false;

    if (password) {
      const { data: createdUser, error: createError } =
        await adminClient.auth.admin.createUser({
          email,
          password,
          email_confirm: !sendInvite,
          user_metadata: metadata,
        });

      if (createError) {
        if (!createError.message?.includes("already registered")) {
          console.error("Create user error", createError);
          return new Response(createError.message, { status: 500 });
        }
        userAlreadyExisted = true;
      }

      targetUserId = createdUser?.user?.id ?? null;

      if (!targetUserId) {
        const { data: listedUsers, error: listError } =
          await adminClient.auth.admin.listUsers({ email, perPage: 1 });
        if (listError) {
          console.error("List users error", listError);
          return new Response(listError.message, { status: 500 });
        }
        targetUserId = listedUsers?.users?.at(0)?.id ?? null;
      }

      if (!targetUserId) {
        return new Response(
          "Provide a password or set send_invite=true to create a new user",
          { status: 400 },
        );
      }

      if (userAlreadyExisted) {
        const { error: updateError } = await adminClient.auth.admin
          .updateUserById(targetUserId, {
            password,
            user_metadata: metadata,
            email_confirm: !sendInvite,
          });
        if (updateError) {
          console.error("Update existing user password", updateError);
          return new Response(updateError.message, { status: 500 });
        }
      }

      if (sendInvite) {
        const { error: inviteError } =
          await adminClient.auth.admin.inviteUserByEmail(email, {
            data: metadata,
          });
        if (inviteError && inviteError.message !== "User already registered") {
          console.error("Invite error", inviteError);
          return new Response(inviteError.message, { status: 500 });
        }
      }
    } else {
      const { data: inviteData, error: inviteError } = sendInvite
        ? await adminClient.auth.admin.inviteUserByEmail(email, {
            data: metadata,
          })
        : { data: null, error: null };

      if (inviteError && inviteError.message !== "User already registered") {
        console.error("Invite error", inviteError);
        return new Response(inviteError.message, { status: 500 });
      }

      targetUserId = inviteData?.user?.id ?? null;

      if (!targetUserId) {
        const { data: listedUsers, error: listError } =
          await adminClient.auth.admin.listUsers({ email, perPage: 1 });
        if (listError) {
          console.error("List users error", listError);
          return new Response(listError.message, { status: 500 });
        }
        targetUserId = listedUsers?.users?.at(0)?.id ?? null;
      }

      if (!targetUserId) {
        return new Response("Unable to resolve user", { status: 500 });
      }
    }

    const { data: existingProfile, error: existingProfileError } =
      await authedClient
        .from("profiles")
        .select("*")
        .eq("id", targetUserId)
        .maybeSingle();

    if (existingProfileError) {
      console.error("Existing profile lookup", existingProfileError);
      return new Response("Profile lookup failed", { status: 500 });
    }

    if (!existingProfile) {
      const { error: insertError } = await authedClient
        .from("profiles")
        .insert({
          id: targetUserId,
          full_name: fullName,
          role: requestedRole,
          status: requestedStatus,
        });
      if (insertError && !insertError.message?.includes("duplicate")) {
        console.error("Profile insert error", insertError);
        return new Response("Profile insert failed", { status: 500 });
      }
    } else if (fullName && existingProfile.full_name !== fullName) {
      const { error: nameUpdateError } = await authedClient
        .from("profiles")
        .update({ full_name: fullName })
        .eq("id", targetUserId);
      if (nameUpdateError) {
        console.error("Profile name update error", nameUpdateError);
      }
    }

    const { error: rpcError } = await authedClient.rpc("set_user_role_status", {
      target_user: targetUserId,
      new_role: requestedRole,
      new_status: requestedStatus,
    });

    if (rpcError) {
      console.error("RPC error", rpcError);
      return new Response(rpcError.message, { status: 500 });
    }

    let profileResponse = null;
    for (let attempt = 0; attempt < 6; attempt++) {
      const { data: fetchedProfile, error: fetchError } = await authedClient
        .from("profiles")
        .select("*")
        .eq("id", targetUserId)
        .maybeSingle();

      if (fetchError) {
        console.error("Fetch profile after create", fetchError);
        return new Response(fetchError.message, { status: 500 });
      }

      if (fetchedProfile) {
        profileResponse = fetchedProfile;
        break;
      }

      await wait(150 * (attempt + 1));
    }

    if (!profileResponse) {
      return new Response("Profile creation pending", { status: 202 });
    }

    return new Response(JSON.stringify(profileResponse), {
      headers: { "Content-Type": "application/json" },
      status: 201,
    });
  }

  if (action === "set_password") {
    const targetUserId =
      typeof body.target_user_id === "string" ? body.target_user_id : "";
    const password =
      typeof body.password === "string" ? body.password.trim() : "";
    const sendInvite = body.send_invite === true;

    if (!targetUserId) {
      return new Response("target_user_id is required", { status: 400 });
    }

    if (password.length < 8) {
      return new Response("Password must be at least 8 characters", {
        status: 400,
      });
    }

    const {
      data: { user: targetUser },
      error: fetchUserError,
    } = await adminClient.auth.admin.getUserById(targetUserId);
    if (fetchUserError || !targetUser) {
      console.error("Fetch target user", fetchUserError);
      return new Response("Unable to load target user", { status: 404 });
    }

    const { error: updateError } = await adminClient.auth.admin.updateUserById(
      targetUserId,
      {
        password,
        email_confirm: true,
      },
    );

    if (updateError) {
      console.error("Update password error", updateError);
      return new Response(updateError.message, { status: 500 });
    }

    if (sendInvite && targetUser.email) {
      const { error: inviteError } =
        await adminClient.auth.admin.inviteUserByEmail(
          targetUser.email,
        );
      if (inviteError && inviteError.message !== "User already registered") {
        console.error("Invite error", inviteError);
        return new Response(inviteError.message, { status: 500 });
      }
    }

    return new Response(JSON.stringify({ ok: true }), {
      headers: { "Content-Type": "application/json" },
      status: 200,
    });
  }

  const { target_user_id, role, status } = body;

  if (
    !target_user_id ||
    !validRoles.has(role) ||
    !validStatuses.has(status)
  ) {
    return new Response("Invalid payload", { status: 400 });
  }

  const { error: rpcError } = await authedClient.rpc("set_user_role_status", {
    target_user: target_user_id,
    new_role: role,
    new_status: status,
  });

  if (rpcError) {
    console.error("RPC error", rpcError);
    return new Response(rpcError.message, { status: 500 });
  }

  const { data: updatedProfile, error: fetchError } = await authedClient
    .from("profiles")
    .select("*")
    .eq("id", target_user_id)
    .single();

  if (fetchError) {
    console.error("Fetch updated profile", fetchError);
    return new Response(fetchError.message, { status: 500 });
  }

  return new Response(JSON.stringify(updatedProfile), {
    headers: { "Content-Type": "application/json" },
    status: 200,
  });
});