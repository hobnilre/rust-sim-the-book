# The SIM Kernel {#the-sim-kernel}

*How a Rust runtime grows through shared contracts*

An extensible runtime needs more than a way to load another library. Its
components must agree on what a value is, how an operation is requested,
which arguments are acceptable, who may perform an effect, and how the
installed system can be inspected. The SIM kernel brings these agreements
together in a common Rust contract layer. This chapter follows an illustrative
sensor extension through that layer, using diagrams and a short dispatch
algorithm to explain the design without a Rust implementation walkthrough.
The central benefit is that domain behavior, surface syntax, evaluation
policy and inspection can evolve around shared protocols. We also examine
the cost of that flexibility: runtime checks, explicit identity choices,
truthful metadata and a firm distinction between saved descriptions and
live executable objects. This chapter establishes the vocabulary for
a later treatment of the loader and its lifecycle responsibilities.

## A runtime that can keep growing

Suppose a developer adds a sensor library to a running software system. Reading
the device is only part of the work. Other components need to find the sensor,
understand its arguments, ask whether reading is permitted, consume its results,
and explain its behavior to a person or an automated tool. A second library
might calculate statistics over the readings. A third might provide a different
input language. If each addition introduces its own representation and discovery
rules, the integration work grows with the number of combinations.

SIM addresses that problem by giving its components a common set of contracts.
The kernel names expressions, live values, operations, shapes, capabilities,
library exports and inspection records. Libraries implement behavior against
those contracts. The interesting result is a place where a new domain object can
be called, checked and described using concepts that its callers already know.
The kernel does not need to anticipate the concrete Rust type of every future
sensor, number domain or user interface.

The word *kernel* here means the shared contract layer of the SIM runtime. It is
not an operating-system kernel. SIM is an expandable Rust runtime with several
possible codec surfaces; a Lisp-like notation is one possible surface, rather
than the definition of the system. A *codec* translates between an external
representation and the runtime's shared forms. Changing that representation
need not replace the underlying object protocols.

Figure \ref{fig:ch02-boundary} shows the architectural division. This is a dependency
picture: components above the kernel depend on its agreements. It is not a
claim that every request follows one fixed execution pipeline.

![Schematic dependency view. Concrete libraries and host mechanisms meet at a common contract layer. The loader's concrete policies are reserved for the next chapter.](figures/kernel-boundary.pdf){#fig:ch02-boundary width=100%}

\FloatBarrier

This chapter explains the design at the public `sim-kernel` revision
`bbf0967be4f8`, whose package version is 0.4.0. The public implementation and its tests establish the behavior described below
([SIM contributors, 2026][ch02-kernel]). The audience is a software developer who
understands libraries and interfaces; familiarity with Rust syntax is optional.

The argument has a deliberate boundary. We start with the contracts that let
an extension participate in SIM. We introduce the registration substrate and
explain why saved metadata differs from live behavior. The concrete acquisition,
activation and lifetime of a library belong to the loader follow-up. A future
chapter can therefore begin with “how does this library enter the system?”
without first rebuilding the vocabulary of values and calls.

### What is actually in the center?

The kernel is more than a collection of empty interfaces. It includes common
representations, stores, checked dispatch machinery, reference evaluation
policies, and bootstrap list and table objects. Those implementations make the
contracts usable before richer libraries are installed. The important boundary
is responsibility: concrete language grammars, number-domain arithmetic,
application behavior and host loading policy can be supplied outside the center.

That boundary is useful because the things that change for different reasons
can have different owners. A sensor author defines device behavior. A codec
author defines a surface representation. A host decides which capabilities it
will grant. An inspection library presents structured descriptions. They still
need to agree on names, values and operations, but none needs to own all the
others' implementations.

There is no measured claim here that this organization is faster, smaller in
compiled bytes, or easier to maintain than every alternative. Its benefit is an
architectural one: common consumers can work against stable participation rules
as new concrete kinds are introduced. Its costs will become visible along the
same path.

## One extension, several cooperating contracts

Consider an illustrative library exposing a sensor object. The object offers a
versioned operation, `sensor:sample@v1`, that accepts a positive sample count
and returns a batch of readings. Reading the device requires the capability
`sensor.read`. A separate operation, `signal:mean@v1`, accepts an already
captured nonempty batch and calculates its arithmetic mean. The count, batch
shape, capabilities and operation names are design choices for this example;
they are not a claim that the kernel ships a sensor driver or these operations.

For a synthetic three-sample response $(2,4,6)$, the second operation returns
$4$. Nothing about that arithmetic requires the kernel to know a sensor's Rust
structure. What matters is that the participating libraries agree on the batch
representation, number domain and operation contracts. Figure
\ref{fig:ch02-extension} follows that agreement from a request to reusable data.

![Schematic extension example. Sensor sampling is an effectful operation; reducing an already captured batch is a separate domain operation. The values are synthetic, not device measurements.](figures/extension-story.pdf){#fig:ch02-extension width=100%}

\FloatBarrier

The kernel contributes five different kinds of agreement to this small story:

| Agreement | Question answered in the example |
|--------------------------|----------------------------------------------------------|
| Expressions and values | How does a written request become a form and refer to a live sensor? |
| Operations and shapes | Which operation is requested, and does its input meet the declared contract? |
| Context and capabilities | May this call perform a sensor read in this context? |
| Evaluation policy | When is a delayed sampling request actually performed? |
| Registry and inspection | What was registered, and how can a tool describe it? |

: The kernel's contributions to one extension. Supplying the driver, arithmetic and external syntax remains library work.

A surface language might express the request as a function call; an application
might construct the equivalent form directly. That choice is separate from the
operation key used for object dispatch. A registry symbol identifies something
that can be looked up; an operation key identifies a behavior requested of a
target object. A language library can connect them, but their roles should not
be collapsed into one global function name.

This distinction becomes valuable when one live object supports several
operations, or when two objects implement the same operation contract. The
caller can ask for behavior without first discovering a concrete Rust type and
writing a branch for each possible implementation.

## Forms, live objects and names for things

An extensible runtime needs several representations because it asks several
different questions. “What was written?”, “what object is available now?” and
“how can this thing be named later?” have different answers in SIM.

### Expressions carry form; values carry live behavior

An `Expr` is a codec-neutral expression graph. It can represent literals,
collections, calls, operators, blocks, quotation, annotations and tagged
extension forms. Source locations are carried by separate located wrappers.
A number literal includes a domain symbol and a textual representation; that
representation does not itself implement arithmetic. A concrete number domain
supplies the relevant interpretation and behavior.

This gives codecs a common target. Two suitable codecs can express the same
form using different external syntax. It does not follow that arbitrary
languages have identical semantics, or that every decoder accepts every form.
Those are obligations of the particular codecs and evaluation policies. The
kernel supplies the meeting point at which those obligations can be stated.

A `Value`, by contrast, is a reference-counted handle to a live runtime object.
The object's concrete type can come from a library. Its shared surface includes
identity information, operations, claims, an optional data snapshot and a
human-readable display. Existing typed protocol views are also available through
compatibility adapters. This is an open object model for behavior, while the
expression graph deliberately has a known vocabulary plus an extension form.

Only a little Rust is needed to understand the mechanism. Rust trait objects
allow different concrete implementations to be reached through a shared
interface ([Rust project, n.d.-a][ch02-traits]). SIM stores a shared handle to such an
object. Reference counting extends its lifetime while handles remain; it does
not make the object's internal state immutable. `Arc`'s ownership properties
must be distinguished from the thread-safety of the data it holds
([Rust project, n.d.-b][ch02-arc]). SIM additionally requires its runtime objects to
satisfy Rust's thread-sharing bounds, which still does not prove application-level
ordering or consistency.

The practical advantage is that adding a new object kind need not add a new
variant to a universal value enumeration and then update every consumer's
case analysis. Consumers that use the shared operations can already carry and
interact with the new value. Concrete downcasting remains possible, but using
it as the routine integration mechanism would give up much of that advantage.

### Equality depends on the question

Two expressions can compare canonically even if the entries of a map, or the
members of a set, appear in a different order. A `Value` uses object identity
for equality and hashing: two handles to the same allocation compare equal.
Separately allocated objects with identical contents need not do so. Therefore
“these batches contain the same samples” is a domain-level question, not an
automatic consequence of comparing two runtime handles.

A `Ref` supplies explicit naming choices. A symbol can be resolved through a
registry; a content identifier names immutable data; a handle identifies a live
object in a host-controlled namespace; a ranked coordinate names a position in
a declared space. Figure \ref{fig:ch02-identity} keeps these roles separate.

![Schematic representation boundaries. Forms describe requests, values carry live behavior, and references name targets. A data snapshot is an explicit optional projection, not an automatic serialization of a live object.](figures/representations.pdf){#fig:ch02-identity width=100%}

\FloatBarrier

For the sensor example, the registry symbol can name the sensor service, while
a handle can identify the particular live connection currently in use. The
captured sample batch may also have a data representation. If that data belongs
to the kernel's `Datum` vocabulary, its canonical bytes can be hashed to obtain
a content identifier. A datum is a restricted data form, not an encoding of
arbitrary executable expressions or Rust objects. Its canonicalization rules
also reject duplicate map keys and duplicate set members.

The choice changes what can survive a restart. Content data can be stored and
looked up by its identifier. A live device connection cannot be restored merely
by saving the address of its object. Handles are allocated from caller-supplied
seeds and sequences, so the host must manage those namespaces; a handle is not
a globally resolvable address or evidence that an object is portable.

This is a strength of the design when used explicitly. SIM does not require a
live object, its description and its saved state to pretend to be the same
thing. A caller can choose the identity needed for the task and state which
resolver or reconstruction mechanism will be required later.

The written request, the live object and its stored description answer different questions. Choosing a representation does not automatically supply the behavior or reconstruction needed by another one.

## A checked call has a visible boundary

An operation has a key consisting of a namespace, a name and a version. Its
specification describes a subject, an input shape, a promised result shape,
declared effects and required capabilities. The object's implementation supplies
the behavior. The checked dispatch entry point brings that specification into
the calling path.

For `sensor:sample@v1`, an input shape might accept a positive integer count;
the result shape might describe a batch with a declared numeric representation.
The effect declaration can identify sampling, and the capability requirement
can demand permission to use the sensor. These statements give callers and
tools something concrete to inspect before they know the implementation.

\Needspace{16\baselineskip}

### The small algorithm that matters

The order of checks is part of the contract. The following pseudocode shows
the kernel's checked operation entry point, with Rust details removed:

```text
invoke(context, target, key, input):
    operation = resolve target's operation for key
    require every capability declared by operation
    check input against operation's argument shape
    return operation's authorized implementation(context, input)
```

Resolution first looks for an operation directly offered by the object. If none
is available, a kernel adapter may expose an existing typed protocol through the
same operation interface. If neither path supplies the requested operation,
resolution fails. This bridge allows existing callables, shapes and collection
views to participate while callers adopt a common operation vocabulary.

For the sampling example, the absence of `sensor.read` prevents entry into the
operation body. So does an input that the declared shape rejects. An unresolved
shape reference is an error; an unknown shape is not silently treated as “accept
anything.” Explicit universal shape references provide the intentional escape
hatch. The checked path therefore distinguishes a broad contract from a broken
contract reference.

That is an admission boundary for the operation body, not a blanket claim that
nothing can happen earlier. Resolution and shape checking have their own
implementations, and the shape protocol can describe effectful matchers. Code
that calls an authorized implementation directly is also responsible for having
performed the checks. The published Rust method name is not an access-control
barrier against arbitrary code already running in the same process.

### A shape can do more than return yes or no

A shape can check a live value or an expression. Its match result can carry
acceptance, a score, named bindings and diagnostics. The same family of contracts
can therefore serve argument validation, grammar matching, binding and selection
among alternatives. Concrete matchers and the rules for using their scores still
belong to their implementations and consumers.

For a sample request, a shape could reject a missing count with a diagnostic,
accept the requested count and bind it under a name, or recognize an expression
before it is evaluated. The attractive part is the reusable result vocabulary.
A tool does not have to learn an unrelated diagnostic convention for each
application domain. Reuse of the protocol does not guarantee that two libraries
chose compatible numeric units, field names or meanings; those agreements must
still be designed.

This dynamic check complements Rust's static type system. Rust verifies the
implementation-level interfaces. A SIM shape describes the runtime-level value
or form accepted at an extensible boundary. A program can compile correctly and
still submit a SIM value that the operation's shape rejects.

### Metadata and enforcement are different

At the inspected revision, the checked operation function enforces required
capabilities and the input shape. It does not perform a general post-call check
of the declared result shape, and it does not automatically audit all emitted
effects against the specification's effect list. Those fields remain valuable
contracts for implementations, tools and other checking layers. They must not
be presented as universal guarantees established by this dispatcher.

The result of an operation is also explicit. The kernel can represent a completed
value, a batch of events, or a suspended step carrying an effect. Defining those
outcomes gives callers a shared vocabulary; arranging event consumption and
resumption still requires the surrounding runtime. A sensor operation that can
suspend needs a consumer that understands that outcome. Merely having a common
return type does not make every caller capable of handling every effect.

\Needspace{14\baselineskip}

| Specification field | Role at the checked operation boundary |
|---------------------------|------------------------------------------------------|
| Key | Selects behavior on the target, directly or through an adapter. |
| Required capabilities | Checked before entering the operation body. |
| Argument shape | Resolved and checked against the input. |
| Result shape | States the implementation's promised output contract. |
| Declared effects | Describes possible effects; this entry point does not audit the complete execution. |

: What the operation specification means in the inspected implementation. Different higher-level paths may impose additional checks.

A declared contract describes what an implementation promises. The guarantees of a particular call depend on the checks that its calling path actually performs.

### The host retains the power to grant

Capabilities are carried in an evaluation context. In a normal build, the
host obtains a separate grant seat when it constructs a context, and the seat
is bound to that context. A callable receives the context, not that seat.
Creating a different context and its seat does not permit granting capabilities
into the original one. Test-only support deliberately exposes fixture shortcuts
and should not be confused with this production contract.

This makes authority assignment a visible host responsibility. A browser may
be allowed to describe a sensor without being allowed to read it. A sampling
operation can ask for its specific capability rather than assuming that any
caller able to find the object may use the device. Capability sets can also be
narrowed by intersection; narrowing does not manufacture a missing grant.

These are protocol-level controls inside SIM. They are not an operating-system
sandbox around an arbitrary native library. Host APIs, direct in-process calls,
transport isolation and the loading of trusted or untrusted code have their own
boundaries. That distinction will matter particularly in the loader chapter.

## Choosing when work happens

The sensor example also explains why evaluation strategy belongs in the
architecture. A delayed expression that samples a device is observably different
from an already captured batch. If the expression is forced twice, should it
sample twice, or should it reuse the first successful result?

The kernel makes evaluation policy explicit. A policy prepares arguments,
forces values according to demands, evaluates expressions, and controls whether
macro expansion is allowed in a particular phase. The supplied reference
policies include eager evaluation, non-memoizing laziness, memoized call-by-need,
and strategies that mix evaluated and deferred or quoted arguments.

A *thunk* is a delayed computation that carries an expression and its captured
lexical environment. Under the non-memoizing lazy policy, forcing it again runs
the captured expression again. Under the supplied call-by-need policy, the first
successful result is cached. Thus, for an illustrative expression that performs
one sampling operation per evaluation, two forces can mean two device reads
under the former policy and one successful read reused under the latter. That
is a semantic choice, not merely a performance optimization.

![State transitions of the supplied memoizing thunk. A successful force caches a value; a failed force restores the pending computation so a later request can retry. Re-entering a computation while it is being forced reports an error.](figures/need-state.pdf){#fig:ch02-need width=96%}

\FloatBarrier

Figure \ref{fig:ch02-need} shows the precise limit of “evaluate once.” The implementation
caches a successful result. A failed attempt returns the thunk to its pending
state, allowing a retry. An effect performed before a failure is not thereby
undone. Memoization is therefore not an exactly-once guarantee for an external
device operation. The forcing state also detects re-entry instead of silently
recursing; it is not a general promise that competing callers wait for a result.

Demands state what a caller needs from an argument: leave it untouched, retain
expression form, obtain a value, obtain truth, or require a specified class or
shape. The reference policies interpret those requests differently during
argument preparation. A demand vocabulary is an interface for evaluation choices,
not proof that every policy enforces every requested property at every stage.
The explicit forcing path performs the corresponding reference checks.

For the sample-and-mean example, this suggests a practical design rule: capture
the batch once when the application intends to analyze one observation, then
pass that value to the statistics operation. Defer the sampling expression only
when repeated evaluation, memoization and retry behavior are part of the
intended semantics. The representation chosen by the caller should make that
choice visible.

The same separation helps symbolic work. A reference policy may keep an unbound
symbol, or an application of an unbound operator, as data. A stricter policy can
reject it. This allows a host to distinguish a symbolic construction from a
programming error without identifying one surface syntax with one immutable
language policy. It does not make every expression meaningful under every policy.

The kernel also defines an evaluation-fabric interface and a realization request
vocabulary for callers that should not depend on a specific transport. These
contracts carry such concerns as observation mode, limits and required
capabilities. They provide a place for local or remote implementations to meet;
they do not, by themselves, implement a distributed scheduler or make a
process-local handle remotely usable. Detailed execution and transport behavior
belongs in later chapters.

For the illustrative sensor task, passing the captured batch onward makes the intended observation explicit. Passing a delayed sampling request instead requires a decision about repetition, caching and retry.

## A system that can describe what is present

A collection of extensible objects is much easier to work with when the system
can describe its installed state. In SIM, this is not confined to debug strings.
The kernel supplies both a registry substrate and structured descriptions of
runtime subjects. They answer different questions and should remain distinct.

### Registration has an authoritative record

The registry presents typed lookup and registration interfaces, but its
authoritative storage is a catalog of named tables and rows. Row data is
represented through expressions; private live cells can hold objects that cannot
be serialized as ordinary data. The registry maintains projection caches where
its borrowed Rust interfaces need stable map or slice views. Those views serve
the API; they are not separate authorities for what was registered.

For the sensor extension, registration records what the library declares and
which exports were resolved to live values. Export states can distinguish
resolved, declared, unsupported and invalid entries. This is more informative
than a single boolean “loaded” flag: a tool can report the difference between an
advertised interface and behavior that is actually available.

The catalog has explicit write policies. Mutable tables permit replacement and
deletion. Sealed and append-only policies restrict changes to existing entries;
derived tables reject direct writes. A catalog transaction first validates its
batch, then applies it at one new epoch and records its operations in a journal.
The implementation tests exercise failed batches leaving no partial rows,
sequence changes or journal entries. This is an in-memory transaction boundary;
it is not a claim of disk durability or a distributed consensus protocol.

Library registration adds a staged load transaction and a linker through which
an implementation declares exports and supplies live values. The receiving
registry changes when the transaction commits. Discarding an uncommitted staged
registration leaves that registry unchanged. These guarantees concern the
registry state: an external side effect performed by library initialization is
not automatically rolled back with it.

That is enough loader context for this chapter. A library has a declaration,
a staged way to contribute behavior, and an authoritative place where the
committed result can be found. Choosing the source, crossing a native or guest
boundary, and managing activation and lifetime are the next layer's questions.

### A snapshot describes; it does not resurrect

A catalog snapshot contains table specifications, row data, sequences and an
epoch in deterministic expression form. Live payloads become explicit unresolved
markers rather than being serialized as Rust objects. Restoring such a snapshot
recreates data rows. It does not reopen the sensor connection or restore an
executable closure from its display text.

![Schematic registry views. Typed lookups, data snapshots and subject Cards serve different readers. Saving a catalog description does not save live executable payloads; reconstruction requires a separate loader or host mechanism.](figures/catalog-views.pdf){#fig:ch02-catalog width=100%}

\FloatBarrier

The distinction in Figure \ref{fig:ch02-catalog} is particularly useful for honest
inspection. A saved record can say which export was expected, where it belonged
and that its live payload remains unresolved. It need not pretend the behavior
has been restored. Catalog deltas can describe changes between compatible epochs,
but applying data changes still does not solve arbitrary object reconstruction.

Boot receipts address a related requirement. They record library identities,
requested and resolved sources, dependencies and committed exports. They provide
input to replay through loaders rather than claiming to serialize live Rust
behavior. Their existence helps explain why the follow-up should focus on the
loader: saved descriptions become useful operationally only when the system can
resolve, validate and reconstruct the intended participants.

### Cards give tools ordinary data to inspect

A Card describes a subject through ordered fields such as kind, help, argument
and result shapes, tests, operations, required capabilities and related subjects.
It is an ordinary runtime value, not a specially formatted paragraph that every
consumer must parse. Its fixed schema provides a common starting point even when
the available information is minimal. Claims and fallback data supply richer
descriptions where they exist.

For the sensor object, a Card could let a tool display the sample operation,
explain the count argument, show the required permission and offer a link to the
batch description. A human browser and an automated assistant can consume the
same structure for different presentations. A `shape-known` field helps a
consumer distinguish known argument information from a generic fallback.

The kernel owns the record contract. Rich browsing, help presentation and test
execution remain library behavior. Capability-gated visibility and structured
redaction are part of the documented browse convention; the mere existence of a
Card does not authorize exposing every field or running the listed tests.
Likewise, a description is evidence of what an implementation declares, not
proof that it behaves correctly.

This is the second payoff of the common contracts. The integration work done to
make an operation callable also makes it describable in a vocabulary shared by
tools. The runtime can carry useful information about itself as data, while
leaving presentation and execution policy to their owners.

## What the design buys, and what it asks of its users

The kernel's appeal is the combination of these agreements. Open objects permit
new concrete kinds. Operation keys let callers request behavior. Shapes make
admission rules explicit. Contexts carry permission and evaluation choices.
Catalog records and Cards make participation visible to tools. Each contract is
useful separately, but their shared use is what reduces the need for a separate
integration story around every library.

Consider adding a second source of sample batches, such as a saved recording.
If it supplies the same batch contract, the statistics operation can continue
to consume batches without knowing whether they came from a device or a file.
The acquisition operations can keep different capabilities and effects. A new
codec can offer another notation for the request without requiring the
statistics author to implement that notation. An inspection tool can present
both producers using their shared metadata. These are consequences of compatible
contracts, not automatic compatibility between arbitrary implementations.

The design asks for care in return. Names and versions must be maintained.
Operation metadata must describe the actual implementation. Shapes must have
well-defined semantics, and missing shape information must be handled honestly.
Applications must distinguish live identity from equal data and choose
appropriate policies for delayed effects. Indirect calls, reference counting,
metadata storage and runtime validation also have costs; this chapter makes no
benchmark claim about their magnitude.

For a small closed program whose types and operations are known together, direct
Rust interfaces and static composition may be simpler. SIM's contract layer
becomes attractive when independently evolving libraries, representations and
tools need to meet inside one runtime, especially when that runtime must describe
what it contains. The decision is about the required kind of extension and
inspection, not a general ranking of dynamic and static software.

### What was checked for this account

The source revision was preserved and its kernel test suite was run in an
isolated copy with Rust 1.96.0. The inspection traced the chapter's central
claims through the object and operation contracts, shape resolution, capability
grants, thunk transitions, catalog transactions, snapshot handling and Card
projection. Tests include failures that prevent operation-body execution,
shape-reference errors, context-bound grants, successful thunk memoization,
retry after a failed force, failed transaction atomicity and data-only snapshot
restoration. These are exercised implementation behaviors, not a proof of every
possible library's correctness.

The sensor and mean example is illustrative. The three sample values are
synthetic. No sensor hardware, concrete device library, benchmark or distributed
deployment was tested for this chapter. The distinction matters because the
kernel's contribution is the participation contract; validating a particular
device or transport requires the implementation that supplies it.

### The next question belongs to the loader

We can now state the loader's job precisely. A prospective library must become
a set of registered, usable participants in these contracts. The system needs
to choose and identify its source, account for dependencies and versions, cross
the relevant execution boundary, commit the available exports, and handle
failures and lifetime changes. Saved boot descriptions must reconnect to actual
behavior rather than masquerading as it.

Those questions deserve their own chapter. This chapter establishes why they
have a coherent place to land. The SIM kernel gives an expanding runtime a shared
language for *what a component can be asked to do, under which conditions, and
how that participation can be inspected*. Its value is that new behavior can
join a system that already knows how to ask those questions.

\Needspace{20\baselineskip}

## References {#ch02-references .unnumbered}

1. SIM contributors (2026). *sim-kernel*, package version 0.4.0, inspected
   revision `bbf0967be4f8`, 29 September 2026.
   [Public source and contract documentation][ch02-kernel]. The implementation and
   its tests are the primary source for the architecture described here.
2. Rust project (n.d.-a). *The Rust Programming Language*, “Using Trait Objects
   to Abstract over Shared Behavior.” [Official documentation][ch02-traits].
   Accessed 29 September 2026.
3. Rust project (n.d.-b). *Rust standard library documentation*, `std::sync::Arc`.
   [Official documentation][ch02-arc]. Accessed 29 September 2026.

[ch02-kernel]: https://github.com/sim-nest/sim-kernel/tree/bbf0967be4f8663490b12e4866de41a65232ee77
[ch02-traits]: https://doc.rust-lang.org/book/ch18-02-trait-objects.html
[ch02-arc]: https://doc.rust-lang.org/std/sync/struct.Arc.html
