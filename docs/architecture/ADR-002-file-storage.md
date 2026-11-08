# ADR-002: File storage uses Option B (Edge Functions + presigned R2 URLs)

Date: 2026-10-15. Status: accepted, pending the online spike results (`infra/cloudflare/r2-spike`). Revisit if the spike contradicts a premise.

## Options
A. Supabase Storage with an S3 backend pointed at R2.
B. Our own Edge Functions that authorise, then issue short-lived presigned R2 URLs. Bytes flow directly between the client and R2.

## Evidence (read 2026-10-15)
- Supabase's self-hosting docs support an S3 backend and list Cloudflare R2 as a target, but state that **R2 does not implement the S3 feature needed for TUS (resumable) uploads**.
- Cloudflare's proxied request-body limit is **100 MB on Free** (official error 413 page). Under A, uploads and downloads would pass through our API hostname.
- Under A every byte passes through the **home laptop and its uplink** (gateway, then Storage, then R2). Under B the home connection carries only small JSON calls.
- R2 presigned URLs support GET, PUT, HEAD, DELETE; expiry 1 s to 7 days; they work only on the S3 endpoint; POST form uploads are not supported (Cloudflare docs). Presigned PUT can pin content type; whether signed content-length is enforced is a spike question.
- R2 egress is free and DeleteObject is a free operation (pricing page).

## Decision
Option B. Reasons, in order: (1) no file bytes through the home connection or the proxied domain; (2) no dependence on a TUS path that R2 lacks; (3) quota reservation, magic-number sniffing and a pending-then-confirm flow are natural to write in a function; (4) revocation is simple: stop issuing URLs, and issued ones expire in 60 to 120 s.

## Cost of this decision
- We write and test the file authorisation ourselves (Phase 4). Mitigation: `file_objects` table with RLS, one shared authorisation helper, pgTAP tests for owner, shared user, denied user, anonymous, and expired or revoked shares.
- Issued download URLs cannot be revoked before they expire (documented residual risk, `THREAT_MODEL.md`).
- Upload size cannot be capped by Storage config. Caps come from the declared size at presign time, signed content-length if enforced, a HEAD check at confirm, and a 1-day expiry on `pending/`.
- The API hostname allowlist (ADR-001) keeps `/storage/v1/` blocked. If this ADR is reversed, add it and its negative test.

## Triggers to revisit
Spike shows presigned PUT cannot be constrained enough; R2 requires a card and you decline; we move to a VPS and want Supabase Storage's built-in RLS for small files.

## Fallback if R2 is not possible
Local disk on the host plus an off-site encrypted copy to a free target chosen then. Same function interface, different driver. Costs: host disk growth and no CDN.
