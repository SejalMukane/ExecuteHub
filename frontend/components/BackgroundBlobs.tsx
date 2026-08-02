"use client";

import React from "react";

export default function BackgroundBlobs() {
  return (
    <div
      className="absolute inset-0 overflow-hidden pointer-events-none"
      aria-hidden="true"
    >
      <div className="absolute -top-24 -left-24 w-[420px] h-[420px] rounded-full bg-emerald-500/15 blur-[110px]" />
      <div className="absolute top-1/3 -right-28 w-[460px] h-[460px] rounded-full bg-blue-500/10 blur-[120px]" />
      <div className="absolute -bottom-32 left-1/4 w-[520px] h-[520px] rounded-full bg-purple-500/10 blur-[120px]" />
      <div className="absolute top-1/4 left-1/2 w-[360px] h-[360px] rounded-full bg-amber-500/10 blur-[100px]" />
    </div>
  );
}
