import { NextResponse } from "next/server";

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
  message?: string;
}

export function successResponse<T>(data: T, message?: string) {
  return NextResponse.json({ success: true, data, message } as ApiResponse<T>);
}

export function errorResponse(error: string, status: number = 400) {
  return NextResponse.json({ success: false, error } as ApiResponse, { status });
}

export function unauthorizedResponse(message: string = "Unauthorized") {
  return errorResponse(message, 401);
}

export function notFoundResponse(message: string = "Not found") {
  return errorResponse(message, 404);
}

export function serverErrorResponse(message: string = "Internal server error") {
  return errorResponse(message, 500);
}

export function validateRequiredFields(
  body: Record<string, unknown>,
  fields: string[]
): string | null {
  for (const field of fields) {
    if (!body[field]) return `Missing required field: ${field}`;
  }
  return null;
}

export function generateDeviceName(): string {
  const adjectives = [
    "Cosmic", "Stellar", "Nebula", "Quantum", "Galactic", "Astro", "Lunar", "Solar",
    "Electric", "Neon", "Cyber", "Digital", "Virtual", "Hyper", "Ultra", "Mega",
    "Turbo", "Super", "Epic", "Legendary", "Mystic", "Ancient", "Crystal", "Golden",
    "Silver", "Platinum", "Diamond", "Ruby", "Sapphire", "Emerald", "Amber", "Jade",
    "Frost", "Flame", "Thunder", "Storm", "Shadow", "Phantom", "Ghost", "Spirit",
    "Wild", "Fierce", "Bold", "Swift", "Rapid", "Blazing", "Frozen", "Eternal",
  ];
  const nouns = [
    "Gizmo", "Widget", "Device", "Gadget", "Thing", "Machine", "Unit", "Module",
    "Console", "Station", "Hub", "Node", "Core", "Engine", "Drive", "System",
    "Beast", "Warrior", "Knight", "Guardian", "Champion", "Hero", "Legend", "Myth",
    "Phoenix", "Dragon", "Tiger", "Eagle", "Wolf", "Falcon", "Hawk", "Lion",
    "Star", "Comet", "Planet", "Moon", "Sun", "Orb", "Sphere", "Cube",
    "Blade", "Shield", "Sword", "Bow", "Arrow", "Spear", "Axe", "Hammer",
  ];
  const a = adjectives[Math.floor(Math.random() * adjectives.length)];
  const n = nouns[Math.floor(Math.random() * nouns.length)];
  const num = Math.floor(Math.random() * 9999) + 1;
  return `${a} ${n} ${num}`;
}
