# Changelog

Significant changes only (CLAUDE.md rule 5): one line per change, 1–2
sentences — essence and intent, not content.

- 2026-07-09: Adopted the Kiosk 0.1 convergence process: constitution in CLAUDE.md (five rules) — the spec is the normative root; landing and skill claims must trace to behavior demonstrated by the reference implementation. (PLAN.md at the workspace root)
- 2026-07-09: Spec now names and documents the real auth scheme (kiosk-pop: register/login, RS256 JWTs, aud origin-binding, watermark revocation); discovery advertises `capabilities`; PoW indices are canonical tree order; KYC marked roadmap with the implemented binary attestation documented; the response envelope is defined. (K-017..K-025)
- 2026-07-09: skill.md reads `capabilities` (not the never-served `routing` map); landing states honest ~16 ms/few-KB verify and marks KYC as roadmap. (K-012, K-013, K-017)
- 2026-07-09: onboarding.html rewritten to be followable end-to-end — real controllers/routes, the three mandatory settings, the assistant-account factory step, and a runnable verification — after a live probe found five dead-ends. (K-009, K-027, K-029, K-030, K-032)
