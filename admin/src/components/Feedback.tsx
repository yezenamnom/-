"use client";

export type Msg = { kind: "error" | "success" | "info"; text: string } | null;

export function Feedback({ msg }: { msg: Msg }) {
  if (!msg) return null;
  return (
    <div className={`alert ${msg.kind}`} role={msg.kind === "error" ? "alert" : "status"} data-testid={`msg-${msg.kind}`}>
      {msg.text}
    </div>
  );
}
