/**
 * HTML šablony pro transakční e-maily z FalcoNest (automation-dispatch).
 * PROČ: Inline CSS a tabulkové rozvržení – kompatibilita s Outlook / Gmail / Apple Mail.
 */

export function escapeHtml(s: string): string {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll("\"", "&quot;");
}

/** Hlavní text → HTML s řádkováním (bez interpretace HTML v obsahu). */
function bodyTextToHtmlParagraphs(body: string): string {
  const escaped = escapeHtml(body);
  return escaped.replaceAll("\r\n", "\n").replaceAll("\n", "<br>");
}

export type FalcoNestEmailTemplateArgs = {
  /** Nadpis v bílé kartě (shodný s předmětem nebo krátký titulek). */
  title: string;
  /** Hlavní text zprávy (plain – bude escapován). */
  body: string;
  /** Volitelný deep link (např. webová aplikace / úkol). */
  ctaUrl?: string | null;
  /** Text na tlačítku – výchozí „Otevřít v aplikaci“. */
  ctaLabel?: string;
};

/**
 * Responzivní HTML e-mail: světle šedé pozadí, bílá karta se stínem, záhlaví FalcoNest,
 * čitelný sans-serif text, volitelné výrazné CTA tlačítko.
 */
export function buildFalcoNestEmailHtml(args: FalcoNestEmailTemplateArgs): string {
  const titleEsc = escapeHtml(args.title.trim() || "FalcoNest");
  const bodyHtml = bodyTextToHtmlParagraphs(args.body);
  const ctaUrlRaw = typeof args.ctaUrl === "string" ? args.ctaUrl.trim() : "";
  const ctaLabel = escapeHtml(
    (args.ctaLabel?.trim() || "Otevřít v aplikaci"),
  );
  const ctaUrlEsc = escapeHtml(ctaUrlRaw);

  const ctaBlock = ctaUrlRaw.length > 0
    ? `<tr>
  <td style="padding:8px 32px 28px;font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
    <table role="presentation" cellpadding="0" cellspacing="0" border="0">
      <tr>
        <td style="border-radius:10px;background:#2563eb;">
          <a href="${ctaUrlEsc}" target="_blank" rel="noopener noreferrer"
            style="display:inline-block;padding:14px 28px;font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:16px;font-weight:600;color:#ffffff;text-decoration:none;border-radius:10px;">
            ${ctaLabel}
          </a>
        </td>
      </tr>
    </table>
    <p style="margin:14px 0 0;font-size:13px;line-height:1.45;color:#64748b;word-break:break-all;">
      <a href="${ctaUrlEsc}" style="color:#2563eb;text-decoration:underline;">${ctaUrlEsc}</a>
    </p>
  </td>
</tr>`
    : `<tr>
  <td style="padding:8px 32px 28px;font-size:13px;line-height:1.5;color:#94a3b8;font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
    — FalcoNest
  </td>
</tr>`;

  return `<!DOCTYPE html>
<html lang="cs">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta http-equiv="X-UA-Compatible" content="IE=edge">
  <title>${titleEsc}</title>
</head>
<body style="margin:0;padding:0;background-color:#e8ecf1;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#e8ecf1;">
    <tr>
      <td align="center" style="padding:28px 14px;">
        <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" style="max-width:600px;width:100%;background-color:#ffffff;border-radius:14px;box-shadow:0 8px 32px rgba(15,23,42,0.1);overflow:hidden;">
          <tr>
            <td style="padding:0;margin:0;background:linear-gradient(90deg,#1e3a8a 0%,#2563eb 100%);height:4px;font-size:0;line-height:0;">&nbsp;</td>
          </tr>
          <tr>
            <td style="padding:24px 32px 8px;font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
              <span style="font-size:22px;font-weight:800;color:#1e3a8a;letter-spacing:-0.03em;">FalcoNest</span>
            </td>
          </tr>
          <tr>
            <td style="padding:8px 32px 4px;font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
              <h1 style="margin:0;font-size:22px;font-weight:700;color:#0f172a;line-height:1.25;">${titleEsc}</h1>
            </td>
          </tr>
          <tr>
            <td style="padding:16px 32px 8px;font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif;font-size:16px;line-height:1.65;color:#334155;">
              ${bodyHtml}
            </td>
          </tr>
          ${ctaBlock}
        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
}

/**
 * Čistě textová verze pro klienty bez HTML a pro pole `text` u Resend / SMTP.
 * Předmět zůstává v hlavičce e-mailu – zde jen tělo + volitelný odkaz.
 */
export function buildAutomationEmailPlainText(args: {
  body: string;
  ctaUrl?: string | null;
  ctaLabel?: string;
}): string {
  let t = args.body.replace(/\r\n/g, "\n").trimEnd();
  const u = typeof args.ctaUrl === "string" ? args.ctaUrl.trim() : "";
  if (u.length > 0) {
    const label = args.ctaLabel?.trim() || "Otevřít v aplikaci";
    t += `\n\n—\n${label}: ${u}`;
  }
  return t;
}
