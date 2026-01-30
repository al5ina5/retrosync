export async function fetcher<T = unknown>(url: string): Promise<T> {
  const token =
    typeof window !== "undefined" ? localStorage.getItem("token") : null;

  if (!token) {
    throw new Error("No authentication token");
  }

  const response = await fetch(url, {
    headers: { Authorization: `Bearer ${token}` },
  });

  if (response.status === 401) {
    if (typeof window !== "undefined") {
      localStorage.removeItem("token");
      localStorage.removeItem("user");
      window.location.href = "/auth";
    }
    throw new Error("Unauthorized");
  }

  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`);
  }

  const data = await response.json();
  if (!data.success) {
    throw new Error(data.error || "Request failed");
  }

  return data.data as T;
}
