# SIM: Make the Kernel Explicit {#make-the-kernel-explicit}

*Build applications around reusable domain modules*

Every program has rules that turn input into behavior. Those rules may form
a deliberate core, or they may be scattered through event handlers, command
processing and storage helpers. This chapter calls that implicit center a
kernel and asks what becomes possible when we give it an explicit boundary.
No general-purpose language is required: copy, paste, move and export can be
ordinary operations reached from a graphical interface, a command-line tool
or another program. Separating shared runtime contracts from domain behavior
then lets the domain become a module that more than one application can use.
Through an illustrative document editor, we explain the appeal of this
design, the agreements that make reuse real, and a practical way to begin
without building a speculative framework. SIM gives the idea a concrete
expression in Rust, while leaving surface syntax and domain behavior open.

## Your program already has a kernel

A diagram editor receives a mouse movement and changes a document. A batch tool
reads a file and writes a transformed one. A service accepts a request and
updates some state. Their interfaces differ, but each must decide what its
inputs mean, which work to perform, what may change, and how the outcome becomes
visible. Those decisions are the program's core.

In this chapter, that core is what we mean by a *kernel*. It need not be general,
reusable or located in a directory with that name. A program can have its kernel
spread across button callbacks, command handlers, validation routines and file
helpers. The responsibilities exist even when the boundary does not.

This is the useful sense in which every program has a kernel. It is an
architectural way of looking at the program, rather than a claim that every
executable contains an operating-system kernel or an interpreter. At the
smallest scale, the core may be no more than a few functions. At a larger scale,
it may coordinate many subsystems. Naming it does not require centralizing all
execution in one object or thread.

The basic picture is input, kernel, output. Input includes more than text:
gestures, messages, startup configuration, a timer firing, or the state left by
an earlier action can all matter. Output includes values, visible changes and
effects such as writing a file. An interactive program repeats this conversation
while retaining state. Figure \ref{fig:ch01-implicit} shows both the scattered
implementation and the responsibility we can identify inside it.

![Schematic views of the same application. Core decisions can be scattered through several files; the input–kernel–output view identifies their common responsibility. State carries consequences from one interaction to the next.](figures/implicit-core.pdf){#fig:ch01-implicit width=100%}

\FloatBarrier

The arrow picture does not make a stateful application a pure function. A
request can suspend, fail, emit several events, or depend on external state.
Some programs have no ongoing external input at all. The point is to identify
the rules governing behavior, including initial conditions and ongoing work,
so that their relationship to the outside world can be designed.

Once that center is visible, a practical question follows: if the program needs
these decisions anyway, why leave their organization accidental? Why not give
the core a clear boundary from the beginning, so the first interface does not
become the only way the program can work?

## A kernel does not need a language

It is easy to hear “runtime” or “kernel” and imagine a parser, a prompt and a
programming language. None is a prerequisite. A program can expose a small
vocabulary of actions through ordinary function calls. For a diagram editor,
that vocabulary might include copying selected objects, pasting a fragment,
moving an object, checking a document and exporting a result.

These operations already have meaning whether or not anyone can type them.
They need inputs, outcomes and rules. They do not need variables, loops, macros
or a Lisp reader. A textual language is one possible way of arranging calls to
such operations. It can arrive later, or never.

### Copy, paste and drag are enough to begin

Consider an illustrative editor whose documents contain shapes and connections.
This editor is a design example, not a claim about a shipped SIM application.
A menu item and a keyboard shortcut can both request a copy. A paste request
supplies a document fragment and a destination. A drag gesture can eventually
request that an object move to a new position.

The GUI knows about pointer coordinates, focus, selection gestures and clipboard
formats. The document behavior knows what a shape is, which connections remain
valid when it moves, and how a pasted fragment acquires fresh identities. The
interface between them says what is being requested without requiring a mouse
event or a window object as its argument.

Not every pointer movement has to become a committed edit. A GUI can show a
temporary preview and commit one move when the user releases the pointer.
Another product may need live document updates throughout the gesture. The
boundary should express the chosen interaction semantics; it should not erase
them. When snapping or geometric constraints affect a valid document position,
the reusable domain behavior should own those rules even if the GUI displays
their effect during a preview.

Figure \ref{fig:ch01-surfaces} shows the resulting freedom. The origin of a request
changes, while its domain meaning can remain the same.

![Schematic alternative surfaces for the illustrative editor. A gesture, a command-line request or a direct application call can reach the same domain operations. Only a surface that accepts a language needs that language's parser.](figures/many-surfaces.pdf){#fig:ch01-surfaces width=100%}

\FloatBarrier

This separation has a well-established architectural precedent. Cockburn's
ports-and-adapters account places an application's meaningful interactions
behind interfaces that can be driven by people, tests, batch jobs or other
programs. Device-specific adapters translate those interactions at the boundary
([Cockburn, 2005][ch01-cockburn]). Here, we use that boundary as the starting point
for a further separation: shared runtime agreements and replaceable domain
modules.

### Standard streams are another surface

A command-line application can take options and arguments, read data from
standard input, write its result to standard output, and report diagnostics on
standard error. Rust exposes these standard streams through its I/O library
([Rust project, n.d.][ch01-stdio]). They carry input and output; they do not prescribe
the application's domain model or require a programming language.

For the editor example, a batch tool might read a document from stdin, apply a
requested move or validation operation, and write the resulting document to
stdout. Its adapter decodes bytes and command options into explicit requests.
A diagnostic about an invalid move becomes stderr text and an appropriate exit
status. The same domain failure could become a highlighted object in the GUI.
The failure's meaning belongs to the shared behavior; its presentation belongs
to the surface.

Keeping the ordinary result stream separate from diagnostics also makes it
possible to connect the tool to another process without mixing an error message
into document data. This is an interface choice the application must honor,
not a property bestowed by calling its core a kernel.

A parser for file data or command options may still be needed. That is different
from implementing a general-purpose language for the whole application. A
direct caller can bypass textual syntax completely and submit already
constructed arguments. The kernel boundary is an operation boundary, not
necessarily a text boundary.

## Give the center a boundary, then separate its responsibilities

So far, “kernel” has meant the program's meaningful core, including its domain
rules. To reuse the same runtime structure across domains, we make a second
distinction inside that core.

Some agreements concern participation: how a value is carried, how an operation
is identified and invoked, where a call's context comes from, and how an error
or result is described. Other rules concern the domain: what counts as a valid
connection in a diagram, what copying a shape includes, or what exporting a
document means. A *protocol kernel* holds the shared participation agreements.
*Domain modules* provide the behavior that makes the application useful.

The application core has not vanished. It is now a composition of a small
runtime center and the domain behavior attached to it. The kernel does not
become a diagram editor simply because a diagram module uses its contracts.
The same center can support another domain without acquiring that domain's
rules as special cases.

![Schematic responsibility split. The host assembles surfaces and services; domain modules implement meaningful operations against shared kernel contracts. Arrows show dependencies on contracts, not a mandatory sequence through every box.](figures/explicit-boundary.pdf){#fig:ch01-boundary width=100%}

\FloatBarrier

Figure \ref{fig:ch01-boundary} also gives the *host* a clear job. The host is the
program that assembles the parts: it chooses modules, creates their context and
state, connects external services and exposes an interface. A GUI host may
provide a clipboard and interactive file selection. A batch host may provide
explicit input and output streams. The domain module should not discover a
desktop window merely to find its document.

The split is about ownership and dependencies, not just file placement. A
module that reads a global “current window” to find its data still depends on
the GUI, even if its source lives in a folder named domain. A module that
receives a document and an explicit destination can be called by a different
host without inventing a window first.

There is a useful connection here to information hiding. Parnas's decomposition
criterion groups responsibilities around design decisions that should be
hidden from other modules, particularly decisions likely to change. Merely
turning successive flowchart steps into modules does not achieve that goal
([Parnas, 1972][ch01-parnas]). Our input–kernel–output drawing is therefore a way to
discuss behavior, not a prescription for exactly three source modules.

In the editor, the document representation can change without changing how the
GUI requests a move, provided the operation's contract is preserved. The
clipboard encoding can change without changing the meaning of a document
fragment. Those are concrete boundaries to design, rather than a demand that
every program adopt an elaborate universal object system.

## Make the domain usable away from its first interface

The payoff becomes clearer when we follow one editing operation across hosts.
Suppose a document contains two connected shapes. The user copies both, pastes
them into another document and moves the new pair. A reusable document module
must preserve the meaning of that sequence even when no GUI is present.

### Copy and paste need a data agreement

Copying can produce a fragment containing the selected shapes and the connection
between them. It should not produce a reference to a GUI widget or assume that
the destination can read the source window's memory. The fragment contract
defines which properties and references travel with it.

Pasting must then decide which identities to allocate, how internal connections
are remapped, and what happens to references that point outside the copied
selection. One possible rule preserves internal connections and reports
unresolved external references. Another may reject such a fragment. The
application needs a deliberate rule, and all hosts using that version of the
operation need the same meaning.

This is where reuse becomes more than sharing a function name. “Paste” on its
own is not a sufficient agreement. The input, ownership, result and failure
behavior together define what another program can safely ask for.

### A move needs explicit state and units

The move operation needs a target document, an object identity and a position
in agreed document coordinates. A GUI converts screen coordinates through its
viewport before issuing the request. A batch caller can supply document
coordinates directly. The shared domain behavior checks constraints and applies
the accepted change.

For a long-lived document, the contract may also need to say which revision the
caller expects to change. Otherwise, another action could invalidate an object
or move it between the caller's observation and its request. An explicit core
does not automatically solve concurrency; it provides a place to define the
chosen rule, whether that is serialization, revision checking or another policy.

The useful invariant is that each host reaches the same document rules. The
hosts can still have different workflows. A GUI offers a preview and undo
interaction. A batch job may stop at the first invalid request. Reusing the
operation does not require reproducing the entire user experience.

### External effects need a visible owner

Clipboard access, file writes and network requests connect the application to
its environment. A reusable module can receive an explicit service, return
data for the host to write, or participate in a defined effect protocol. The
appropriate choice depends on the job. What matters is that the dependency is
visible and can be supplied in the new host.

For example, exporting may first produce a document representation, which the
GUI host saves through a selected destination and the CLI host writes to stdout.
Large outputs may need streaming and cancellation rather than one in-memory
result. Those needs should shape the contract before claiming the exporter works
in both environments. Changing the wrapper cannot compensate for an interface
that omits a necessary behavior.

Once these agreements exist, a batch tool can reuse the editor's operations
without driving menu items. An automated check can exercise document rules
without generating mouse events. A second application can embed the same
behavior without adopting the first application's window layout.

## Reuse becomes a property of the architecture

Imagine three products: an interactive editor, a batch document converter and
a service that checks submitted diagrams. Each chooses a different surface and
deployment model. All three can use the same document module where their
required semantics agree. The converter can also reuse a format module; the
service can reuse a validation module. Shared contracts give those modules a
common way to participate.

![Schematic reuse across products. The same module implementation can be instantiated in different hosts, each with its own context, document state and external services. The diagram does not imply a shared process, shared mutable state or a network service.](figures/module-reuse.pdf){#fig:ch01-reuse width=100%}

\FloatBarrier

In Figure \ref{fig:ch01-reuse}, reuse means that the same implementation and contract
can serve several compositions. It need not mean that all products share one
running instance, one address space or one permissions set. The host can create
separate document state and supply different services. Crossing a process or
machine boundary adds transport and serialization obligations; it is not a
free consequence of the module boundary.

The benefit can compound. A correction to document validation can be made in
the shared module, then adopted by each product through its normal upgrade and
verification process. A new interface can reuse existing operations. A new
domain module can reuse the same calling and inspection conventions. The team
spends less effort rediscovering how each subsystem participates and more effort
on what the new subsystem actually does.

Compatibility still has several layers. Two modules may agree on how a value
is passed while disagreeing about coordinate units, identity lifetime or what
a successful operation guarantees. A shared runtime can connect them; it cannot
invent those missing semantic agreements. Names, versions, data contracts and
integration checks are part of the reusable module's product.

There is also a useful result before a second product exists: the domain can be
exercised without its first interface. That gives developers a way to discuss
and check what the program means independently of how it happens to look.
It makes future reuse plausible through a present boundary, rather than relying
on a promise that the GUI code can be extracted later.

## SIM gives the idea a concrete shape

SIM is an expandable Rust runtime built around a protocol kernel. In the
inspected public implementation, version 0.4.0 at revision `bbf0967be4f8`,
libraries meet through common contracts for values, objects, operations,
contexts and registered exports ([SIM contributors, 2026][ch01-sim]). Those contracts
let a new concrete object participate without requiring each caller to know its
Rust type.

An operation has an identity and a description of its expected input and
required capabilities. The kernel's checked dispatch path resolves an
operation, requires its declared capabilities and checks its input shape before
entering its implementation. A *shape* is a runtime description used to check
whether an input is acceptable. The kernel supplies the common calling
machinery; the library supplies the operation's domain behavior. Other metadata,
including promised result shapes, does not become a universal post-call check
merely because it appears in the description.

This is a concrete version of the separation developed above. The kernel need
not contain the rules for moving a diagram shape. A library could supply that
behavior while using the common value and operation contracts. The editor in
this chapter remains an illustration of that possibility, not an integration
demonstrated by the inspected repository.

SIM also separates the forms used to describe work from the live objects that
perform it. Its shared expression representation is independent of a particular
textual syntax. Concrete codecs and language behavior can be supplied around
the center. Lisp can be one surface, but SIM's identity is not tied to Lisp.
A host with an operation key, a target object and input values can use checked
dispatch without first constructing a textual program.

The implementation contains machinery as well as interfaces: registration,
stores, reference evaluation policies and bootstrap objects make the contracts
usable. “Small kernel” describes a responsibility boundary, not a claim that
the crate contains no behavior. The important discipline is that a new domain
can contribute its own behavior without making the shared center responsible
for that domain's rules.

Library manifests and export records provide a vocabulary for declaring what
a module contributes. The next architectural question is how the host obtains
and activates that contribution, resolves its dependencies and manages its
lifetime. That is the loader's subject. A modular design can begin with ordinary
static composition; dynamic loading is an additional choice with additional
obligations, not a prerequisite for the argument here.

Chapter \ref{the-sim-kernel}, *The SIM Kernel*, develops the kernel's contracts in
more detail. This chapter supplies the motivation: why those contracts can be
useful even for a program whose visible interface is only a few buttons or a
small command-line tool. Neither chapter assumes the reader wants a language
implementation walkthrough.

## Build the boundary from the start; let its breadth follow the work

Making the kernel properly from the start does not require predicting every
future module. It requires making today's behavior callable without smuggling
today's interface into its inputs. The first version can be small enough to
understand in one sitting.

Start by naming the domain's meaningful actions and the state they affect. For
the editor, copying a fragment and moving an object are better starting points
than reproducing the GUI toolkit's event vocabulary. Define the document
identity, coordinate meaning, success result and relevant failures. Choose who
owns the state and who supplies external services.

Then implement one complete path through that boundary. Let the GUI invoke it,
and let a small direct caller or automated check invoke it as well. If the
second caller needs a hidden window, global selection or modal dialog, the
boundary still contains assumptions from the first interface. Resolve those
assumptions while the operation is small.

As several operations and modules appear, identify the participation rules they
actually share. A common context, result convention or operation description
may now justify a shared runtime contract. Domain distinctions should remain
domain distinctions. A geometry rule does not belong in the kernel merely
because two editor features use it; it may belong in a geometry module.

SIM offers an existing contract layer when that degree of extensibility and
inspection fits the project. For a small, closed application, ordinary typed
functions and explicit dependencies may already provide the needed boundary.
The useful decision is whether several independently evolving modules and
surfaces need shared runtime agreements. There is no measured claim here that
one arrangement is always faster, smaller or cheaper to maintain.

The design also has costs: another interface to understand, contracts to keep
compatible, and sometimes additional indirection or runtime checking. A
universal dispatcher that merely forwards every call while hiding useful types
may add little. The boundary earns its place when it makes real behavior usable
in another context and keeps changes with the component that owns their meaning.

What makes the idea appealing is that the application stops being trapped in
its first presentation. The editor's knowledge of documents can outlive its
first window. A command-line tool can become a useful part of another program.
A new surface can offer existing behavior in a new way, and a new domain can
join an already understood runtime.

The program had a core all along. Giving it a deliberate boundary turns that
core into something we can name, compose, inspect and reuse. The domain remains
the reason the program exists; making it a module gives that domain more places
to work.

## References {#ch01-references .unnumbered}

1. Cockburn, A. (2005). *Hexagonal Architecture*, HaT Technical Report 2005.02.
   [Original article][ch01-cockburn], dated 4 September 2005. Accessed 29 September 2026.
2. Parnas, D. L. (1972). “On the Criteria To Be Used in Decomposing Systems
   into Modules.” *Communications of the ACM*, 15(12), 1053–1058.
   [doi:10.1145/361598.361623][ch01-parnas].
3. Rust project (n.d.). *Rust standard library documentation*, module
   `std::io`. [Official documentation][ch01-stdio]. Accessed 29 September 2026.
4. SIM contributors (2026). *sim-kernel*, package version 0.4.0, inspected
   revision `bbf0967be4f8`. [Public source and contract documentation][ch01-sim].
   Revision dated 29 September 2026.

[ch01-cockburn]: https://alistair.cockburn.us/hexagonal-architecture
[ch01-parnas]: https://doi.org/10.1145/361598.361623
[ch01-stdio]: https://doc.rust-lang.org/std/io/index.html
[ch01-sim]: https://github.com/sim-nest/sim-kernel/tree/bbf0967be4f8663490b12e4866de41a65232ee77
