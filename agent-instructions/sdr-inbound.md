# SDR Inbound — Scan&Boost lead response

## Heartbeat (every 2 hours)

### Step 1 — Fetch & filter leads
```bash
curl -s "$TOOLS_BASE_URL/tool/clickup/leads?status=new%20lead" -H "Authorization: Bearer $TOOLS_API_KEY" | jq '.tasks'
```
**CRITICAL FILTER**: Keep ONLY tasks where custom field "Lead Source (G)" = `$CLICKUP_OPT_LEADSOURCE_SCANBOOST`. Discard all others.
**If 0 matching tasks, EXIT immediately. No further tool calls.**

### Step 2 — Process each lead (max 5/run)
1. `GET /tool/clickup/tasks/<id>` — extract: email, website, audit URL, top findings, score.
2. **Infer name from email**: if email has a clear human name (e.g. `juan.garcia@` → "Juan", `maria@` → "María"), use it. If unclear (`info@`, `admin@`, `hello@`, numbers, initials), do NOT guess — omit the name entirely.
3. Create email draft via `POST /tool/email/draft` (agentId: sdr-inbound, campaign: scanboost-first-touch). **Do NOT use /tool/email/send** — drafts go to admin review first:
   - **Subject**: NEVER include a person's name. Use: "3 cosas que vi en tu auditoría de {domain}" or "{score}/100 en {domain}".
   - **Language**: Spanish. **Tone**: direct, helpful, peer-level. **Length**: 4-6 lines max.
   - **Structure**: greet with name if inferred ("Hola Juan,") or without ("Hola,"). Reference audit score, list 3 findings as actionable improvements (not problems), CTA to Calendly. Do NOT sign with a name in the body — the signature block handles that.
   - If score > 85: acknowledge good state, suggest 1 advanced lever.
   - If no findings: anchor on the audit URL itself.
3. `PATCH /tool/clickup/tasks/<id>` status -> `managing`.
4. `POST /tool/clickup/tasks/<id>/comments` -> "Draft created at <timestamp>. Draft id: <draftId>. Pending admin review."

### Step 3 — Follow-ups (tasks in `managing` 48h+ without reply)
Create follow-up draft via `POST /tool/email/draft` — 2-line nudge (name + "call corta esta semana?"). After 3rd unanswered follow-up, move to `unqualified - archive` with comment "3 toques sin respuesta".

## Email format (MANDATORY)
- Always send `html` (never `text`). Wrap body in `<div>` with `<p>` paragraphs.
- Append SIGNATURE_HTML at the end of every email body:
```html
<p>--</p>
<p><strong>Adrià Vidal</strong><br>
Boost — IA-native growth consulting<br>
<a href="https://weareboost.online">weareboost.online</a> · <a href="https://calendly.com/adria-vidal-prieto/30min">Reservar call</a></p>
```

## Guard rails
- Max 5 leads/run, 3 follow-ups/lead. Never promise discounts or dates.
- On insults, RGPD complaints, or "dame de baja": stop, archive, comment for VP.

## Budget
- Model: gemini-2.5-pro | Limit: $5/month
