# blissmont-contracts

The single source of truth for every Protobuf contract consumed by **more than one
independently deployable component** of the BlissMont / Rachis family (the Go engine +
accounting core, the Flutter POS terminal, the device-local terminal engine UI, and
future inventory / accounting / customer clients).

Engine-internal protos — consumed only inside the Go server — do **not** live here. They
stay in `rachis-core`. The inclusion test is one question:

> Does more than one independently deployable artifact consume this contract?
> **yes →** it belongs here. **no →** it stays in the consuming repo.

## Layout

```
proto/
├── common/v1/        package blissmont.common.v1 — transport-neutral shared value types
│   ├── money.proto       ONE money type, family-wide (decimal string, never paise-int64)
│   ├── decimal.proto     arbitrary-precision decimal as a string
│   ├── ids.proto         shared id wrappers (ProductId, TerminalId, …)
│   └── timestamp.proto   RFC3339 UTC instant
├── terminal/v1/      package blissmont.terminal.v1 — device-local UI ↔ engine Session stream
└── pos/v1/           package blissmont.pos.v1 — terminal ↔ server POS service
```

`common/v1` holds the family standard for shared value types so no two contracts invent
their own `Money` / `ProductId` / `Timestamp` and then drift (e.g. one money as paise-int64,
another as decimal-string → 1-paise bugs at the contract layer). **Money is a decimal string,
family-wide** — matching the exact-decimal engine, never a float, never an integer minor unit.

### The terminal contract is device-oriented

The terminal contract is device-oriented, not server-oriented. Every message represents what a terminal needs to know, not how the server stores or computes it. The engine is responsible for translating server-domain models into terminal-domain models.

Concretely: `terminal/v1` may import `common/v1`, but it MUST NOT import `pos/v1`. Server-domain
types (e.g. `pos.v1.TerminalConfigSnapshot`, with its GL accounts and posting concerns) never
cross onto the device wire — the engine maps them into device-domain twins (e.g.
`terminal.v1.TerminalConfig`). This direction is enforced in CI by the dependency-direction guard
(`make guard`), not just by convention.

> Adoption note: as of v1.0.0 the `common/v1` types are the canonical *definitions*. The
> existing `pos`/`terminal` contracts still carry their amounts/instants as bare strings.
> Migrating those fields to the `common/v1` message types is an additive, wire-considered
> change for a later minor — it is intentionally **not** done in the extraction milestone, to
> keep that move a zero-behavior-change relocation.

## Hard rules (in force from v1.0.0)

### Versioned package namespaces
The version lives **in the package name**: `package blissmont.pos.v1;`, not `package pos;`.
A git tag versions the *file*; the namespace versions the *type*. This lets `v1` and `v2` of a
contract coexist at the compiler/type level during a fleet migration (the Google / Kubernetes /
Envoy pattern). Every breaking change ships as a new major namespace (`blissmont.pos.v2`), never
an edit to `v1`.

### Wire compatibility (protobuf evolution)
Clients pin versions; field deployments run different ones. A v1.2 engine may talk to a v1.1
client in the field. Therefore every change to an existing contract MUST:

- **never** renumber or reuse a field tag,
- **never** change a field's type,
- only **add** optional fields / new messages / new RPCs,
- **deprecate** rather than delete (mark deprecated, keep the tag reserved forever).

Field-number bands keep new tags domain-aligned (terminal Command/Event):

```
1-99    Core        100-199  Discounts   200-299  Tender
300-399 Returns     400-499  Supervisor  500-599  Future (reserved)
```

Existing tags are frozen — they are **not** renumbered to fit the bands (tags are on the wire).
The bands govern *new* tags; the `500-599` Future band is compiler-guarded with `reserved` so a
stray tag there is a build error, not a silent land-grab.

### Note: the proto package name affects the gRPC method path
Renaming a proto package (e.g. `pos.v1` → `blissmont.pos.v1`) is **not** on the proto3 field
wire, but it **does** change the gRPC full-method path (`/blissmont.pos.v1.PosService/SubmitOrder`).
Every consumer — including the external Flutter POS client — must regenerate from the matching
contract version. Server and clients move together per release.

## Compatibility policy (semver → wire semantics)

- **Patch** (`1.0.x`) — documentation / comments / tooling only. No generated-code change.
- **Minor** (`1.x.0`) — additive, wire-compatible changes (new optional fields, messages, RPCs).
- **Major** (`x.0.0`) — intentional wire-**incompatible** change → new major package namespace
  (`blissmont.pos.v2`), coexisting with `v1`.

## Lifecycle policy (when can we retire a major?)

- At least one major version is supported at all times.
- Minor versions within a major are wire-compatible with each other.
- Deprecation must be **announced before removal**, with a minimum deprecation window
  (≥ one major cycle / a stated calendar duration). "Announced" alone is not enough — the
  window is what lets a client maintainer plan and ship a migration.
- A major version is never removed until **every supported client has migrated**.
- Every breaking change requires a new major package namespace (`v2`, `v3`, …).

## Contributing

Every PR is reviewed against the four questions in `.github/PULL_REQUEST_TEMPLATE.md`. Q3 —
"why is this a contract change rather than an implementation change?" — is the guard that keeps
engine/server concerns from leaking onto the wire.

### Buf release gate (enforced)

Breaking-change enforcement via [Buf](https://buf.build) is a **release gate**, not a
convenience: no new contract version may be tagged unless the breaking-change check passes
against the previous release tag. This makes the wire-compatibility rule and the semver
policy machine-enforced rather than remembered.

- **`buf.yaml`** pins the rules: `breaking: WIRE_JSON` (the wire-compat gate) and a pragmatic
  `lint: BASIC` set. Two lint rules (`PACKAGE_DIRECTORY_MATCH`, `IMPORT_USED`) are excepted
  because the v1.0.0 contracts can't satisfy them without a wire-breaking rename or a layout
  change — adopting full `STANDARD` lint + the `blissmont/<area>/v1` layout is a deliberate
  future (v2) change, documented in `buf.yaml`.
- **CI** (`.github/workflows/buf.yml`) runs `buf build` + `buf lint` on every push/PR and
  `buf breaking` against the latest release tag — so a wire break is caught at review time,
  before a tag is cut.
- **Locally:** `make check` (or `make lint` / `make breaking`) runs the same gate. Requires
  `buf 1.47.2`.

An intentional breaking change is never an exception to the gate — it ships as a new major
package namespace (`blissmont.pos.v2`) in a new file, which does not conflict with `v1` under
the breaking check.

## Versioning

`VERSION` holds the current family version. Consumers pin this repo as a git submodule at a
specific tag and run their own codegen against the pinned `.proto` source.
