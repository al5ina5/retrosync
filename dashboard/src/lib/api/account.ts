export type AccountData = {
  subscriptionTier: string;
  email: string;
  name: string;
  createdAt: string;
};

export type UpdateAccountBody = {
  name?: string;
  email?: string;
  currentPassword?: string;
  newPassword?: string;
};

export type AccountApiResult<T = unknown> =
  | { success: true; data: T }
  | { success: false; error: string };

async function accountFetch<T>(
  token: string,
  init?: RequestInit
): Promise<AccountApiResult<T>> {
  try {
    const res = await fetch("/api/account", {
      ...init,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${token}`,
        ...init?.headers,
      },
    });
    const json = await res.json();
    if (json.success && json.data != null) {
      return { success: true, data: json.data as T };
    }
    return { success: false, error: json.error ?? "Request failed" };
  } catch {
    return { success: false, error: "Request failed" };
  }
}

export async function getAccount(token: string): Promise<AccountApiResult<AccountData>> {
  return accountFetch<AccountData>(token, { method: "GET" });
}

export async function updateAccount(
  token: string,
  body: UpdateAccountBody
): Promise<AccountApiResult<{ ok: true }>> {
  return accountFetch<{ ok: true }>(token, {
    method: "PATCH",
    body: JSON.stringify(body),
  });
}

export async function deleteAccount(
  token: string,
  password: string
): Promise<AccountApiResult<{ ok: true }>> {
  return accountFetch<{ ok: true }>(token, {
    method: "DELETE",
    body: JSON.stringify({ password }),
  });
}
