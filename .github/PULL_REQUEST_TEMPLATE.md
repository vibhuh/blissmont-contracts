<!--
Contract review gate. A contract is a promise to every independently deployable
component that consumes it. Answer all four — Q3 is the key guard.
-->

## Contract-change checklist

**1. Is this additive?**
<!-- New fields / new messages / new RPCs only? Or does it remove or alter existing ones? -->

**2. Is this wire-compatible?**
<!-- No field tag renumbered or reused, no field type changed, no field deleted
     (deprecate instead). A v1.x engine must still talk to a v1.(x-1) field client. -->

**3. Why is this a contract change rather than an implementation change?**
<!-- The key guard. If the need is "the engine/server now does X", that is usually an
     IMPLEMENTATION concern that should NOT touch the wire. A change belongs here only
     because more than one independently deployable component must agree on it. -->

**4. Does this require a major version?**
<!-- Any wire-INCOMPATIBLE change => new major package namespace (e.g. blissmont.pos.v2)
     coexisting with v1. If yes, link the migration plan. -->

---

- [ ] Semver bump matches the change class (patch = docs/tooling, minor = additive, major = breaking).
- [ ] `VERSION` updated.
- [ ] Buf breaking-change check passes (release gate — Milestone 0.5+).
