# D050/P6-29 deterministic Windows export containers

This evidence package closes the raw-container reproducibility defect recorded
by D045. Godot 4.6.1 produced equal logical resources in nondeterministic write
order, so the release owner now canonicalizes every Windows resource ZIP, PCK,
and embedded-PCK executable immediately after Godot export and before inventory
inspection, runtime probing, hashing, signing, or approval.

The canonicalizer is deliberately narrow and fail closed. It accepts the
pinned Godot 4.6 PCK v3 profile, validates every path, size, range, alignment,
flag, MD5 field and embedded trailer, then rewrites payloads in ascending ASCII
path order. ZIP metadata is normalized to stored entries, a fixed timestamp,
fixed permissions and no comments or extra fields. It rejects unsafe paths,
case-fold collisions, encrypted ZIP entries, unsupported formats, overlap,
non-zero padding, digest drift and existing outputs. The embedded executable's
PE prefix, total length and Godot trailer remain unchanged.

The old D045 A/B exports first proved that three different raw container hashes
converge to exact byte equality after canonicalization. Two new complete
Windows release exports from the same worktree then independently produced the
same five bound outputs: resource ZIP, PCK, embedded EXE, inventory and PCK
runtime-probe log. The runtime probe loaded the canonical PCK and accepted all
22 required release paths.

The canonicalized executable was then run outside the editor against the
existing rules AI for seeds 84700-84702. All three games reached terminal state;
182/182 policy calls succeeded, 179 engine commands committed, and policy
errors, invalid outputs, same-window fallback, classic fallback, engine
rejections and external-process attempts were all zero. The wrapper observed
zero child processes and zero network endpoints.

This is a deterministic build-container and development execution subgate. It
does not provision a production key, approve a package, prove OS-level network
isolation, approve the proposed device profile, claim A5, open ordinary player
start, establish official CABT W0-W7 or engine parity, or add Android scope.
AS-WP6 remains the active work cursor.
