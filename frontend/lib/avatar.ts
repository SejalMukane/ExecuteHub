export const AVATAR_KEY = "executehub_avatar_style";

export interface AvatarStyle {
  id: string;
  label: string;
}

export const AVATAR_STYLES: AvatarStyle[] = [
  { id: "adventurer", label: "Adventurer" },
  { id: "adventurer-neutral", label: "Adventurer Mono" },
  { id: "avataaars", label: "Avataaars" },
  { id: "avataaars-neutral", label: "Avataaars Mono" },
  { id: "big-smile", label: "Big Smile" },
  { id: "bottts", label: "Botts" },
  { id: "bottts-neutral", label: "Botts Mono" },
  { id: "dylan", label: "Dylan" },
  { id: "fun-emoji", label: "Emoji" },
  { id: "glass", label: "Glass" },
  { id: "identicon", label: "Identicon" },
  { id: "lorelei", label: "Lorelei" },
  { id: "lorelei-neutral", label: "Lorelei Mono" },
  { id: "micah", label: "Micah" },
  { id: "miniavs", label: "Miniavs" },
  { id: "notionists", label: "Notionists" },
  { id: "notionists-neutral", label: "Notionists Mono" },
  { id: "open-peeps", label: "Open Peeps" },
  { id: "pixel-art", label: "Pixel Art" },
  { id: "pixel-art-neutral", label: "Pixel Mono" },
];

const AVATAR_BASE = "https://api.dicebear.com/9.x";

export function avatarUrl(style: string, seed: string): string {
  return `${AVATAR_BASE}/${style}/svg?seed=${encodeURIComponent(seed)}&backgroundColor=b6e3f4,c0aede,d1d4f9,ffd5dc,ffdfbf`;
}

export function readAvatarStyle(): string | null {
  try {
    return localStorage.getItem(AVATAR_KEY);
  } catch {
    return null;
  }
}

export function saveAvatarStyle(style: string | null): void {
  try {
    if (style) {
      localStorage.setItem(AVATAR_KEY, style);
    } else {
      localStorage.removeItem(AVATAR_KEY);
    }
  } catch {
    // ignore storage errors
  }
}

export function getInitials(name: string): string {
  return name
    .split(" ")
    .filter(Boolean)
    .slice(0, 2)
    .map((part) => part[0]?.toUpperCase() ?? "")
    .join("");
}
