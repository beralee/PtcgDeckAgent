# D050/P6-29 known gaps

Raw Windows ZIP/PCK/embedded-EXE reproducibility is closed for the pinned Godot
4.6.1 export profile. The following AS-WP6 gates remain open:

- no product-owned active Ed25519 production key or approved exact package;
- the fixed Windows device profile is still `proposed`, not product-approved;
- no positive production-signed acceptance-only device canary exists;
- the administrator WFP/4688 formal OS-isolation lane has not run;
- no formal Windows device report, rollback-bound release approval or A5 claim;
- no official CABT W0-W7 conformance or complete effect/engine parity claim;
- ordinary production player start remains closed;
- Android release, physical arm64 device evidence and Android A5 remain deferred.

The canonicalized development executable ran three complete matches, but the
absence of observed endpoints is not OS-level airplane-mode proof. The built-in
Marnie archive remains test-fixture signed with `execution_trusted=false` and
`cabt_exportable=false`. Official and Godot-local identities remain separate;
the official lane still has 9 mapped IDs covering 34/60 cards and 10 unmapped
IDs covering 26/60, while the local deck has 28 stable UIDs covering all 60
cards. A0 remains partial/not claimed and A1-A5 remain not evaluated.
